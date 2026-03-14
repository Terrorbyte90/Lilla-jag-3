//
//  Dashboard.swift
//  Lilla Jag
//
//  Förbättringar iteration 2–3:
//  • Emotion-indikator från LillaJagAIService visas i header
//  • Affirmation animeras mjukt vid byte (transition)
//  • Daglig AI-insikt-ruta under citatboxen
//  • Snabbare quick actions med tydligare ikonografi
//

import SwiftUI
import AVKit
import Combine

// MARK: - Dashboard

struct Dashboard: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var ai = LillaJagAIService.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LoopingVideoBackground(videoName: "bloop", fileExtension: "mp4")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: geo.size.height > 800 ? 24 : 18) {
                        header
                        videoBox(geo: geo)
                        quickActions
                        affirmationBox
                        if let emotion = ai.currentEmotion, !ai.messages.isEmpty {
                            emotionCard(emotion: emotion)
                        }
                        ukraineBanner
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, max(16, geo.size.width * 0.06))
                    .padding(.top, 16)
                    .padding(.bottom, 110)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $viewModel.showChatty) { ChattyView() }
        .fullScreenCover(isPresented: $viewModel.showNumbers) { NumbersView() }
        .fullScreenCover(isPresented: $viewModel.showCrisisPlan) { KrisplanView() }
        .fullScreenCover(isPresented: $viewModel.showDonation) { DonationView() }
        .fullScreenCover(isPresented: $viewModel.showForum) { ForumView() }
        .fullScreenCover(isPresented: $viewModel.showPsykolog) { PsykologView() }
        .fullScreenCover(isPresented: $viewModel.showUkraine) { UkraineView() }
        .fullScreenCover(isPresented: $viewModel.showSocial) { SocialView() }
    }
}

// MARK: - Delvyer

private extension Dashboard {

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lilla Jag")
                    .font(DesignSystem.Typography.titleMain)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                    .shadow(radius: 10)
                Text(greetingText)
                    .font(.subheadline)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            HStack(spacing: 8) {
                DashboardHeaderButton(icon: "heart.fill", action: { viewModel.showDonation = true })
                DashboardHeaderButton(icon: "cross.case", action: { viewModel.showCrisisPlan = true })
                DashboardHeaderButton(icon: "phone", action: { viewModel.showNumbers = true })
            }
        }
        .padding(12)
        .ljGlassCard(radius: 18)
        .shadow(radius: 4, y: 2)
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

    func videoBox(geo: GeometryProxy) -> some View {
        let height = min(max(geo.size.height * 0.28, 180), 280)
        return LoopingVideoBackground(videoName: "bipolar", fileExtension: "mp4")
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(radius: 10)
            .frame(height: height)
    }

    var quickActions: some View {
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
        }
    }

    var affirmationBox: some View {
        Text(viewModel.affirmation)
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .ljGlassCard(radius: 18)
            .shadow(radius: 4, y: 2)
            .id(viewModel.affirmation)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .animation(.easeInOut(duration: 0.5), value: viewModel.affirmation)
    }

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
    }

    var ukraineBanner: some View {
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
        }
    }
}

// MARK: - Header button

struct DashboardHeaderButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .ljGlassCard(radius: 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action button

struct DashboardActionButton: View {
    let icon: String
    let label: String
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
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
