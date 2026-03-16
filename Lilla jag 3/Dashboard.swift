//
//  Dashboard.swift
//  Lilla Jag
//

import SwiftUI
import AVKit
import Combine

// MARK: - Dashboard

struct Dashboard: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var ai = LillaJagAIService.shared
    @State private var appearedSections: Set<Int> = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LoopingVideoBackground(videoName: "bloop", fileExtension: "mp4")
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        heroSection(geo: geo)
                        quickActionsSection
                            .appeared(index: 0, appeared: $appearedSections)
                        if let emotion = ai.currentEmotion, !ai.messages.isEmpty {
                            emotionCard(emotion: emotion)
                                .appeared(index: 1, appeared: $appearedSections)
                        }
                        supportRow
                            .appeared(index: 2, appeared: $appearedSections)
                        affirmationSection
                            .appeared(index: 3, appeared: $appearedSections)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, 110)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $viewModel.showChatty)     { ChattyView() }
        .fullScreenCover(isPresented: $viewModel.showNumbers)    { NumbersView() }
        .fullScreenCover(isPresented: $viewModel.showCrisisPlan) { KrisplanView() }
        .fullScreenCover(isPresented: $viewModel.showDonation)   { DonationView() }
        .fullScreenCover(isPresented: $viewModel.showForum)      { ForumView() }
        .fullScreenCover(isPresented: $viewModel.showPsykolog)   { PsykologView() }
        .fullScreenCover(isPresented: $viewModel.showUkraine)    { UkraineView() }
        .fullScreenCover(isPresented: $viewModel.showSocial)     { SocialView() }
    }
}

// MARK: - Subviews

private extension Dashboard {

    // ─── HERO ────────────────────────────────────────────────────────────────

    func heroSection(geo: GeometryProxy) -> some View {
        let height = DesignSystem.Size.heroHeight(for: geo.size.height)
        return ZStack(alignment: .bottom) {
            // Background video
            LoopingVideoBackground(videoName: "bipolar", fileExtension: "mp4")
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.extraLarge,
                                            style: .continuous))

            // Gradient overlay for legibility
            LinearGradient(
                colors: [.clear, Color(hex: 0x110D1C).opacity(0.55), Color(hex: 0x110D1C).opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.extraLarge, style: .continuous))

            // Content overlay
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingLabel)
                    .font(DesignSystem.Typography.overline)
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(1.2)
                    .textCase(.uppercase)

                Text("Lilla Jag")
                    .font(DesignSystem.Typography.titleLarge)
                    .foregroundStyle(.white)

                Text(viewModel.affirmation)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(2)
                    .id(viewModel.affirmation)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.affirmation)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.extraLarge, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .ljShadowMedium()
        // Header action buttons top-right
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                DashboardHeaderButton(icon: "heart.fill",  color: .warmRose,    action: { viewModel.showDonation = true })
                DashboardHeaderButton(icon: "cross.case",  color: Color(hex: 0x6ECFF6), action: { viewModel.showCrisisPlan = true })
                DashboardHeaderButton(icon: "phone",       color: .warmSage,    action: { viewModel.showNumbers = true })
            }
            .padding(DesignSystem.Spacing.md)
        }
    }

    var greetingLabel: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "God morgon"
        case 12..<18: return "God eftermiddag"
        case 18..<23: return "God kväll"
        default:      return "Välkommen"
        }
    }

    // ─── QUICK ACTIONS ────────────────────────────────────────────────────────

    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            LJSectionHeader(title: "Snabbverktyg")
            HStack(spacing: 12) {
                DashboardActionButton(
                    icon: "bubble.left.and.bubble.right.fill",
                    label: "Chatta",
                    gradient: LinearGradient(colors: [.warmLavender, Color(hex: 0x9B6FD6)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                    action: { viewModel.showChatty = true }
                )
                DashboardActionButton(
                    icon: "person.3.fill",
                    label: "Forum",
                    gradient: LinearGradient(colors: [.warmSage, Color(hex: 0x34D399)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                    action: { viewModel.showForum = true }
                )
                DashboardActionButton(
                    icon: "stethoscope",
                    label: "Psykolog",
                    gradient: LinearGradient(colors: [Color(hex: 0x6ECFF6), Color(hex: 0x38BDF8)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                    action: { viewModel.showPsykolog = true }
                )
            }
        }
    }

    // ─── EMOTION CARD ─────────────────────────────────────────────────────────

    func emotionCard(emotion: EmotionResult) -> some View {
        Button { viewModel.showChatty = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(emotion.color.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: emotion.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(emotion.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Din senaste känsla")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    Text(emotion.dominant.name.capitalized)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(emotion.color)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(DesignSystem.Spacing.md)
            .ljGlassCard(radius: DesignSystem.Radius.medium, fill: emotion.color.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                    .stroke(emotion.color.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.5), value: emotion.dominant.name)
    }

    // ─── SUPPORT ROW ─────────────────────────────────────────────────────────

    var supportRow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            LJSectionHeader(title: "Stöd & resurser")
            HStack(spacing: 12) {
                SupportCard(
                    icon: "heart.fill",
                    label: "Stöd Ukraina",
                    sublabel: "Gör skillnad",
                    gradient: LinearGradient(colors: [Color(hex: 0x3B82F6), Color(hex: 0xEAB308)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                    action: { viewModel.showUkraine = true }
                )
                SupportCard(
                    icon: "person.2.fill",
                    label: "Socialt stöd",
                    sublabel: "Hitta gemenskap",
                    gradient: LinearGradient(colors: [.warmRose, .warmLavender],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                    action: { viewModel.showSocial = true }
                )
            }
        }
    }

    // ─── AFFIRMATION ─────────────────────────────────────────────────────────

    var affirmationSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            LJSectionHeader(title: "Dagens påminnelse")
            HStack(spacing: 14) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(DesignSystem.Colors.brandGradient)
                Text(viewModel.affirmation)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .id(viewModel.affirmation)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.affirmation)
            }
            .padding(DesignSystem.Spacing.md)
            .ljGlassCard(radius: DesignSystem.Radius.medium, fill: DesignSystem.Colors.glassMedium)
        }
    }
}

// MARK: - Header Button

struct DashboardHeaderButton: View {
    let icon: String
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.35), in: Circle())
                .overlay(Circle().stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Button

struct DashboardActionButton: View {
    let icon: String
    let label: String
    var gradient: LinearGradient = DesignSystem.Colors.brandGradient
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(gradient)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.glassMedium,
                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}

// MARK: - Support Card

struct SupportCard: View {
    let icon: String
    let label: String
    let sublabel: String
    let gradient: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(gradient)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(sublabel)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                Spacer()
            }
            .padding(12)
            .ljGlassCard(radius: DesignSystem.Radius.medium)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Appeared modifier (stagger)

private struct AppearedModifier: ViewModifier {
    let index: Int
    @Binding var appeared: Set<Int>

    func body(content: Content) -> some View {
        content
            .opacity(appeared.contains(index) ? 1 : 0)
            .offset(y: appeared.contains(index) ? 0 : 18)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)
                    .delay(Double(index) * 0.08)) {
                    appeared.insert(index)
                }
            }
    }
}

private extension View {
    func appeared(index: Int, appeared: Binding<Set<Int>>) -> some View {
        modifier(AppearedModifier(index: index, appeared: appeared))
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
        "Din hjärna gör sitt bästa – det räcker."
    ]
    static func random() -> String { list.randomElement() ?? "" }
}

// MARK: - Preview

#Preview {
    Dashboard()
        .preferredColorScheme(.dark)
}
