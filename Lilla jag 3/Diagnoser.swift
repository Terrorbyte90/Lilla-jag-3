//
//  Diagnoser.swift
//  LillaJag
//

import SwiftUI
import AVKit

// MARK: - Datamodell

struct Diagnosis: Identifiable, Hashable {
    let id = UUID()
    let name, description: String
    let symptoms, help: [String]
    let videoFile: String
    let icon: String
    let color: Color
}

// MARK: - Fasta data (15 vanliga diagnoser)

let diagnoses: [Diagnosis] = [
    Diagnosis(
        name: "Depression",
        description: "Depression innebär ihållande nedstämdhet, energibrist och minskat intresse för aktiviteter som tidigare gav glädje. Tillståndet påverkar sömn, aptit och självkänsla och kan leda till isolering.",
        symptoms: [
            "Ledsenhet större delen av dagen",
            "Förlust av glädje och motivation",
            "Energi- och koncentrationsbrist",
            "Sömn- och aptitförändringar",
            "Skuldkänslor, hopplöshet, suicidtankar"
        ],
        help: [
            "Kognitiv beteendeterapi",
            "Antidepressiv medicinering (SSRI/SNRI)",
            "Regelbunden fysisk aktivitet",
            "Socialt stöd & meningsfulla aktiviteter",
            "Ljus- eller sömnbehandling vid behov"
        ],
        videoFile: "depression",
        icon: "cloud.rain.fill",
        color: Color(hex: 0x6B8DD6)
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
            "SSRI/SNRI-läkemedel",
            "Stresshantering & planering",
            "Regelbunden motion"
        ],
        videoFile: "gad",
        icon: "waveform.path.ecg",
        color: Color.warmLavender
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
        videoFile: "bipolar",
        icon: "arrow.up.arrow.down.circle.fill",
        color: Color.warmCoral
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
        videoFile: "adhd",
        icon: "bolt.circle.fill",
        color: Color.warmGold
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
        videoFile: "autism",
        icon: "puzzlepiece.fill",
        color: Color.warmSage
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
            "EMDR-behandling",
            "SSRI/SNRI",
            "Grounding- och stabiliseringstekniker",
            "Socialt stöd & trygghet"
        ],
        videoFile: "ptsd",
        icon: "bolt.heart.fill",
        color: Color(hex: 0xFF8C69)
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
        videoFile: "ocd",
        icon: "arrow.triangle.2.circlepath.circle.fill",
        color: Color(hex: 0x6ECFF6)
    ),
    Diagnosis(
        name: "Emotionellt instabil personlighetsstörning (EIPS)",
        description: "EIPS kännetecknas av instabila relationer, självkänsla och kraftiga känslosvängningar samt impulsivitet och självskadebeteende.",
        symptoms: [
            "Intensiv rädsla för övergivenhet",
            "Svart-vit värdering av relationer",
            "Impulsivitet och vredesutbrott",
            "Kronisk tomhetskänsla",
            "Självskadehandlingar"
        ],
        help: [
            "Dialektisk beteendeterapi (DBT)",
            "Mentaliseringsbaserad terapi (MBT)",
            "Kris- & säkerhetsplan",
            "Känsloregleringsfärdigheter",
            "Farmakologiskt stöd vid samsjuklighet"
        ],
        videoFile: "eips",
        icon: "flame.fill",
        color: Color.warmRose
    ),
    Diagnosis(
        name: "Paniksyndrom",
        description: "Återkommande panikattacker med intensiv rädsla för nya attacker vilket leder till undvikanden och funktionsnedsättning.",
        symptoms: [
            "Hjärtklappning & svettningar",
            "Andnöd & kvävningskänsla",
            "Yrsel, overklighetskänsla",
            "Akut döds- eller kontrollförlustskräck",
            "Förväntansoro"
        ],
        help: [
            "KBT med interoceptiv exponering",
            "Andnings- & avslappningsövningar",
            "SSRI/SNRI",
            "Regelbunden konditionsträning",
            "Psykoedukation"
        ],
        videoFile: "panic",
        icon: "heart.circle.fill",
        color: Color(hex: 0xFF5B5B)
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
            "Grupp- eller individuell KBT",
            "Exponeringsövningar",
            "SSRI/SNRI",
            "Social färdighetsträning",
            "Mindfulness & ACT-tekniker"
        ],
        videoFile: "social_anxiety",
        icon: "person.fill.questionmark",
        color: Color(hex: 0xFF8FAD)
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
            "Psykosocialt stöd & case-management",
            "Kognitiv rehabilitering",
            "Familjeintervention",
            "Stödd sysselsättning"
        ],
        videoFile: "schizophrenia",
        icon: "eye.trianglebadge.exclamationmark.fill",
        color: Color(hex: 0x9B59B6)
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
            "Specialiserad KBT-E",
            "Näringsterapi & medicinsk uppföljning",
            "Familjebaserad behandling",
            "Farmakologisk samsjuklighetsbehandling",
            "Kroppsacceptans-övningar"
        ],
        videoFile: "eating_disorder",
        icon: "fork.knife.circle.fill",
        color: Color(hex: 0xE8A87C)
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
            "Självhjälpsgrupper (12-steg, SMART)",
            "Social rehabilitering"
        ],
        videoFile: "substance_use",
        icon: "drop.triangle.fill",
        color: Color(hex: 0x8B6F47)
    ),
    Diagnosis(
        name: "Specifika fobier",
        description: "Intensiv, irrationell rädsla för ett specifikt objekt eller situation som leder till undvikande och ångest.",
        symptoms: [
            "Omedelbar panikreaktion vid exponering",
            "Panik-/ångestsymtom",
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
        videoFile: "phobia",
        icon: "exclamationmark.triangle.fill",
        color: Color.warmCoral
    ),
    Diagnosis(
        name: "Insomni",
        description: "Insomni innebär svårigheter att somna, bibehålla sömn eller vakna för tidigt tre eller fler nätter per vecka i minst en månad.",
        symptoms: [
            "Lång insomningstid",
            "Uppvaknanden nattetid",
            "Tidiga morgonuppvaknanden",
            "Dagtrötthet & irritabilitet",
            "Koncentrationsproblem"
        ],
        help: [
            "KBT-I (sömnrestriktion/stimulus-kontroll)",
            "Sömnhygien",
            "Avslappning & mindfulness",
            "Korttidsverkande insomnimedicin",
            "Behandla bakomliggande orsaker"
        ],
        videoFile: "insomnia",
        icon: "moon.zzz.fill",
        color: Color(hex: 0x7B8CDE)
    )
]

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
            WarmBackground()

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        LJTitle(text: "Diagnoser")
                        Spacer()
                        Text("\(filtered.count) diagnoser")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Sök diagnos...", text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Rensa sökning")
                        }
                    }
                    .padding()
                    .ljGlassCard(radius: 12)
                    .padding()
                    .accessibilityLabel("Sök bland diagnoser")

                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { diag in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selected = diag
                            } label: {
                                HStack(spacing: 14) {
                                    LJIconCircle(icon: diag.icon, color: diag.color, size: 44)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(diag.name)
                                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                                            .foregroundStyle(.white)
                                        Text(diag.description)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.25))
                                }
                                .padding(14)
                                .ljGlassCard()
                            }
                            .buttonStyle(LJPressableButtonStyle())
                            .accessibilityLabel(diag.name)
                            .accessibilityHint("Tryck för att läsa mer om \(diag.name)")
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

