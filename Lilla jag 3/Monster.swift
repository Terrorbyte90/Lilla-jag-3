//
//  MonsterView.swift
//  Lilla Jag
//
//  • Lägg in filen i projektet.  Sätt `MonsterPanel()` i din befintliga ContentView.
//  • Byt API‑nyckeln i OpenAIConfig.
//  • Videomonstret loopar utan kontroller.
//  • Logg‑guiden öppnas helskärm med 4 tydliga val, faktaruta och en kort mp4‑loop per steg.
//  • GPT‑tipsen fokuserar på det som gått bra och pratar alltid i "du"-form.
//
import SwiftUI
import AVKit
import Foundation

// MARK: - 2  Videofiler
struct MonsterClips {
    static let idle       = ["idle_01", "idle_02", "idle_03"]
    static let sleepy     = "sleepy"
    static let hungry     = "hungry"
    static let pale       = "pale"
    static let stiff      = "stiff"
    static let mute       = "mute"
    static let superHappy = "happy_big"
}

// MARK: - 3  MonsterState
enum MonsterState: String, Codable {
    case idle, sleepy, hungry, pale, stiff, mute, superHappy
    
    var videoFile: String {
        switch self {
        case .idle:       return MonsterClips.idle.randomElement()!
        case .sleepy:     return MonsterClips.sleepy
        case .hungry:     return MonsterClips.hungry
        case .pale:       return MonsterClips.pale
        case .stiff:      return MonsterClips.stiff
        case .mute:       return MonsterClips.mute
        case .superHappy: return MonsterClips.superHappy
        }
    }
    
    var summary: String {
        switch self {
        case .idle:       return "Monstret chillar ✨"
        case .sleepy:     return "Monstret är sömnigt 😴"
        case .hungry:     return "Monstret är hungrigt 🍽️"
        case .pale:       return "Monstret vill ha solsken ☀️"
        case .stiff:      return "Monstret vill röra på sig 🤸"
        case .mute:       return "Monstret saknar sällskap 🗨️"
        case .superHappy: return "Monstret är superglatt 🎉"
        }
    }
}

// MARK: - 4  Dagens logg
struct DailyLog: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date
    let sleep, meals, outdoor, exercise, social: Int   // 1–4
    
    var monsterState: MonsterState {
        if sleep    < 3 { return .sleepy }
        if meals    < 3 { return .hungry }
        if outdoor  < 3 { return .pale }
        if exercise < 3 { return .stiff }
        if social   < 3 { return .mute }
        return .superHappy
    }
    var prompt: String {
        """
        Datum: \(date.formatted(date: .abbreviated, time: .omitted))
        Sömn: \(sleep)/4
        Mat: \(meals)/4
        Utomhus: \(outdoor)/4
        Träning: \(exercise)/4
        Socialt: \(social)/4
        """
    }
}

// MARK: - 5  Lokal lagring
@MainActor
final class MonsterStore: ObservableObject {
    @Published private(set) var logs: [DailyLog] = []
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory,
                                 in: .userDomainMask)[0]
        .appendingPathComponent("monster_logs.json")
    }
    init() { load() }
    func add(_ log: DailyLog) { logs.append(log); save() }
    private func save() { if let d = try? JSONEncoder().encode(logs) { try? d.write(to: fileURL) } }
    private func load() { if let d = try? Data(contentsOf: fileURL),
                           let l = try? JSONDecoder().decode([DailyLog].self, from: d) { logs = l } }
}

// MARK: - 6  AI-service (lokal – 100% offline via LillaJagAI)
final class MonsterGPT {
    struct Tip: Identifiable { let id = UUID(); let text: String }

