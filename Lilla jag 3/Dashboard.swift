//
//  Dashboard.swift
//  Lilla Jag
//
//  Förbättringar iteration 4 – App Store-optimerade:
//  • Daglig humör-incheckning (som Daylio/Headspace)
//  • Streak-räknare med gamification
//  • Andningsövning-snabbåtkomst
//  • Förbättrad sektionsstruktur med headers
//  • Accessibility-labels på alla interaktiva element
//  • Haptic feedback på knapptryck
//

import SwiftUI
import AVKit
import Combine

// MARK: - Dashboard

struct Dashboard: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var ai = LillaJagAIService.shared
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LoopingVideoBackground(videoName: "bloop", fileExtension: "mp4")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: geo.size.height > 800 ? 20 : 16) {
                        header
                        dailyCheckInCard
                        streakAndProgressBar
                        quickActions
                        breathingQuickAccess
                        affirmationBox
                        monsterSection
                        if let emotion = ai.currentEmotion, !ai.messages.isEmpty {
                            emotionCard(emotion: emotion)
                        }
                        ukraineBanner
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, max(16, geo.size.width * 0.06))
                    .padding(.top, 16)
                    .padding(.bottom, 110)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
        .fullScreenCover(isPresented: $viewModel.showChatty) { ChattyView() }
        .fullScreenCover(isPresented: $viewModel.showNumbers) { NumbersView() }
        .fullScreenCover(isPresented: $viewModel.showCrisisPlan) { KrisplanView() }
        .fullScreenCover(isPresented: $viewModel.showDonation) { DonationView() }
        .fullScreenCover(isPresented: $viewModel.showForum) { ForumView() }
        .fullScreenCover(isPresented: $viewModel.showPsykolog) { PsykologView() }
        .fullScreenCover(isPresented: $viewModel.showUkraine) { UkraineView() }
        .fullScreenCover(isPresented: $viewModel.showSocial) { SocialView() }
        .fullScreenCover(isPresented: $viewModel.showBreathing) { BreathingQuickView() }
        .fullScreenCover(isPresented: $viewModel.showMonster) {
            MonsterLogWizard { log in
                viewModel.monsterStore.add(log)
                viewModel.lastMonsterLog = log
            }
        }
        .fullScreenCover(isPresented: $viewModel.showAchievements) {
            AchievementsGridView()
        }
        .fullScreenCover(isPresented: $viewModel.showSOS) { CrisisSheetView() }
        .task {
            await NotificationManager.shared.requestPermission()
        }
    }
}

// MARK: - Delvyer

