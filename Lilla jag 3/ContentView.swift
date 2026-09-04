//
//  ContentView.swift
//  Lilla jag 3
//
//  Created by Ted Svärd on 2025-07-13.
//

import SwiftUI
import AVKit

struct ContentView: View {
    @State private var showText = false
    @State private var showSubtitle = false
    @State private var navigateToAssistant = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                if let videoURL = Bundle.main.url(forResource: "Start", withExtension: "mp4") {
                    LoopingVideoPlayer(videoURL: videoURL)
                        .ignoresSafeArea()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color(hex: 0x1A1025).ignoresSafeArea()
                }

                GeometryReader { geo in
                    VStack(spacing: 0) {
                        Spacer().frame(height: geo.size.height * 0.12)

                        Text("Lilla Jag")
                            .font(.system(size: min(geo.size.width * 0.13, 52), weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                            .opacity(showText ? 1 : 0)
                            .offset(y: showText ? 0 : 20)

                        Text("Appen för dig med psykisk ohälsa")
                            .font(.system(size: min(geo.size.width * 0.055, 22), design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.2), radius: 8)
                            .padding(.top, 8)
                            .opacity(showSubtitle ? 1 : 0)
                            .offset(y: showSubtitle ? 0 : 12)

                        Spacer()

                        // Tap hint
                        if showText {
                            VStack(spacing: 12) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .symbolEffect(.pulse, options: .repeating)
                                Text("Tryck för att börja")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Text("Utvecklad av Ted Svärd")
                            .font(.system(size: min(geo.size.width * 0.035, 15), weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 16)
                            .padding(.bottom, geo.safeAreaInsets.bottom + 28)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .padding()
            }
            // A full-screen tap gesture is not accessible: VoiceOver users and
            // switch-control users need a real, labelled control.
            .overlay(alignment: .bottom) {
                if showText {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                            navigateToAssistant = true
                        }
                    } label: {
                        Label("Börja använda Lilla Jag", systemImage: "arrow.right.circle.fill")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.black.opacity(0.28), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Öppnar appens huvudmeny")
                    .padding(.bottom, 72)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("VideoPaused"))) { _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { showText = true }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.3)) { showSubtitle = true }
                // Do not navigate without user consent. The previous timer made
                // the splash screen unexpectedly disappear for assistive-tech users.
            }
            .onAppear {
                // Fallback: om ingen video finns i bundle visas texten direkt
                // och navigering sker efter 4 sekunder utan att vänta på "VideoPaused"
                if Bundle.main.url(forResource: "Start", withExtension: "mp4") == nil || reduceMotion {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { showText = true }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.3)) { showSubtitle = true }
                }
            }
            .navigationDestination(isPresented: $navigateToAssistant) {
                RootContainer()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

#Preview {
    ContentView()
}

struct LoopingVideoPlayer: UIViewControllerRepresentable {
    let videoURL: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: videoURL)

        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill

        // Start video at 1.5 seconds
        let startTime = CMTime(seconds: 1.5, preferredTimescale: 600)
        player.seek(to: startTime)
        // Respect the user's Reduce Motion preference by keeping the decorative
        // splash still. The explicit start button remains available.
        if !UIAccessibility.isReduceMotionEnabled {
            player.play()
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
            guard let player = player, let currentItem = player.currentItem else { return }

            let duration = CMTimeGetSeconds(currentItem.duration)
            let current = CMTimeGetSeconds(time)

            if duration > 0 && current >= duration - 1 && !context.coordinator.didPostCompletion {
                context.coordinator.didPostCompletion = true
                player.pause()
                NotificationCenter.default.post(name: Notification.Name("VideoPaused"), object: nil)
            }
        }
        context.coordinator.timeObserver = observer
        context.coordinator.player = player

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var timeObserver: Any?
        var player: AVPlayer?
        var didPostCompletion = false

        deinit {
            if let observer = timeObserver, let player = player {
                player.removeTimeObserver(observer)
            }
        }
    }
}
