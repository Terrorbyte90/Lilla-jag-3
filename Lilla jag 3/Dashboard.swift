//
//  Dashboard.swift
//  Lilla Jag
//
//  Den ursprungliga layouten är bevarad men justerad enligt önskemålen:
//
//  • “Stora rutan” under välkomsttexten spelar nu videoloopen *bipolar.mp4*.
//  • Citatet har fått glasram, saknar citattecken och byts var 30:e s.
//  • “Logga humör” → “Chatta anonymt” och öppnar ChattyView helskärm utan back‑pil.
//  • Statistik ersatt av en info‑ruta om psykisk ohälsa och om appens skapare.
//  • Dagbok‑ och Andas‑knapparna ligger kvar men är inaktiva.
//

import SwiftUI
import AVKit
import Combine

// MARK: ‑ Övergripande Dashboard‑vy
struct Dashboard: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        ZStack {
            // Bakgrundsvideon
            LoopingVideoBackground(videoName: "bloop", fileExtension: "mp4")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    videoBox
                    quickActions
                    affirmationBox
                    ukraineBanner
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 100) // Plats för navbar
            }
        }
        .preferredColorScheme(.dark)
        // chatty‑sheet
        .fullScreenCover(isPresented: $viewModel.showChatty) { ChattyView() }
        // numbers‑sheet
        .fullScreenCover(isPresented: $viewModel.showNumbers) { NumbersView() }
        // krisplan‑sheet
        .fullScreenCover(isPresented: $viewModel.showCrisisPlan) { KrisplanView() }
        // donation‑sheet
        .fullScreenCover(isPresented: $viewModel.showDonation) { DonationView() }
        // forum‑sheet
        .fullScreenCover(isPresented: $viewModel.showForum) { ForumView() }
        // psykolog-sheet
        .fullScreenCover(isPresented: $viewModel.showPsykolog) { PsykologView() }
        // ukraine-sheet
        .fullScreenCover(isPresented: $viewModel.showUkraine) { UkraineView() }
        // social-sheet
        .fullScreenCover(isPresented: $viewModel.showSocial) { SocialView() }
    }
}

// MARK: ‑ Delvyer
private extension Dashboard {
    
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
    
    // Rubriker
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Lilla Jag")
                    .font(DesignSystem.Typography.titleMain)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                    .shadow(radius: 10)

                Text("Välkommen in i värmen!")
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
}

// MARK: - Hjälpkomponent för header-knappar
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

private extension Dashboard {
    
    // Stora videorutan
    var videoBox: some View {
        GeometryReader { geo in
            LoopingVideoBackground(videoName: "bipolar", fileExtension: "mp4")
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(radius: 10)
        }
        .frame(height: 250)
    }
    
    // Snabba åtgärder
    var quickActions: some View {
        HStack(spacing: 16) {
            DashboardActionButton(icon: "bubble.left.and.bubble.right",
                                  label: "Chatt") {
                viewModel.showChatty = true
            }
            DashboardActionButton(icon: "person.3", label: "Forum") {
                viewModel.showForum = true
            }
            DashboardActionButton(icon: "video.bubble.left", label: "Psykolog") {
                viewModel.showPsykolog = true
            }
        }
    }
    
    // Citatbox
    var affirmationBox: some View {
        Text(viewModel.affirmation)
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .center)
            .ljGlassCard(radius: 18)
            .shadow(radius: 4, y: 2)
    }
}

// MARK: ‑ Snabbknappskomponent
struct DashboardActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity)
            .ljGlassCard(radius: 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: ‑ LoopingVideoBackground (oförändrad)
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

// MARK: ‑ AffirmationManager
struct AffirmationManager {
    private static let list: [String] = [
        "Du är modigare än du tror.",
        "Andas djupt – allt ordnar sig.",
        "Dina känslor är viktiga.",
        "Du förtjänar omtanke och ro.",
        "Ett litet steg är också framsteg.",
        "Du är inte ensam i det här.",
        "Tack för att du fortsätter kämpa.",
        "Du duger precis som du är."
    ]
    static func random() -> String { list.randomElement() ?? "" }
}


// MARK: ‑ Preview
#Preview {
    Dashboard()
        .previewDevice("iPhone 16 Pro Max")
        .preferredColorScheme(.dark)
}