private extension Dashboard {

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lilla Jag")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                Text(greetingText)
                    .font(.system(.subheadline, design: .rounded))
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Lilla Jag. \(greetingText)")
            Spacer()
            HStack(spacing: 8) {
                DashboardHeaderButton(icon: "heart.fill", label: "Donera", action: { viewModel.showDonation = true })
                DashboardHeaderButton(icon: "cross.case.fill", label: "Krisplan", action: { viewModel.showCrisisPlan = true })
                DashboardHeaderButton(icon: "phone.fill", label: "Krisnummer", action: { viewModel.showNumbers = true })
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .ljGlassCard(radius: 18)
    }

    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "God morgon!"
        case 12..<18: return "God eftermiddag!"
        case 18..<23: return "God kväll!"
        default: return "Välkommen in i värmen!"
        }
    }

    // MARK: - Daily Check-In (inspirerat av Daylio/Headspace)

    var dailyCheckInCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: viewModel.hasCheckedInToday ? "checkmark.circle.fill" : "sun.horizon.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(viewModel.hasCheckedInToday ? Color.warmSage : Color.warmGold)
                Text(viewModel.hasCheckedInToday ? "Incheckat idag!" : "Hur mår du idag?")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }

            if !viewModel.hasCheckedInToday {
                HStack(spacing: 0) {
                    ForEach(QuickMood.allCases, id: \.rawValue) { mood in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                viewModel.selectedQuickMood = mood
                                viewModel.hasCheckedInToday = true
                                viewModel.recordCheckIn()
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 5) {
                                Text(mood.emoji)
                                    .font(.system(size: 30))
                                    .scaleEffect(viewModel.selectedQuickMood == mood ? 1.2 : 1.0)
                                Text(mood.rawValue)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                viewModel.selectedQuickMood == mood
                                ? mood.color.opacity(0.2)
                                : Color.clear,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Humör: \(mood.rawValue)")
                    }
                }
            } else if let mood = viewModel.selectedQuickMood {
                HStack(spacing: 10) {
                    Text(mood.emoji)
                        .font(.system(size: 28))
                    Text("Du mår \(mood.rawValue.lowercased()) idag")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.warmSage)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(14)
        .ljGlassCard(radius: 18)
        .shadow(radius: 4, y: 2)
    }

    // MARK: - Streak & Progress (gamification som Duolingo/Headspace)

    var streakAndProgressBar: some View {
        HStack(spacing: 14) {
            // Streak
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.warmGold.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(viewModel.currentStreak > 0 ? Color.warmGold : Color.white.opacity(0.3))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(viewModel.currentStreak)")
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                    Text(viewModel.currentStreak == 1 ? "dag i rad" : "dagar i rad")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .ljGlassCard(radius: 14)
            .accessibilityLabel("Streak: \(viewModel.currentStreak) dagar i rad")

            // Weekly progress dots
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { day in
                    let isActive = day < viewModel.currentStreak
                    Circle()
                        .fill(isActive ? Color.warmSage : Color.white.opacity(0.1))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(isActive ? Color.warmSage.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                        )
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Veckomål")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(min(viewModel.currentStreak, 7))/7")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.warmSage)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .ljGlassCard(radius: 14)
            .accessibilityLabel("Veckomål: \(min(viewModel.currentStreak, 7)) av 7 dagar")
        }
    }

    // MARK: - Quick Actions

    var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Snabbåtgärder", icon: "bolt.fill")
            HStack(spacing: 12) {
                DashboardActionButton(icon: "bubble.left.and.bubble.right.fill",
                                      label: "Chatt",
                                      color: Color.warmLavender) {
                    viewModel.showChatty = true
                }
                DashboardActionButton(icon: "person.3.fill",
                                      label: "Forum",
                                      color: Color.warmSage) {
                    viewModel.showForum = true
                }
                DashboardActionButton(icon: "stethoscope",
                                      label: "Psykolog",
                                      color: Color(hex: 0x6ECFF6)) {
                    viewModel.showPsykolog = true
                }
                DashboardActionButton(icon: "trophy.fill",
                                      label: "Prestationer",
                                      color: Color.warmGold) {
                    viewModel.showAchievements = true
                }
            }
        }
    }

    // MARK: - Breathing Quick Access (som Calm/Headspace)

    var breathingQuickAccess: some View {
        Button {
            viewModel.showBreathing = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x6ECFF6).opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "wind")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color(hex: 0x6ECFF6))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Andas lugnt")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("1 minut · Snabb avslappning")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: 0x6ECFF6).opacity(0.8))
            }
            .padding(14)
            .ljGlassCard(radius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Starta andningsövning. 1 minut snabb avslappning.")
    }

    // MARK: - Affirmation

    var affirmationBox: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.warmGold.opacity(0.6))
                Text("Dagens påminnelse")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.warmGold.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(viewModel.affirmation)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.warmGold.opacity(0.06), Color.warmLavender.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .ljGlassCard(radius: 18)
        .id(viewModel.affirmation)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .animation(.easeInOut(duration: 0.5), value: viewModel.affirmation)
        .accessibilityLabel("Dagens påminnelse: \(viewModel.affirmation)")
    }

    // MARK: - Monster Section

    var monsterSection: some View {
        let state = viewModel.lastMonsterLog?.monsterState ?? .idle
        let hasLog = viewModel.lastMonsterLog != nil

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                LJIconCircle(icon: "pawprint.fill", color: Color.warmLavender, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ditt monster")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(hasLog ? state.summary : "Monstret väntar på din dagliga logg!")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }

            if hasLog, let log = viewModel.lastMonsterLog {
                // Kompakt visning av dagens resultat
                HStack(spacing: 8) {
                    monsterStat("Sömn", value: log.sleep, icon: "moon.fill")
                    monsterStat("Mat", value: log.meals, icon: "fork.knife")
                    monsterStat("Ute", value: log.outdoor, icon: "sun.max.fill")
                    monsterStat("Rörelse", value: log.exercise, icon: "figure.walk")
                    monsterStat("Socialt", value: log.social, icon: "person.2.fill")
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.showMonster = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasLog ? "arrow.clockwise" : "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(hasLog ? "Logga igen" : "Logga din dag")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [Color.warmLavender, Color.warmRose],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(LJPressableButtonStyle())
        }
        .padding(14)
        .ljGlassCard(radius: 18)
    }

    func monsterStat(_ label: String, value: Int, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(value >= 3 ? Color.warmSage : Color.white.opacity(0.35))
            Text("\(value)/4")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(value >= 3 ? .white : .white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(value >= 3 ? Color.warmSage.opacity(0.1) : Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Emotion Card

    func emotionCard(emotion: EmotionResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(emotion.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: emotion.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(emotion.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Din senaste känsla")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(emotion.dominant.name.capitalized)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(emotion.color)
            }
            Spacer()
            Button {
                viewModel.showChatty = true
            } label: {
                Text("Prata om det")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(emotion.color.opacity(0.3), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .ljGlassCard(radius: 16)
        .shadow(radius: 4, y: 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.5), value: emotion.dominant.name)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Din senaste känsla: \(emotion.dominant.name)")
    }

    // MARK: - Ukraine & Social

    var ukraineBanner: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    viewModel.showUkraine = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(LinearGradient(colors: [.blue, .yellow], startPoint: .top, endPoint: .bottom))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Stöd Ukraina")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Gör skillnad")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ljGlassCard(radius: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stöd Ukraina")

                Button {
                    viewModel.showSocial = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Socialt")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Hitta vänner")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ljGlassCard(radius: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Socialt, hitta vänner")
            }

            // SOS-knapp centrerad
            Button {
                viewModel.showSOS = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Behöver du akut stöd?")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [Color(hex: 0xCC2222), Color(hex: 0xFF4444)],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: Color(hex: 0xFF2222).opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(LJPressableButtonStyle())
            .accessibilityLabel("Akut stöd och krisnummer")
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.leading, 4)
    }
}

// MARK: - Header button

struct DashboardHeaderButton: View {
    let icon: String
    var label: String = ""
    let action: () -> Void
    var body: some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .ljGlassCard(radius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Action button

struct DashboardActionButton: View {
    let icon: String
    let label: String
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .ljGlassCard(radius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - LoopingVideoBackground

struct LoopingVideoBackground: UIViewControllerRepresentable {
    let videoName: String
    let fileExtension: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .clear

        guard let url = Bundle.main.url(forResource: videoName, withExtension: fileExtension) else {
            return controller
        }

        let playerItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        let looper = AVPlayerLooper(player: player, templateItem: playerItem)
        context.coordinator.looper = looper
        controller.player = player
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
    class Coordinator { var looper: AVPlayerLooper? }
}

// MARK: - AffirmationManager

struct AffirmationManager {
    private static let list: [String] = [
        "Du är modigare än du tror.",
        "Andas djupt – allt ordnar sig.",
        "Dina känslor är viktiga.",
        "Du förtjänar omtanke och ro.",
        "Ett litet steg är också framsteg.",
        "Du är inte ensam i det här.",
        "Tack för att du fortsätter kämpa.",
        "Du duger precis som du är.",
        "Varje dag är en ny chans.",
        "Din hjärna gör sitt bästa – det räcker.",
        "Det är okej att inte vara okej.",
        "Du är starkare än dina svåraste dagar.",
        "Att be om hjälp är modigt.",
        "Du förtjänar samma kärlek du ger andra.",
        "Varje andetag är en ny början.",
        "Du gör framsteg, även när det inte känns så.",
        "Det är okej att ta det lugnt idag.",
        "Du är värd att bli lyssnad på.",
        "Mörker varar inte för evigt.",
        "Din resa är unik och värdefull.",
        "Självmedkänsla är inte svaghet – det är styrka.",
        "Du har klarat svåra saker förut.",
        "Idag räcker det att bara vara.",
        "Dina tankar definierar inte vem du är.",
        "Du förtjänar vila utan skuldkänslor."
    ]
    static func random() -> String { list.randomElement() ?? "" }
}

// MARK: - BreathingQuickView (snabb andningsövning)

struct BreathingQuickView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: BreathPhase = .inhale
    @State private var circleScale: CGFloat = 0.5
    @State private var timer: Timer?
    @State private var secondsLeft = 60
    @State private var isActive = false

    enum BreathPhase: String {
        case inhale = "Andas in"
        case hold = "Håll"
        case exhale = "Andas ut"

        var duration: Double {
            switch self {
            case .inhale: return 4
            case .hold:   return 4
            case .exhale: return 4
            }
        }

        var next: BreathPhase {
            switch self {
            case .inhale: return .hold
            case .hold:   return .exhale
            case .exhale: return .inhale
            }
        }

        var color: Color {
            switch self {
            case .inhale: return Color(hex: 0x6ECFF6)
            case .hold:   return Color.warmLavender
            case .exhale: return Color.warmSage
            }
        }
    }

    var body: some View {
        ZStack {
            WarmBackground()

            VStack(spacing: 40) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(timeString)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                // Animated circle
                ZStack {
                    Circle()
                        .fill(phase.color.opacity(0.08))
                        .frame(width: 260, height: 260)
                    Circle()
                        .fill(phase.color.opacity(0.15))
                        .frame(width: 200, height: 200)
                        .scaleEffect(circleScale)
                    Circle()
                        .fill(phase.color.opacity(0.25))
                        .frame(width: 140, height: 140)
                        .scaleEffect(circleScale)
                    Text(phase.rawValue)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
                .animation(.easeInOut(duration: phase.duration), value: circleScale)

                Spacer()

                if !isActive {
                    Button {
                        startBreathing()
                    } label: {
                        Text("Börja andas")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                } else {
                    Text("Följ cirkeln och andas lugnt")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 40)
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { timer?.invalidate() }
    }

    private var timeString: String {
        let m = secondsLeft / 60
        let s = secondsLeft % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startBreathing() {
        isActive = true
        advancePhase()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                secondsLeft -= 1
                if secondsLeft <= 0 {
                    timer?.invalidate()
                    dismiss()
                }
            }
        }
    }

    private func advancePhase() {
        // Set scale based on phase
        withAnimation(.easeInOut(duration: phase.duration)) {
            switch phase {
            case .inhale: circleScale = 1.0
            case .hold:   circleScale = 1.0
            case .exhale: circleScale = 0.5
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + phase.duration) {
            if isActive && secondsLeft > 0 {
                phase = phase.next
                advancePhase()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Dashboard()
        .preferredColorScheme(.dark)
}
