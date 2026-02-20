//
//  Diagnoser.swift
//  LillaJag
//
//  Åtgärdad & förbättrad 26 jul 2025 av ChatGPT (o3)
//  – Fixat topp‑mellanrum & knappdocka
//


import SwiftUI
import AVKit
import AVFoundation

// MARK: – Layout helper: reservera bottenutrymme för framtida navbar
struct ReserveBottomSpace: ViewModifier {
    let fraction: CGFloat
    let minHeight: CGFloat
    func body(content: Content) -> some View {
        GeometryReader { geo in
            content
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: max(minHeight, geo.size.height * fraction))
                }
        }
    }
}

extension View {
    /// Lägger ett transparent inlägg i nederkant som tar upp plats (t.ex. för navbar)
    /// - Parameters:
    ///   - fraction: andel av höjden att reservera (standard 0.2 = 20%)
    ///   - minHeight: minsta höjd i punkter (standard 120)
    func reserveBottomSpace(fraction: CGFloat = 0.2, minHeight: CGFloat = 120) -> some View {
        modifier(ReserveBottomSpace(fraction: fraction, minHeight: minHeight))
    }
}

// MARK: – Datamodell ----------------------------------------------------------

struct Diagnosis: Identifiable, Hashable {
    let id = UUID()
    let name, description: String
    let symptoms, help: [String]
    let videoFile: String
}

// MARK: – Fasta data (15 vanliga diagnoser) ----------------------------------

