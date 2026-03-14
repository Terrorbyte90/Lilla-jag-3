// UkraineView.swift
// Lilla Jag – Stöd Ukraina

import SwiftUI

struct UkraineView: View {
    @Environment(\.dismiss) private var dismiss

    private let orgs: [(name: String, url: String, desc: String)] = [
        ("Röda Korset", "https://www.redcross.se/stod-ukraine/", "Humanitärt arbete i Ukraina med sjukvård och evakuering."),
        ("UNHCR", "https://www.unhcr.org/ukraine-emergency", "FN:s flyktingorgan – stöder flyktingar i och runt Ukraina."),
        ("Läkare utan gränser", "https://www.lakarutangranser.se", "Medicinsk nödhjälp i krigsdrabbade områden."),
        ("Ukraine Aid", "https://u24.gov.ua", "Ukrainas officiella insamling för humanitärt stöd.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Ukrainian flag gradient
                        VStack(spacing: 14) {
                            ZStack {
                                LinearGradient(
                                    colors: [Color(hex: 0x005BBB), Color(hex: 0xFFD500)],
                                    startPoint: .top, endPoint: .bottom
                                )
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                                Text("🇺🇦")
                                    .font(.system(size: 48))
                            }

                            Text("Stöd Ukraina")
                                .font(.system(.title2, design: .rounded, weight: .black))
                                .foregroundStyle(.white)

                            Text("Kriget i Ukraina har fördrivit miljoner människor och orsakat enormt lidande. Varje krona hjälper.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))

                        ForEach(orgs, id: \.name) { org in
                            if let url = URL(string: org.url) {
                                Link(destination: url) {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(org.name)
                                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                .foregroundStyle(.white)
                                            Text(org.desc)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.65))
                                                .multilineTextAlignment(.leading)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right.circle.fill")
                                            .font(.system(size: 26))
                                            .foregroundStyle(Color(hex: 0xFFD500))
                                    }
                                    .padding(14)
                                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xFFD500).opacity(0.25), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("Psykisk ohälsa ökar i krig. Tack för att du bryr dig.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Stöd Ukraina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

#Preview {
    UkraineView()
}
