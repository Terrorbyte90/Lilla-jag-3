// SocialView.swift
// Lilla Jag – Sociala resurser & community

import SwiftUI

struct SocialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showForum = false
    @State private var showMeditation = false

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        // Community-åtgärder
                        VStack(spacing: 12) {
                            socialAction(
                                icon: "person.3.fill",
                                color: Color.warmLavender,
                                title: "Community-forumet",
                                description: "Dela erfarenheter och hitta stöd från andra i samma situation.",
                                action: { showForum = true }
                            )
                            socialAction(
                                icon: "lungs.fill",
                                color: Color.warmSage,
                                title: "Andningsövningar",
                                description: "Lugna nervsystemet med guidade andnings- och mindfulnessövningar.",
                                action: { showMeditation = true }
                            )
                        }

                        Text("Externa resurser")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(externalLinks, id: \.title) { link in
                            externalLinkCard(link)
                        }

                        Text("Att prata med andra – oavsett om det är vänner, familj eller en community – har starka evidensbaserade effekter på psykisk hälsa.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Socialt stöd")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .fullScreenCover(isPresented: $showForum) { ForumView() }
        .fullScreenCover(isPresented: $showMeditation) {
            NavigationStack { MeditationView() }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            LJIconCircle(icon: "person.2.fill", color: Color.warmRose, size: 64)
            Text("Du behöver inte vara ensam")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(.white)
            Text("Mänsklig kontakt och gemenskap är grundläggande för återhämtning.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .background(Color.warmRose.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.warmRose.opacity(0.2), lineWidth: 1))
    }

    private func socialAction(icon: String, color: Color, title: String, description: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 20, weight: .medium)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func externalLinkCard(_ link: (title: String, subtitle: String, url: String, icon: String, color: Color)) -> some View {
        if let url = URL(string: link.url) {
            return AnyView(
                Link(destination: url) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(link.color.opacity(0.2)).frame(width: 44, height: 44)
                            Image(systemName: link.icon).font(.system(size: 18)).foregroundStyle(link.color)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(link.title)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            Text(link.subtitle)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: "safari")
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            )
        }
        return AnyView(EmptyView())
    }
}

private let externalLinks: [(title: String, subtitle: String, url: String, icon: String, color: Color)] = [
    ("Mind.se", "Stöd, information och hjälplinjen", "https://mind.se", "heart.fill", Color.warmRose),
    ("r/psykiskohalsa (Reddit)", "Svensk subreddit om psykisk hälsa", "https://reddit.com/r/psykiskohalsa", "text.bubble.fill", Color(hex: 0xFF4500)),
    ("1177 – Psykisk hälsa", "Officiell information och hitta vård", "https://www.1177.se", "stethoscope", Color(hex: 0x6ECFF6)),
    ("Internetpsykiatri.se", "Gratis KBT online med legitimerade terapeuter", "https://www.internetpsykiatri.se", "video.fill", Color.warmLavender)
]

#Preview {
    SocialView()
}