let diagnoses: [Diagnosis] = [
    Diagnosis(
        name: "Depression",
        description: "Depression innebär ihållande nedstämdhet, energibrist och minskat intresse för aktiviteter som tidigare gav glädje. Tillståndet påverkar sömn, aptit och självkänsla och kan leda till isolering.",
        symptoms: [
            "Ledsenhet större delen av dagen",
            "Förlust av glädje och motivation",
            "Energi‑ och koncentrationsbrist",
            "Sömn‑ och aptitförändringar",
            "Skuldkänslor, hopplöshet, suicidtankar"
        ],
        help: [
            "Kognitiv beteendeterapi",
            "Antidepressiv medicinering (SSRI/SNRI)",
            "Regelbunden fysisk aktivitet",
            "Socialt stöd & meningsfulla aktiviteter",
            "Ljus‑ eller sömnbehandling vid behov"
        ],
        videoFile: "depression"
    ),
    Diagnosis(
        name: "Generaliserat ångestsyndrom (GAD)",
        description: "GAD kännetecknas av okontrollerbar, långvarig oro kring många livsområden. Orosnivån är oproportionerlig och ger både psykiska och fysiska symtom.",
        symptoms: [
            "Konstant oro, grubblande",
            "Sömnsvårigheter och trötthet",
            "Muskelspänningar och rastlöshet",
            "Koncentrationsproblem",
            "Irritabilitet"
        ],
        help: [
            "Kognitiv beteendeterapi",
            "Avslappning & mindfulness",
            "SSRI/SNRI‑läkemedel",
            "Stresshantering & planering",
            "Regelbunden motion"
        ],
        videoFile: "gad"
    ),
    Diagnosis(
        name: "Bipolär sjukdom",
        description: "Bipolär sjukdom innebär växlingar mellan maniska/hypomana och depressiva episoder som påverkar energi, sömn, omdöme och funktionsförmåga.",
        symptoms: [
            "Mani: upprymdhet, minskat sömnbehov",
            "Impulsivt risktagande",
            "Snabba tankar & tal",
            "Depressiva perioder",
            "Starka stämningssvängningar"
        ],
        help: [
            "Stämningsstabiliserare (litium m.fl.)",
            "Psykoedukation & regelbunden livsrytm",
            "Terapi (IPSRT, KBT, FFT)",
            "Sömnhygien och stressreduktion",
            "Undvik alkohol & droger"
        ],
        videoFile: "bipolar"
    ),
    Diagnosis(
        name: "ADHD",
        description: "ADHD är ett neuropsykiatriskt funktionshinder som kännetecknas av uppmärksamhetsproblem, impulsivitet och/eller hyperaktivitet vilket påverkar studier, arbete och relationer.",
        symptoms: [
            "Svårigheter att behålla fokus",
            "Glömska och dålig tidsuppfattning",
            "Impulsivt agerande",
            "Inre/yttre rastlöshet",
            "Organisationssvårigheter"
        ],
        help: [
            "Centralstimulerande medicinering",
            "Strukturerande hjälpmedel",
            "KBT & färdighetsträning",
            "Fysisk aktivitet",
            "Psykoedukation för omgivningen"
        ],
        videoFile: "adhd"
    ),
    Diagnosis(
        name: "Autismspektrumtillstånd (AST)",
        description: "AST innebär svårigheter med social kommunikation och flexibilitet kombinerat med repetitiva beteenden och ofta starka specialintressen.",
        symptoms: [
            "Utmaningar i ömsesidig kommunikation",
            "Bokstavlig tolkning av språk",
            "Behov av fasta rutiner",
            "Sensorisk känslighet",
            "Specialintressen"
        ],
        help: [
            "Tydliggörande pedagogik",
            "Social färdighetsträning",
            "Miljöanpassningar",
            "Ergoterapi & sensoriska strategier",
            "Stöd för anhöriga"
        ],
        videoFile: "autism"
    ),
    Diagnosis(
        name: "Posttraumatiskt stressyndrom (PTSD)",
        description: "PTSD uppstår efter en eller flera traumatiska händelser och präglas av återupplevanden, undvikanden och ständig beredskap.",
        symptoms: [
            "Flashbacks & mardrömmar",
            "Undvikande av påminnelser",
            "Sömnstörning och irritabilitet",
            "Hypervigilans",
            "Negativa tankar & känslor"
        ],
        help: [
            "Traumafokuserad KBT (PE, CPT)",
            "EMDR‑behandling",
            "SSRI/SNRI",
            "Grounding‑ och stabiliseringstekniker",
            "Socialt stöd & trygghet"
        ],
        videoFile: "ptsd"
    ),
    Diagnosis(
        name: "Tvångssyndrom (OCD)",
        description: "OCD består av tvångstankar och tvångshandlingar som lindrar ångest kortsiktigt men tar tid och påverkar livskvaliteten negativt.",
        symptoms: [
            "Påträngande tvångstankar",
            "Ritualiserad tvättning/kontroll",
            "Krävande symmetri eller ordning",
            "Rädsla för smitta/skada",
            "Tidskrävande ceremonier"
        ],
        help: [
            "Exponering & responsprevention",
            "Högdos SSRI",
            "Psykoedukation & anhörigstöd",
            "Stresshantering",
            "Mindfulness"
        ],
        videoFile: "ocd"
    ),
    Diagnosis(
        name: "Emotionellt instabil personlighetsstörning (EIPS)",
        description: "EIPS kännetecknas av instabila relationer, självkänsla och kraftiga känslosvängningar samt impulsivitet och självskadebeteende.",
        symptoms: [
            "Intensiv rädsla för övergivenhet",
            "Svart‑vit värdering av relationer",
            "Impulsivitet och vredesutbrott",
            "Kronisk tomhetskänsla",
            "Självskadehandlingar"
        ],
        help: [
            "Dialektisk beteendeterapi (DBT)",
            "Mentaliseringsbaserad terapi (MBT)",
            "Kris‑ & säkerhetsplan",
            "Känsloregleringsfärdigheter",
            "Farmakologiskt stöd vid samsjuklighet"
        ],
        videoFile: "eips"
    ),
    Diagnosis(
        name: "Paniksyndrom",
        description: "Återkommande panikattacker med intensiv rädsla för nya attacker vilket leder till undvikanden och funktionsnedsättning.",
        symptoms: [
            "Hjärtklappning & svettningar",
            "Andnöd & kvävningskänsla",
            "Yrsel, overklighetskänsla",
            "Akut döds‑ eller kontrollförlustskräck",
            "Förväntansoro"
        ],
        help: [
            "KBT med interoceptiv exponering",
            "Andnings‑ & avslappningsövningar",
            "SSRI/SNRI",
            "Regelbunden konditionsträning",
            "Psykoedukation"
        ],
        videoFile: "panic"
    ),
    Diagnosis(
        name: "Social ångest",
        description: "Stark rädsla för negativ granskning i sociala situationer vilket leder till undvikande och nedsatt livskvalitet.",
        symptoms: [
            "Rodnad, skakningar, svettning",
            "Rädsla att göra bort sig",
            "Undvikande av tal inför grupp",
            "Uttalad självmedvetenhet",
            "Eftergrubblande"
        ],
        help: [
            "Grupp‑ eller individuell KBT",
            "Exponeringsövningar",
            "SSRI/SNRI",
            "Social färdighetsträning",
            "Mindfulness & ACT‑tekniker"
        ],
        videoFile: "social_anxiety"
    ),
    Diagnosis(
        name: "Schizofreni",
        description: "Schizofreni är en kronisk psykossjukdom med hallucinationer, vanföreställningar och kognitiva funktionsnedsättningar.",
        symptoms: [
            "Röster eller andra hallucinationer",
            "Vanföreställningar",
            "Desorganiserat tal/beteende",
            "Negativa symtom (avtrubbning)",
            "Kognitiv svikt"
        ],
        help: [
            "Antipsykotiska läkemedel",
            "Psykosocialt stöd & case‑management",
            "Kognitiv rehabilitering",
            "Familjeintervention",
            "Stödd sysselsättning"
        ],
        videoFile: "schizophrenia"
    ),
    Diagnosis(
        name: "Ätstörningar",
        description: "Ätstörningar som anorexia, bulimi och hetsätningsstörning kännetecknas av störd kroppsuppfattning och dysfunktionellt ätbeteende.",
        symptoms: [
            "Intensiv rädsla för viktuppgång",
            "Restriktivt ätande eller hetsätning",
            "Kompensation (kräkning, laxermedel)",
            "Kroppsmissnöje",
            "Amenorré eller låg puls (vid AN)"
        ],
        help: [
            "Specialiserad KBT‑E",
            "Näringsterapi & medicinsk uppföljning",
            "Familjebaserad behandling",
            "Farmakologisk samsjuklighetsbehandling",
            "Kroppsacceptans‑övningar"
        ],
        videoFile: "eating_disorder"
    ),
    Diagnosis(
        name: "Substansbrukssyndrom",
        description: "Problematiskt bruk av alkohol eller droger som leder till funktionsnedsättning, tolerans och abstinens.",
        symptoms: [
            "Kontrollförlust & cravings",
            "Toleransökning",
            "Abstinenssymtom",
            "Fortsatt bruk trots skada",
            "Social och yrkesmässig försämring"
        ],
        help: [
            "Motiverande samtal",
            "Läkemedelsassisterad behandling",
            "Återfallsprevention",
            "Självhjälpsgrupper (12‑steg, SMART)",
            "Social rehabilitering"
        ],
        videoFile: "substance_use"
    ),
    Diagnosis(
        name: "Specifika fobier",
        description: "Intensiv, irrationell rädsla för ett specifikt objekt eller situation som leder till undvikande och ångest.",
        symptoms: [
            "Omedelbar panikreaktion vid exponering",
            "Panik‑/ångestsymtom",
            "Undvikande av fobiobjektet",
            "Insikt om att rädslan är överdriven",
            "Funktionsförlust"
        ],
        help: [
            "Gradvis exponeringsterapi",
            "Systematisk desensibilisering",
            "Kognitiv omstrukturering",
            "Avslappningstekniker",
            "Korttidsfarmaka vid behov"
        ],
        videoFile: "phobia"
    ),
    Diagnosis(
        name: "Insomni",
        description: "Insomni innebär svårigheter att somna, bibehålla sömn eller vakna för tidigt ≥ 3 nätter/vecka i minst en månad.",
        symptoms: [
            "Lång insomningstid",
            "Uppvaknanden nattetid",
            "Tidiga morgonuppvaknanden",
            "Dagtrötthet & irritabilitet",
            "Koncentrationsproblem"
        ],
        help: [
            "KBT‑I (sömnrestriktion/stimulus‑kontroll)",
            "Sömnhygien",
            "Avslappning & mindfulness",
            "Korttidsverkande insomnimedicin",
            "Behandla bakomliggande orsaker"
        ],
        videoFile: "insomnia"
    )
]

