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
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 100) // Fast höjd för navbar
            }
    }
}

extension View {
    /// Lägger ett transparent inlägg i nederkant som tar upp plats (t.ex. för navbar)
    func reserveBottomSpace() -> some View {
        modifier(ReserveBottomSpace())
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

// MARK: – ChatGPT‑klient ------------------------------------------------------

final class ChatGPT {
    static let shared = ChatGPT(); private init() {}
    
    func send(_ prompt: String) async throws -> String {
        var r = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        r.httpMethod = "POST"
        r.addValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        r.addValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-4o-mini",
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
        let voiceID = "4WpEoB5wO1r9MAJoD3s0"
        var r = URLRequest(url: URL(string:
            "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)/stream")!)
        r.httpMethod = "POST"
        r.addValue(Config.elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")
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

// MARK: - DiagnoserView
struct DiagnoserView: View {
    @State private var selected: Diagnosis?
    @State private var searchText = ""
    
    var filtered: [Diagnosis] {
        if searchText.isEmpty { return diagnoses }
        return diagnoses.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 0) {
                HStack {
                    LJTitle(text: "Diagnoser")
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Sök diagnos...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding()
                .ljGlassCard(radius: 12)
                .padding()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filtered) { diag in
                            Button {
                                selected = diag
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(diag.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(diag.description)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .ljGlassCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120)
                }
            }
        }
        .fullScreenCover(item: $selected) { diag in
            DiagnosisDetailView(diagnosis: diag)
        }
    }
}

struct DiagnosisDetailView: View {
    let diagnosis: Diagnosis
    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying = false
    @State private var loadingAudio = false
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        
                        Button {
                            speak()
                        } label: {
                            HStack {
                                if loadingAudio {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                                }
                                Text(isPlaying ? "Stoppa" : "Lyssna")
                            }
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.3), in: Capsule())
                            .overlay(Capsule().stroke(Color.blue, lineWidth: 1))
                        }
                        .disabled(loadingAudio)
                    }
                    .padding(.top, 20)
                    
                    Text(diagnosis.name)
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    if let url = Bundle.main.url(forResource: diagnosis.videoFile, withExtension: "mp4") {
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .ljGlassCard(radius: 20)
                    }
                    
                    LJCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Om diagnosen")
                                .font(.headline)
                            Text(diagnosis.description)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }
                    
                    LJCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Vanliga symtom")
                                .font(.headline)
                            ForEach(diagnosis.symptoms, id: \.self) { symptom in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .padding(.top, 6)
                                    Text(symptom)
                                }
                            }
                        }
                    }
                    
                    LJCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hjälp & Behandling")
                                .font(.headline)
                            ForEach(diagnosis.help, id: \.self) { item in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(item)
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
        }
    }
    
    private func speak() {
        if isPlaying {
            // Stoppa (ej implementerat i AudioPlayer.shared men för UI skull)
            isPlaying = false
            return
        }
        
        loadingAudio = true
        Task {
            do {
                let text = "\(diagnosis.name). \(diagnosis.description). Symtom inkluderar: \(diagnosis.symptoms.joined(separator: ", ")). Behandling inkluderar: \(diagnosis.help.joined(separator: ", "))"
                if let data = try await ElevenLabsTTS.shared.generateAudio(text) {
                    try AudioPlayer.shared.play(data: data) {
                        isPlaying = false
                    }
                    isPlaying = true
                }
            } catch {
                print("TTS error: \(error)")
            }
            loadingAudio = false
        }
    }
}

// MARK: – Preview -------------------------------------------------------------

#Preview {
    DiagnoserView()
        .environment(\.colorScheme, .dark)
}