    func fetch(for log: DailyLog) async -> [Tip] {
        // Generera tips baserat på loggens innehåll – helt lokalt
        var tips: [Tip] = []

        // Beröm det som gick bra (rating ≥ 3)
        if log.sleep >= 3 {
            tips.append(Tip(text: "Monstret blev glad att du sov bra i natt – sömn är superkraft!"))
        }
        if log.meals >= 3 {
            tips.append(Tip(text: "Bra jobbat med maten idag! Kroppen tackar dig."))
        }
        if log.outdoor >= 3 {
            tips.append(Tip(text: "Monstret älskar att du var utomhus – dagsljus gör underverk!"))
        }
        if log.exercise >= 3 {
            tips.append(Tip(text: "Du rörde på dig idag – monstret hoppar av glädje!"))
        }
        if log.social >= 3 {
            tips.append(Tip(text: "Social kontakt gör monstret varmt i hjärtat. Bra att du umgicks!"))
        }

        // Om inget var ≥ 3, ge uppmuntran
        if tips.isEmpty {
            tips.append(Tip(text: "Monstret vill bara säga: du klarade dagen, och det räcker."))
            tips.append(Tip(text: "Imorgon är en ny chans – ett litet steg i taget."))
        }

        // Ge ett förbättringsförslag för det lägsta
        let scores = [("sömnen", log.sleep), ("maten", log.meals),
                      ("utomhustiden", log.outdoor), ("träningen", log.exercise),
                      ("det sociala", log.social)]
        if let lowest = scores.min(by: { $0.1 < $1.1 }), lowest.1 < 3 {
            tips.append(Tip(text: "Monstret undrar: kan du satsa lite extra på \(lowest.0) imorgon?"))
        }

        return Array(tips.prefix(3))
    }
}

// MARK: - 7  Video‑uppspelare utan kontroller
struct MonsterVideoView: UIViewRepresentable {
    let fileName: String
    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(fileName: fileName)
    }
    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.updateVideo(fileName: fileName)
    }
}

final class LoopingPlayerUIView: UIView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    init(fileName: String) { super.init(frame: .zero); layer.cornerRadius = 16; layer.masksToBounds = true; updateVideo(fileName: fileName) }
    required init?(coder: NSCoder) { fatalError() }
    func updateVideo(fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp4") else { return }
        player?.pause()
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        looper = AVPlayerLooper(player: queue, templateItem: item)
        let avLayer = AVPlayerLayer(player: queue)
        avLayer.videoGravity = .resizeAspectFill
        avLayer.frame = bounds
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        layer.addSublayer(avLayer)
        player = queue
        queue.play()
    }
    override func layoutSubviews() { super.layoutSubviews(); layer.sublayers?.first?.frame = bounds }
}

// MARK: - 8  Stilknappar
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.warmLavender, Color.warmRose],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.warmLavender.opacity(0.3), radius: configuration.isPressed ? 2 : 8, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .foregroundStyle(.white)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct OptionButton: View {
    let label: String
    let selected: Bool
    var body: some View {
        Text(label)
            .font(.system(.body, design: .rounded, weight: .medium))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.warmLavender : Color.white.opacity(0.08))
            .foregroundStyle(selected ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(selected ? 0 : 0.1), lineWidth: 1))
    }
}