// MARK: - DiagnosisDetailView

struct DiagnosisDetailView: View {
    let diagnosis: Diagnosis
    @Environment(\.dismiss) private var dismiss
    @State private var aiInsight: String = ""
    @State private var loadingInsight = false

    var body: some View {
        ZStack {
            WarmBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()

                        Button {
                            loadAIInsight()
                        } label: {
                            HStack {
                                if loadingInsight {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "brain.head.profile")
                                }
                                Text(loadingInsight ? "Tänker..." : "AI-insikt")
                            }
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.warmLavender.opacity(0.3), in: Capsule())
                            .overlay(Capsule().stroke(Color.warmLavender, lineWidth: 1))
                        }
                        .disabled(loadingInsight)
                        .foregroundStyle(.white)
                    }
                    .padding(.top, 8)

                    HStack(spacing: 14) {
                        LJIconCircle(icon: diagnosis.icon, color: diagnosis.color, size: 48)
                        Text(diagnosis.name)
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundStyle(.white)
                    }

                    if !aiInsight.isEmpty {
                        LJCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundStyle(Color.warmLavender)
                                    Text("AI-insikt från Lilla Jag")
                                        .font(.headline)
                                        .foregroundStyle(Color.warmLavender)
                                }
                                Text(aiInsight)
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineSpacing(4)
                            }
                        }
                    }

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
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            ForEach(diagnosis.symptoms, id: \.self) { symptom in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 5))
                                        .foregroundStyle(diagnosis.color.opacity(0.7))
                                        .padding(.top, 7)
                                    Text(symptom)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                        }
                    }

                    LJCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hjälp & Behandling")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            ForEach(diagnosis.help, id: \.self) { item in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.warmSage)
                                        .font(.system(size: 14))
                                    Text(item)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.85))
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

    private func loadAIInsight() {
        loadingInsight = true
        Task {
            let prompt = "Ge en kort, empatisk och evidensbaserad insikt (3-4 meningar) på svenska om \(diagnosis.name) ur ett KBT-perspektiv. Fokusera på hopp och återhämtning."
            aiInsight = await LillaJagAIService.shared.generateResponse(to: prompt)
            loadingInsight = false
        }
    }
}

// MARK: - Preview

#Preview {
    DiagnoserView()
        .environment(\.colorScheme, .dark)
}