// MARK: – API‑nycklar (demo) --------------------------------------------------

private let elevenLabsAPIKey  = "sk_d2f47d257b333b5c851363dd2f17c25babaa63b873d7dd0d"
private let elevenLabsVoiceID = "4WpEoB5wO1r9MAJoD3s0"

private let openAIAPIKey = "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"
private let openAIModel   = "gpt-4o-mini"

// MARK: – Huvudvy -------------------------------------------------------------

struct DiagnoserView: View {
    @State private var search = ""
    @State private var showFavoritesOnly = false
    @State private var favorites: Set<Diagnosis> = []
    
    private var filtered: [Diagnosis] {
        var list = diagnoses
        if !search.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
        if showFavoritesOnly {
            list = list.filter { favorites.contains($0) }
        }
        return list
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filtered) { diag in
                            NavigationLink {
                                DiagnosisDetailView(
                                    diagnosis: diag,
                                    isFavorite: favorites.contains(diag)
                                ) { fav, set in
                                    if set { favorites.insert(fav) } else { favorites.remove(fav) }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(diag.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(diag.description)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.7))
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 12)
                                    Image(systemName: favorites.contains(diag) ? "heart.fill" : "heart")
                                        .foregroundColor(.pink)
                                }
                                .padding()
                                .glass()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)        // litet & jämnt topp‑avstånd
                }
                .searchable(text: $search, prompt: "Sök diagnos")
            }
            .navigationTitle("Diagnoser")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFavoritesOnly.toggle()
                    } label: {
                        Label("Favoriter", systemImage: showFavoritesOnly ? "heart.fill" : "heart")
                    }
                }
            }
        }
        .reserveBottomSpace() // ← reservera ~20% i nederkant
    }
}

