import SwiftUI

// MARK: - Onboarding data

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        icon: "heart.fill",
        iconColor: .warmRose,
        title: "Välkommen till\nLilla Jag",
        subtitle: "En trygg plats för dig som kämpar\nmed psykisk ohälsa. Du är inte ensam."
    ),
    OnboardingPage(
        icon: "brain.head.profile",
        iconColor: .warmLavender,
        title: "KBT i fickan",
        subtitle: "Tankedagbok, humörlogg och\nbeteendeaktivering – vetenskapligt förankrat."
    ),
    OnboardingPage(
        icon: "lock.shield.fill",
        iconColor: .warmSage,
        title: "100 % privat",
        subtitle: "All AI körs lokalt på din enhet.\nIngen data lämnar din telefon – aldrig."
    ),
    OnboardingPage(
        icon: "sparkles",
        iconColor: .warmGold,
        title: "Din AI-terapeut",
        subtitle: "Prata med en empatisk KBT-coach\nnär du behöver det – dygnet runt.\nAllt körs lokalt, helt privat."
    )
]

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var animateContent = false
    @State private var aiWelcome: String = ""

    var body: some View {
        ZStack {
            WarmBackground()

            VStack(spacing: 0) {
                // Top bar: dots + skip
                HStack {
                    // Page indicator dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? Color.white : Color.white.opacity(0.25))
                                .frame(width: i == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.35), value: currentPage)
                        }
                    }
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Hoppa över") {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.4)) { hasCompletedOnboarding = true }
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .accessibilityLabel("Hoppa över introduktionen")
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 60)

                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageContent(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentPage)

                Spacer()

                // AI-välkomstmeddelande på sista sidan
                if currentPage == pages.count - 1, !aiWelcome.isEmpty {
                    Text(aiWelcome)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                }

                // CTA button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.4)) {
                        if currentPage < pages.count - 1 {
                            currentPage += 1
                        } else {
                            hasCompletedOnboarding = true
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage < pages.count - 1 ? "Nästa" : "Kom igång")
                            .font(.system(.body, design: .rounded, weight: .bold))
                        Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .white.opacity(0.2), radius: 12, y: 4)
                }
                .buttonStyle(LJPressableButtonStyle())
                .accessibilityLabel(currentPage < pages.count - 1 ? "Nästa sida" : "Kom igång med appen")
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            aiWelcome = LillaJagAIService.shared.welcomeMessage()
        }
    }

    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: 28) {
            ZStack {
                // Pulsating outer ring
                Circle()
                    .fill(page.iconColor.opacity(0.06))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(page.iconColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                Image(systemName: page.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(page.iconColor)
                    .shadow(color: page.iconColor.opacity(0.6), radius: 24)
            }
            .padding(.bottom, 8)

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(page.subtitle)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 28)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Warm background

struct WarmBackground: View {
    var body: some View {
        ZStack {
            Color(hex: 0x1A1025).ignoresSafeArea()
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x8B2FC9).opacity(0.4), Color(hex: 0xFF6B6B).opacity(0.25)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 500, height: 500)
                .blur(radius: 120)
                .offset(x: 100, y: -180)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x4A90D9).opacity(0.25), Color(hex: 0x9B59B6).opacity(0.3)],
                                     startPoint: .bottomLeading, endPoint: .topTrailing))
                .frame(width: 400, height: 400)
                .blur(radius: 130)
                .offset(x: -120, y: 220)
        }
    }
}

// Färger och Color(hex:) definieras i LillaJagColors.swift

// MARK: - Preview

#Preview {
    OnboardingView()
}