// MARK: - 9  Tipskort
struct TipsCard: View {
    let tips: [MonsterGPT.Tip]
    var body: some View {
        VStack(spacing: 18) {
            ForEach(tips) { tip in
                Text(tip.text)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(radius: 5, y: 2)
    }
}

// MARK: - 10  Logg‑guide helskärm
struct MonsterLogWizard: View {
    @Environment(\.dismiss) private var dismiss
    
    struct Option { let label: String; let rating: Int }
    
    //‑‑‑ Val (4 knappar vardera)
    private let options: [[Option]] = [
        [ .init(label:"0‑3 h",rating:1), .init(label:"4‑5 h",rating:2),
          .init(label:"6‑7 h",rating:3), .init(label:"8+ h",rating:4) ],
        [ .init(label:"0‑1 mål",rating:1), .init(label:"2 mål",rating:2),
          .init(label:"3 mål",rating:3), .init(label:"4+ mål",rating:4) ],
        [ .init(label:"0 min",rating:1), .init(label:"1‑15 min",rating:2),
          .init(label:"16‑30 min",rating:3), .init(label:"30 min+",rating:4) ],
        [ .init(label:"0 min",rating:1), .init(label:"1‑10 min",rating:2),
          .init(label:"11‑30 min",rating:3), .init(label:"30 min+",rating:4) ],
        [ .init(label:"0 ggr",rating:1), .init(label:"1 gång",rating:2),
          .init(label:"2‑3 ggr",rating:3), .init(label:"4+ ggr",rating:4) ]
    ]
    
    private let prompts = [
        "Hur länge sov du i natt?",
        "Hur många mål mat åt du idag?",
        "Hur länge var du utomhus?",
        "Hur länge rörde du på dig?",
        "Hur många sociala interaktioner hade du?"
    ]
    
    private let facts = [
        "7–9 timmar sömn hjälper minne, immunförsvar och hormonbalans. För lite sömn ökar stress & sötsug.",
        "3–4 måltider jämnar ut blodsocker och ork. Kroppen behöver protein, fullkorn och grönsaker.",
        "Minst 30 min dagsljus om dagen stärker dygnsrytm, humör och D‑vitaminproduktion.",
        "150 min pulshöjande aktivitet/vecka stärker hjärta, muskler och hjärnan. Små steg räknas!",
        "Meningsfull kontakt sänker kortisol och stärker självkänsla. Kort ‘hej’ räknas som interaktion."
    ]
    
    private let stepVideos = [
        "sleep_step",   // lägg sleep_step.mp4 i bundle
        "food_step",    // food_step.mp4
        "sun_step",     // sun_step.mp4
        "move_step",    // move_step.mp4
        "social_step"   // social_step.mp4
    ]
    
    //‑‑‑ State
    @State private var step = 0
    @State private var selections: [Int?] = Array(repeating: nil, count: 5)
    let onDone: (DailyLog) -> Void
    
    //‑‑‑ Layout
    private let grid = Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)
    
    var body: some View {
        VStack(spacing: 24) {
            // Steg-indikator
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.warmLavender : Color.white.opacity(0.15))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 32)
            .animation(.easeOut(duration: 0.3), value: step)

            // Video högst upp
            MonsterVideoView(fileName: stepVideos[step])
                .frame(height: 180)
                .padding(.horizontal, 32)

            Text(prompts[step])
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            LazyVGrid(columns: grid, spacing: 14) {
                ForEach(options[step].indices, id: \.self) { i in
                    let opt = options[step][i]
                    OptionButton(label: opt.label, selected: selections[step] == opt.rating)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(.easeOut(duration: 0.2)) { selections[step] = opt.rating }
                        }
                }
            }
            .padding(.horizontal)
            
            Text(facts[step])
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button(step < 4 ? "Nästa" : "Spara", action: advance)
                .buttonStyle(GradientButtonStyle())
                .padding(.horizontal)
                .disabled(selections[step] == nil)
        }
        .padding(.top, 44)
        .background(Color(hex: 0x1A1025).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
    
    private func advance() {
        guard let _ = selections[step] else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if step < 4 {
            withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let log = DailyLog(
                date: .now,
                sleep: selections[0] ?? 1,
                meals: selections[1] ?? 1,
                outdoor: selections[2] ?? 1,
                exercise: selections[3] ?? 1,
                social: selections[4] ?? 1)
            onDone(log)
            dismiss()
        }
    }
}

// MARK: - 11  MonsterPanel (placera i ContentView)
struct MonsterPanel: View {
    @StateObject private var store = MonsterStore()
    @State private var tips: [MonsterGPT.Tip] = []
    @State private var aiInsight: String = ""
    @State private var loading = false
    @State private var showWizard = false
    private let gpt = MonsterGPT()
    
    var body: some View {
        VStack(spacing: 28) {
            MonsterVideoView(fileName: state.videoFile)
                .frame(maxWidth: .infinity)
            
            Text(state.summary)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            
            if loading {
                ProgressView().padding()
            } else if !tips.isEmpty {
                TipsCard(tips: tips)
                    .transition(.opacity.combined(with: .scale))

                if !aiInsight.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.warmGold)
                            Text("AI-insikt")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Text(aiInsight)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.warmGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.warmGold.opacity(0.2), lineWidth: 1))
                    .transition(.opacity)
                }
            }
            
            Button("Logga din dag") { showWizard = true }
                .buttonStyle(GradientButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
        .fullScreenCover(isPresented: $showWizard) {
            MonsterLogWizard { log in
                store.add(log)
                Task { await loadTips(for: log) }
            }
        }
        .task {
            if let last = store.logs.last { await loadTips(for: last) }
        }
    }
    
    private var state: MonsterState { store.logs.last?.monsterState ?? .idle }
    
    @MainActor
    private func loadTips(for log: DailyLog) async {
        loading = true
        tips = await gpt.fetch(for: log)
        aiInsight = await LillaJagAIService.shared.monsterInsight(for: log)
        loading = false
    }
}

// MARK: - 12  Preview
#Preview {
    MonsterPanel()
        .previewDevice(.init(rawValue: "iPhone 16 Pro Max"))
        .preferredColorScheme(.dark)
}