// MARK: – Detaljvy ------------------------------------------------------------

struct DiagnosisDetailView: View {
    let diagnosis: Diagnosis
    @State private var player = AVPlayer()
    @State private var isSpeaking = false
    @State private var showChat = false
    @State private var favorite: Bool
    let onFavoriteChange: (Diagnosis, Bool) -> Void
    
    init(diagnosis: Diagnosis, isFavorite: Bool,
         onFavoriteChange: @escaping (Diagnosis, Bool) -> Void) {
        self.diagnosis = diagnosis
        _favorite = State(initialValue: isFavorite)
        self.onFavoriteChange = onFavoriteChange
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    videoHeader
                    infoSection
                    // knapparna – under "Vad kan hjälpa"
                    HStack(spacing: 16) {
                        Button {
                            Task { await speak(diagnosis.description) }
                        } label: {
                            Label(isSpeaking ? "Spelar…" : "Lyssna", systemImage: "ear")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButton())
                        .disabled(isSpeaking)
                        
                        Button {
                            showChat = true
                        } label: {
                            Label("Fråga ChatGPT", systemImage: "bubble.left.and.bubble.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButton())
                    }
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle(diagnosis.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    favorite.toggle()
                    onFavoriteChange(diagnosis, favorite)
                } label: {
                    Image(systemName: favorite ? "heart.fill" : "heart")
                        .foregroundColor(.pink)
                }
            }
        }
        .reserveBottomSpace() // ← reservera ~20% i nederkant
        .sheet(isPresented: $showChat) {
            ChatView(prompt: "Vilken evidensbaserad behandling rekommenderas för \(diagnosis.name.lowercased())?")
        }
        .onDisappear { player.pause() }
    }
    
    // MARK: – Delvyer
    
