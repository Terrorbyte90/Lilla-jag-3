//
//  Psykolog.swift
//  LillaJag3
//
//  Skapad: 26 juli 2025
//
//  Boka tid hos Mindler via inbäddad webbvy.
//  UI-matchar appens glasstil och mörkt/ljust läge.
//

import SwiftUI
import WebKit

// MARK: – Inbäddad WebView

struct InAppWebView: UIViewRepresentable {

    // URL som ska laddas
    let url: URL

    final class Coordinator: NSObject, WKNavigationDelegate {
        // Håll koll på extern navigering om du vill bryta ut vissa länkar till Safari.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            // Exempel: öppna externa domäner i Safari
            /*
            if let host = navigationAction.request.url?.host,
               host.contains("mindler.se") == false {
                UIApplication.shared.open(navigationAction.request.url!)
                decisionHandler(.cancel)
                return
            }
             */
            decisionHandler(.allow)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero,
                                configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
}

// MARK: – Huvudvy

struct PsykologView: View {

    // MARK: – State
    @State private var showBooking = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // MARK: – Body
    var body: some View {
        ZStack {
            // Bakgrundsvideon
            LoopingVideoBackground(videoName: "bloop", fileExtension: "mp4")
                .ignoresSafeArea()

            Color.black.opacity(0.4)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    rubrik
                    infoKort
                    bokaKnapp
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 60)
            }
            
            // Stäng-knapp
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        // Fullskärms‑modal med inbäddad webb
        .fullScreenCover(isPresented: $showBooking) {
            BookingWebContainer {
                showBooking = false
            }
        }
    }

    // MARK: – Delvyer

    private var rubrik: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Psykologhjälp")
                .font(.largeTitle.weight(.bold))
            Text("Via Mindler – ingen väntetid")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var infoKort: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "video.bubble.left.fill")
                    .font(.title2)
                Text("Videosamtal med legitimerad psykolog")
            }
            HStack(spacing: 12) {
                Image(systemName: "banknote.fill")
                    .font(.title2)
                Text("100 kr per besök – frikort gäller")
            }
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title2)
                Text("Öppet 07–22 alla dagar")
            }
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                Text("IKBT‑program & självhjälp")
            }
        }
        .font(.body)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var bokaKnapp: some View {
        Button {
            showBooking = true
        } label: {
            HStack {
                Image(systemName: "arrow.up.right.square.fill")
                Text("Boka tid i Mindler")
                    .font(.headline)
                    .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .padding(.top, 8)
    }
}

// MARK: – Container för fullskärms‑webb

private struct BookingWebContainer: View {

    // Action för att stänga
    let onClose: () -> Void

    // Mindlers boknings‑URL
    private let bookingURL = URL(string: "https://mindler.se/boka")!

    var body: some View {
        NavigationStack {
            InAppWebView(url: bookingURL)
                .ignoresSafeArea()
                .navigationTitle("Mindler")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Stäng‑knapp till höger
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Stäng") { onClose() }
                    }
                }
        }
    }
}

// MARK: – Preview

#Preview("Psykolog‑vy (in‑app‑webb)") {
    PsykologView()
        .previewDevice(.init(rawValue: "iPhone 16 Pro"))
        .environment(\.colorScheme, .dark)
}
