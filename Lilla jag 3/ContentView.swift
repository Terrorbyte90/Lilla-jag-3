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
    @State private var navigateToAssistant = false

    var body: some View {
        NavigationStack {
            ZStack {
                if let videoURL = Bundle.main.url(forResource: "Start", withExtension: "mp4") {
                    LoopingVideoPlayer(videoURL: videoURL)
                        .ignoresSafeArea()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.black.ignoresSafeArea()
                }

                GeometryReader { geo in
                    VStack {
                        Spacer().frame(height: geo.size.height * 0.12)

                        Text("Lilla Jag")
                            .font(.system(size: min(geo.size.width * 0.14, 56), weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(radius: 10)

                        Text("Appen för dig med psykisk ohälsa")
                            .font(.system(size: min(geo.size.width * 0.065, 28)))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(radius: 5)

                        Spacer()

                        Text("Utvecklad av Ted Svärd")
                            .font(.system(size: min(geo.size.width * 0.038, 16), weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.bottom, geo.safeAreaInsets.bottom + 32)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .padding()
                .opacity(showText ? 1 : 0)
                .scaleEffect(showText ? 1 : 0.8)
                .animation(.easeInOut(duration: 1.0), value: showText)
            }
            .onTapGesture {
                navigateToAssistant = true
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("VideoPaused"))) { _ in
                showText = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    navigateToAssistant = true
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
        player.play()

        context.coordinator.player = player
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        context.coordinator.timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
            guard let player = player, let currentItem = player.currentItem else { return }
            
            let duration = CMTimeGetSeconds(currentItem.asset.duration)
            let current = CMTimeGetSeconds(time)
            
            if duration > 0 && current >= duration - 1 {
                player.pause()
                NotificationCenter.default.post(name: Notification.Name("VideoPaused"), object: nil)
            }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var timeObserver: Any?
        var player: AVPlayer?

        deinit {
            if let obs = timeObserver {
                player?.removeTimeObserver(obs)
                timeObserver = nil
            }
        }
    }
}