    private var videoHeader: some View {
        VideoPlayer(player: player)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .bottomTrailing) {
                Button {
                    player.isMuted.toggle()
                } label: {
                    Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(12)
            }
            .onAppear {
                if let url = Bundle.main.url(forResource: diagnosis.videoFile, withExtension: "mp4") {
                    player.replaceCurrentItem(with: AVPlayerItem(url: url))
                    player.play()
                    player.isMuted = true
                    player.actionAtItemEnd = .none
                    NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: player.currentItem,
                        queue: .main
                    ) { _ in
                        player.seek(to: .zero)
                        player.play()
                    }
                }
            }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(diagnosis.description)
                .foregroundColor(.white)
            Divider().background(.white.opacity(0.3))
            bullet(title: "Vanliga kännetecken",
                   icon: "exclamationmark.circle",
                   items: diagnosis.symptoms)
            Divider().background(.white.opacity(0.3))
            bullet(title: "Vad kan hjälpa?",
                   icon: "heart.text.square",
                   items: diagnosis.help)
        }
        .glass()
    }
    
    private func bullet(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.white)
            ForEach(items, id: \.self) { i in
                HStack(alignment: .top, spacing: 4) {
                    Text("•").fontWeight(.bold)
                    Text(i).foregroundColor(.white.opacity(0.9))
                }
            }
        }
    }
    
    // MARK: – TTS
    
    private func speak(_ text: String) async {
        guard !isSpeaking else { return }
        isSpeaking = true
        defer { isSpeaking = false }
        do {
            if let d = try await ElevenLabsTTS.shared.generateAudio(text) {
                try AudioPlayer.shared.play(data: d) { }
            }
        } catch { }
    }
}

// MARK: – Chat (Chatty‑stil) --------------------------------------------------

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    let prompt: String?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                ChatBubble(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last?.id {
                            withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $input)
                            .frame(minHeight: 44, maxHeight: 100)
                            .padding(6)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(.white)
                            .onSubmit(send)
                        if input.isEmpty {
                            Text("Skriv ett meddelande …")
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                    }
                    Button {
                        send()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            if let prompt {
                messages.append(ChatMessage(content: prompt, isUser: true))
                Task { await ask(prompt) }
            }
        }
    }
    
    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        messages.append(ChatMessage(content: text, isUser: true))
        Task { await ask(text) }
    }
    
    private func ask(_ text: String) async {
        do {
            let reply = try await ChatGPT.shared.send(text)
            messages.append(ChatMessage(content: reply, isUser: false))
        } catch {
            messages.append(ChatMessage(content: "❗️Kunde inte hämta svar.", isUser: false))
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 50) }
            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.isUser
                    ? Color.blue.opacity(0.85)
                    : Color.white.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .leading)
            if !message.isUser { Spacer(minLength: 50) }
        }
        .padding(message.isUser ? .leading : .trailing, 60)
    }
}

struct ChatMessage: Identifiable {
    let id = UUID(); let content: String; let isUser: Bool
}

// MARK: – ChatGPT‑klient ------------------------------------------------------

final class ChatGPT {
    static let shared = ChatGPT(); private init() {}
    
    func send(_ prompt: String) async throws -> String {
        var r = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        r.httpMethod = "POST"
        r.addValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        r.addValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": openAIModel,
            "temperature": 0.7,
            "messages": [
                ["role":"system","content":"Du är en hjälpsam, empatisk svensk psykologassistent."],
                ["role":"user","content": prompt]
            ]
        ])
        
        let (d, _) = try await URLSession.shared.data(for: r)
        guard
            let obj = try JSONSerialization.jsonObject(with: d) as? [String:Any],
            let choice = (obj["choices"] as? [[String:Any]])?.first,
            let msg = choice["message"] as? [String:Any],
            let txt = msg["content"] as? String
        else { throw URLError(.badServerResponse) }
        return txt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: – ElevenLabs TTS ------------------------------------------------------

final class ElevenLabsTTS {
    static let shared = ElevenLabsTTS(); private init() {}
    
    func generateAudio(_ text: String) async throws -> Data? {
        var r = URLRequest(url: URL(string:
            "https://api.elevenlabs.io/v1/text-to-speech/\(elevenLabsVoiceID)/stream")!)
        r.httpMethod = "POST"
        r.addValue(elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")
        r.addValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "voice_settings": ["stability": 0.35, "similarity_boost": 0.8]
        ])
        let (d, _) = try await URLSession.shared.data(for: r)
        return d
    }
}

// MARK: – Audio‑spelare -------------------------------------------------------

final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayer(); private override init() {}
    private var player: AVAudioPlayer?; private var done: () -> Void = {}
    
    func play(data: Data, completion: @escaping () -> Void) throws {
        done = completion
        player = try AVAudioPlayer(data: data)
        player?.delegate = self
        player?.prepareToPlay()
        player?.play()
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        done()
    }
}


// MARK: – Preview -------------------------------------------------------------

#Preview {
    DiagnoserView()
        .environment(\.colorScheme, .dark)
}
