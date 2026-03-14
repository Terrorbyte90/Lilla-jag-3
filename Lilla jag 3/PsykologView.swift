// PsykologView.swift
// Lilla Jag – Hitta professionell hjälp

import SwiftUI

struct PsykologView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var ai = LillaJagAIService.shared
    @State private var aiSuggestion: String = ""
    @State private var loadingSuggestion = false

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        heroCard
                        if !aiSuggestion.isEmpty || loadingSuggestion {
                            aiSuggestionCard
                        }
                        ForEach(resources, id: \.title) { res in
                            ResourceCard(resource: res)
                        }
                        crisisButton
                        noteCard
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Professionell hjälp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .task { await loadAISuggestion() }
        }
    }

    private func loadAISuggestion() async {
        guard !loadingSuggestion else { return }
        loadingSuggestion = true
        let emotionContext = ai.currentEmotion.map { "Jag mår dåligt och känner \($0.dominant.name)." } ?? "Jag mår inte bra."
        let prompt = "Ge ett kort, varmt och hoppfullt råd (2 meningar) på svenska om varför det är viktigt att söka professionell hjälp vid psykisk ohälsa. Börja med att validera känslan av att ta steget."
        aiSuggestion = await LillaJagAIService.shared.generateResponse(to: prompt)
        loadingSuggestion = false
    }

    private var heroCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.warmLavender.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.warmLavender)
            }
            Text("Professionell hjälp funkar")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(.white)
            Text("Appen är ett komplement – inte en ersättning. Vid allvarlig psykisk ohälsa är professionell vård avgörande.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                statPill(label: "KBT", icon: "brain.head.profile", color: .warmLavender)
                statPill(label: "Gratis via 1177", icon: "stethoscope", color: .warmSage)
                statPill(label: "Online", icon: "video.fill", color: .warmGold)
            }
        }
        .padding(20)
        .background(Color.warmLavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.warmLavender.opacity(0.25), lineWidth: 1))
    }

    private func statPill(label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var aiSuggestionCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.warmGold.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.warmGold)
            }
            if loadingSuggestion {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Personlig insikt...")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.warmGold)
                    ProgressView()
                        .tint(Color.warmGold)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lilla Jag säger")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.warmGold)
                    Text(aiSuggestion)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(3)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.warmGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.warmGold.opacity(0.2), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var crisisButton: some View {
        Group {
            if let url = URL(string: "tel:90101") {
                Link(destination: url) {
                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Självmordslinjen – 90101")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Dygnet runt · kostnadsfritt · anonymt")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(14)
                    .background(Color(hex: 0xFF5B5B).opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xFF5B5B).opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noteCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.warmGold)
            Text("Lilla Jag ersätter inte psykvård")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Använd appen som ett dagligt stöd, men kontakta alltid vården vid allvarliga symptom.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.warmGold.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct PsykResource {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let description: String
    let url: String?
    let phone: String?
}

private let resources: [PsykResource] = [
    PsykResource(icon: "globe", color: Color(hex: 0x6ECFF6), title: "1177.se – Psykisk hälsa",
                 subtitle: "Hitta vård nära dig",
                 description: "På 1177.se kan du hitta och boka tid hos psykolog, kurator eller psykiatrisk öppenvård i din region.",
                 url: "https://www.1177.se", phone: "1177"),
    PsykResource(icon: "video.fill", color: Color.warmLavender, title: "KBT via internet (iKBT)",
                 subtitle: "Kostnadsfri KBT-behandling",
                 description: "Internetpsykiatri.se erbjuder KBT för depression, ångest och panikattacker. Kostnadsfritt med remiss.",
                 url: "https://www.internetpsykiatri.se", phone: nil),
    PsykResource(icon: "building.2.fill", color: Color.warmSage, title: "Psykiatrin",
                 subtitle: "Via remiss eller självremiss",
                 description: "Kontakta din vårdcentral för remiss till psykiatrin, eller sök direkt på psykiatrisk akutmottagning vid kris.",
                 url: nil, phone: "1177"),
    PsykResource(icon: "person.3.fill", color: Color.warmGold, title: "Ahum",
                 subtitle: "Digital KBT-behandling på svenska",
                 description: "Ahum erbjuder KBT-behandling, självtester och digitala guider på svenska.",
                 url: "https://www.ahum.se", phone: nil),
    PsykResource(icon: "heart.fill", color: Color.warmRose, title: "Ellycare",
                 subtitle: "Online-psykolog",
                 description: "Privat psykologhjälp online med snabba tider. Via BankID och videosamtal.",
                 url: "https://www.ellycare.se", phone: nil)
]

struct ResourceCard: View {
    let resource: PsykResource

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(resource.color.opacity(0.2)).frame(width: 44, height: 44)
                    Image(systemName: resource.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(resource.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(resource.subtitle)
                        .font(.caption)
                        .foregroundStyle(resource.color)
                }
                Spacer()
            }
            Text(resource.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(2)

            HStack(spacing: 10) {
                if let urlStr = resource.url, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Label("Öppna webbsida", systemImage: "safari")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(resource.color.opacity(0.25), in: Capsule())
                    }
                }
                if let phone = resource.phone, let telURL = URL(string: "tel:\(phone)") {
                    Link(destination: telURL) {
                        Label(phone, systemImage: "phone.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(resource.color.opacity(0.2), lineWidth: 1))
    }
}

#Preview {
    PsykologView()
}
