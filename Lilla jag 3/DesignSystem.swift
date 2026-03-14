import SwiftUI

// MARK: - Color hex initializer (global – används av hela appen)
// OBS: En identisk initializer finns i Onboarding.swift. Swift tillåter identiska
// extension-metoder i samma modul om de har exakt samma signatur (kompileras utan fel).
// Alternativt: flytta hit och ta bort från Onboarding.swift.

struct DesignSystem {
    // MARK: - Colors (varma, lugnande toner – ej kliniskt kalla)
    enum Colors {
        // Bakgrunder – djup varm lila
        static let background          = Color(hex: 0x1A1025)
        static let backgroundSecondary = Color(hex: 0x221535)

        // Accenter
        static let accent          = Color(hex: 0xBB86FC)   // varm lavendel
        static let accentSecondary = Color(hex: 0xFF6B8A)   // varm ros
        static let accentGold      = Color(hex: 0xFFD166)   // guld

        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let glassStroke   = Color.white.opacity(0.15)
        static let glassFill     = Color.white.opacity(0.06)

        static var brandGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: 0xBB86FC), Color(hex: 0xFF6B8A)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }

        static var backgroundGradient: LinearGradient {
            LinearGradient(colors: [background, backgroundSecondary], startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Typography
    enum Typography {
        static let titleLarge = Font.system(.largeTitle, design: .rounded, weight: .black)
        static let titleMain  = Font.system(.title2, design: .rounded, weight: .bold)
        static let headline   = Font.headline.weight(.semibold)
        static let body       = Font.body
        static let caption    = Font.caption.weight(.medium)
    }

    // MARK: - Corner Radii
    enum Radius {
        static let small: CGFloat      = 12
        static let medium: CGFloat     = 18
        static let large: CGFloat      = 24
        static let extraLarge: CGFloat = 28
    }

    // MARK: - Adaptive Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32

        static func horizontalPadding(for width: CGFloat) -> CGFloat {
            max(16, width * 0.055)
        }

        static func cardSpacing(for height: CGFloat) -> CGFloat {
            height > 800 ? 24 : 16
        }
    }

    // MARK: - Adaptive Sizes
    enum Size {
        static func heroHeight(for screenHeight: CGFloat) -> CGFloat {
            min(max(screenHeight * 0.28, 180), 280)
        }
        static let minTapTarget: CGFloat = 44
    }
}

// MARK: - View Modifiers

struct GlassModifier: ViewModifier {
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.glassFill)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(DesignSystem.Colors.glassStroke, lineWidth: 1)
            )
    }
}

extension View {
    func ljGlassCard(radius: CGFloat = DesignSystem.Radius.medium) -> some View {
        modifier(GlassModifier(radius: radius))
    }
}

// MARK: - Global UI Components

struct LJTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.titleMain)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }
}

struct LJCard<Content: View>: View {
    let content: Content
    let radius: CGFloat

    init(radius: CGFloat = DesignSystem.Radius.medium, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .ljGlassCard(radius: radius)
    }
}
