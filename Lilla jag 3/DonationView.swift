// DonationView.swift
// Lilla Jag – Stöd appen

import SwiftUI

struct DonationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var aiMotivation: String = ""

    private let organizations: [(name: String, url: String, desc: String, icon: String, color: Color)] = [
        ("Mind", "https://mind.se/stod-oss/", "Arbetar för psykisk hälsa i Sverige. Driver Självmordslinjen.", "heart.fill", Color.warmRose),
        ("SPES", "https://spes.se", "Riksförbundet för suicidprevention och efterlevandestöd.", "hand.raised.fill", Color.warmLavender),
        ("Hjärnfonden", "https://hjarnfonden.se", "Forskning om hjärna och psykisk hälsa.", "brain.head.profile", Color(hex: 0x6ECFF6))
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 14) {
                            LJIconCircle(icon: "heart.fill", color: Color.warmRose, size: 72)

                            Text("Stöd psykisk hälsa")
                                .font(.system(.title2, design: .rounded, weight: .black))
                                .foregroundStyle(.white)

                            Text("Lilla Jag är gratis. Du kan stötta oss och organisationer som arbetar för psykisk hälsa i Sverige.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .background(Color.warmRose.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))

                        // AI-motivation
                        if !aiMotivation.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles").foregroundStyle(Color.warmGold)
                                    Text("Visste du?")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                Text(aiMotivation)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineSpacing(3)
                            }
                            .padding(14)
                            .background(Color.warmGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.warmGold.opacity(0.2), lineWidth: 1))
                        }

                        appSupportSection

                        Text("Stöd dessa organisationer")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(organizations, id: \.name) { org in
                            orgCard(org)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .task { aiMotivation = await LillaJagAIService.shared.donationMotivation() }
            .preferredColorScheme(.dark)
            .navigationTitle("Ge tillbaka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var appSupportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stöd Lilla Jag")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Det bästa sättet att stötta är att berätta om appen för någon du bryr dig om.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            ShareLink(item: "Kolla in Lilla Jag – en gratis app för psykisk hälsa med KBT-verktyg och lokal AI. https://apps.apple.com/app/lilla-jag") {
                Label("Dela appen", systemImage: "square.and.arrow.up")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.warmGold, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private func orgCard(_ org: (name: String, url: String, desc: String, icon: String, color: Color)) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(org.color.opacity(0.2)).frame(width: 48, height: 48)
                Image(systemName: org.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(org.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(org.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(org.desc)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }
            Spacer()
            if let url = URL(string: org.url) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(org.color)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(org.color.opacity(0.2), lineWidth: 1))
    }
}

#Preview {
    DonationView()
}
