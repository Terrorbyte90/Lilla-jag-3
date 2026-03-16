import SwiftUI

// MARK: - Onboarding data

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let accentColor: Color
    let title: String
    let subtitle: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        icon: "heart.fill",
        iconColor: .warmRose,
        accentColor: Color(hex: 0xFF6B8A),
        title: "Välkommen till\nLilla Jag",
        subtitle: "En trygg plats för dig som kämpar med psykisk ohälsa."
    ),
    OnboardingPage(
        icon: "brain.head.profile",
        iconColor: .warmLavender,
        accentColor: Color(hex: 0xC084FC),
        title: "KBT i fickan",
        subtitle: "Tankedagbok, humörlogg och beteendeaktivering – vetenskapligt förankrat."
    ),
    OnboardingPage(
        icon: "lock.shield.fill",
        iconColor: .warmSage,
        accentColor: Color(hex: 0x7EC8A4),
        title: "100 % privat",
        subtitle: "All AI körs lokalt på din enhet. Ingen data lämnar din telefon – aldrig."
    ),
    OnboardingPage(
        icon: "sparkles",
        iconColor: .warmGold,
        accentColor: Color(hex: 0xFFD166),
        title: "Din AI-terapeut",
        subtitle: "Prata med en empatisk KBT-coach när du behöver det – dygnet runt."
    )
]

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var isVisible = false

    var body: some View {
        ZStack {
            // Dynamic background tinted by current page's accent color
            WarmBackground(accentHint: pages[currentPage].accentColor)
                .animation(.easeInOut(duration: 0.6), value: currentPage)

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage
                                  ? pages[i].accentColor
                                  : Color.white.opacity(0.18))
                            .frame(width: i == currentPage ? 28 : 8, height: 4)
                            .animation(.spring(response: 0.38, dampingFraction: 0.75), value: currentPage)
                    }
                }
                .padding(.top, 64)
                .opacity(isVisible ? 1 : 0)

                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        PageContent(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                .opacity(isVisible ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentPage)

                Spacer(minLength: 16)

                // CTA
                VStack(spacing: 14) {
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                hasCompletedOnboarding = true
                            }
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentPage < pages.count - 1 ? "Nästa" : "Kom igång")
                                .font(DesignSystem.Typography.headline)
                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous))
                        .shadow(color: pages[currentPage].accentColor.opacity(0.45), radius: 16, x: 0, y: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                    .buttonStyle(.plain)

                    if currentPage > 0 {
                        Button("Hoppa över") {
                            withAnimation { hasCompletedOnboarding = true }
                        }
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(.white.opacity(0.45))
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, 52)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.1)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Page Content

private struct PageContent: View {
    let page: OnboardingPage
    @State private var iconPulse = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            // Icon with layered glow rings
            ZStack {
                // Outer glow ring (animated)
                Circle()
                    .fill(page.accentColor.opacity(0.06))
                    .frame(width: 180, height: 180)
                    .scaleEffect(iconPulse ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: iconPulse)

                // Mid ring
                Circle()
                    .fill(page.accentColor.opacity(0.12))
                    .frame(width: 144, height: 144)
                    .scaleEffect(iconPulse ? 0.96 : 1.0)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)
                        .delay(0.3), value: iconPulse)

                // Icon background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.accentColor.opacity(0.30), page.accentColor.opacity(0.10)],
                            center: .center, startRadius: 10, endRadius: 54
                        )
                    )
                    .frame(width: 108, height: 108)
                    .overlay(Circle().stroke(page.accentColor.opacity(0.25), lineWidth: 1))

                Image(systemName: page.icon)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(page.accentColor)
                    .shadow(color: page.accentColor.opacity(0.6), radius: 24, x: 0, y: 4)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .animation(.spring(response: 0.55, dampingFraction: 0.6), value: appeared)
            }
            .padding(.bottom, 8)

            // Text
            VStack(spacing: 16) {
                Text(page.title)
                    .font(DesignSystem.Typography.titleLarge)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.08), value: appeared)

                Text(page.subtitle)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)
            }
        }
        .padding(.horizontal, 36)
        .onAppear {
            iconPulse = true
            withAnimation { appeared = true }
        }
        .onDisappear { appeared = false }
    }
}

// MARK: - Warm background

struct WarmBackground: View {
    var accentHint: Color = Color(hex: 0x8B2FC9)

    var body: some View {
        ZStack {
            Color(hex: 0x110D1C).ignoresSafeArea()

            // Top-right warm orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentHint.opacity(0.35), Color(hex: 0xFF6B6B).opacity(0.15), .clear],
                        center: .center, startRadius: 0, endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .blur(radius: 60)
                .offset(x: 120, y: -180)

            // Bottom-left cool orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x4A90D9).opacity(0.20), Color(hex: 0x9B59B6).opacity(0.22), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 70)
                .offset(x: -140, y: 240)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
