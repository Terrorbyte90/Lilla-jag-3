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
    // Citat
    @State private var affirmation: String = AffirmationManager.random()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    // Chatty
    @State private var showChatty = false
    // Numbers
    @State private var showNumbers = false
    // Krisplan
    @State private var showCrisisPlan = false
    // Donation
    @State private var showDonation = false
    // Forum
    @State private var showForum = false
    
    var body: some View {
        ZStack {
            // Bakgrundsvideon
            LoopingVideoBackground(videoName: "bloop", fileExtension: "mp4")
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 32) {
                header
                videoBox
                quickActions
                affirmationBox
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 80)
            .padding(.bottom, 20)
          //  .offset(y: -UIScreen.main.bounds.height * 0.04)
        }
        .preferredColorScheme(.dark)
        // uppdatera citat
        .onReceive(timer) { _ in affirmation = AffirmationManager.random() }
        // chatty‑sheet
        .fullScreenCover(isPresented: $showChatty) { ChattyView() }
        // numbers‑sheet
        .fullScreenCover(isPresented: $showNumbers) { NumbersView() }
        // krisplan‑sheet
        .fullScreenCover(isPresented: $showCrisisPlan) { KrisplanView() }
        // donation‑sheet
        .fullScreenCover(isPresented: $showDonation) { DonationView() }
        // forum‑sheet
        .fullScreenCover(isPresented: $showForum) { ForumView() }
    }
}

// MARK: ‑ Delvyer
private extension Dashboard {
    
    // Rubriker
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Lilla Jag")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 10)

                Text("Välkommen in i värmen!")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            HStack(spacing: 12) {
                Button(action: { showDonation = true }) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.25),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                // Krisplan‑knapp
                Button(action: { showCrisisPlan = true }) {
                    Image(systemName: "cross.case")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.25),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                // Telefon‑knapp
                Button(action: { showNumbers = true }) {
                    Image(systemName: "phone")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.25),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.25),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(radius: 4, y: 2)
        .padding(.top, -40)
    }
    
    // Stora videorutan
    var videoBox: some View {
        LoopingVideoBackground(videoName: "bipolar", fileExtension: "mp4")
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(radius: 10)
            .frame(height: 250)
    }
    
    // Snabba åtgärder
    var quickActions: some View {
        HStack(spacing: 16) {
            DashboardActionButton(icon: "bubble.left.and.bubble.right",
                                  label: "Chatt") {
                showChatty = true
            }
            DashboardActionButton(icon: "person.3", label: "Forum") {
                showForum = true
            }
            DashboardActionButton(icon: "book.closed", label: "Dagbok") { }
        }
    }
    
    // Citatbox
    var affirmationBox: some View {
        Text(affirmation)
            .font(.headline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1))
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
            .background(.ultraThinMaterial.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
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
