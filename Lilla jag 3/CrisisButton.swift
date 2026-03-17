// CrisisButton.swift
// Lilla Jag – Flytande SOS-knapp + Krisblad

import SwiftUI
import UIKit

// MARK: - Data

private struct CrisisResource: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let availability: String
    let icon: String
    let color: Color
    let urlString: String
}

private let crisisResources: [CrisisResource] = [
    CrisisResource(
        name: "Självmordslinjen",
        detail: "90101",
        availability: "Dygnet runt, 24/7",
        icon: "phone.fill",
        color: Color(red: 1.0, green: 0.36, blue: 0.36),
        urlString: "tel://90101"
    ),
    CrisisResource(
        name: "Mind Självmordslinjen",
        detail: "Chatt på mind.se",
        availability: "Dygnet runt",
        icon: "message.fill",
        color: Color(red: 1.0, green: 0.6, blue: 0.2),
        urlString: "https://mind.se/hitta-hjalp/sjalvmordslinjen/"
    ),
    CrisisResource(
        name: "SOS Alarm",
        detail: "112",
        availability: "Akut fara – dygnet runt",
        icon: "exclamationmark.triangle.fill",
        color: Color(red: 1.0, green: 0.23, blue: 0.19),
        urlString: "tel://112"
    ),
    CrisisResource(
        name: "Bris",
        detail: "116 111",
        availability: "Unga under 18 år",
        icon: "person.fill",
        color: Color(red: 0.35, green: 0.6, blue: 1.0),
        urlString: "tel://116111"
    ),
    CrisisResource(
        name: "1177 Vårdguiden",
        detail: "1177",
        availability: "Rådgivning dygnet runt",
        icon: "cross.fill",
        color: Color(red: 0.3, green: 0.85, blue: 0.55),
        urlString: "tel://1177"
    )
]

// MARK: - SOSButtonOverlay

struct SOSButtonOverlay: View {
    @State private var showCrisis = false
    @State private var pulseOpacity: Double = 1.0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button {
            showCrisis = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 0.85, green: 0.1, blue: 0.1))
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(red: 1.0, green: 0.1, blue: 0.1).opacity(0.5), radius: 10, x: 0, y: 4)

                VStack(spacing: 2) {
                    Image(systemName: "cross.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                    Text("SOS")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .opacity(pulseOpacity)
        .scaleEffect(pulseScale)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
            ) {
                pulseOpacity = 0.7
                pulseScale = 0.95
            }
        }
        .sheet(isPresented: $showCrisis) {
            CrisisSheetView()
        }
        .accessibilityLabel("SOS – Krishjälp")
        .accessibilityHint("Öppnar krisnummer och stödresurser")
    }
}

// MARK: - CrisisSheetView

struct CrisisSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.05, blue: 0.15)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.fill")
                                .font(.title2)
                                .foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.36))
                            Text("Behöver du hjälp nu?")
                                .font(.system(.title2, design: .rounded, weight: .black))
                                .foregroundStyle(.white)
                        }
                        Text("Du är inte ensam. Det finns hjälp.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Resource cards
                    VStack(spacing: 12) {
                        ForEach(crisisResources) { resource in
                            CrisisResourceCard(resource: resource)
                        }
                    }

                    // Disclaimer
                    Text("Vid omedelbar livsfara, ring 112")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.36).opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Color(red: 1.0, green: 0.1, blue: 0.1).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 1.0, green: 0.1, blue: 0.1).opacity(0.25), lineWidth: 1)
                        )
                        .padding(.bottom, 12)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(20)
            }
            .accessibilityLabel("Stäng")
        }
    }
}

// MARK: - CrisisResourceCard

private struct CrisisResourceCard: View {
    let resource: CrisisResource

    var body: some View {
        Button {
            if let url = URL(string: resource.urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(resource.color.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: resource.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(resource.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.name)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(resource.detail)
                        .font(.system(.callout, design: .monospaced, weight: .semibold))
                        .foregroundStyle(resource.color)
                    Text(resource.availability)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(resource.color.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(resource.color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Modifier

extension View {
    func withSOSButton() -> some View {
        self.overlay(alignment: .bottomLeading) {
            SOSButtonOverlay()
                .padding(.leading, 20)
                .padding(.bottom, 120)
        }
    }
}

// MARK: - Preview

#Preview("SOS Overlay") {
    ZStack {
        Color(red: 0.12, green: 0.08, blue: 0.18).ignoresSafeArea()
        Text("App innehåll")
            .foregroundStyle(.white)
    }
    .withSOSButton()
}

#Preview("Crisis Sheet") {
    CrisisSheetView()
}
