import SwiftUI

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

        // Text
        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let textTertiary  = Color.white.opacity(0.45)

        // Glass
        static let glassStroke   = Color.white.opacity(0.12)
        static let glassFill     = Color.white.opacity(0.06)

        // Danger / Crisis
        static let danger = Color(hex: 0xFF5B5B)

        static var brandGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: 0xBB86FC), Color(hex: 0xFF6B8A)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }

        static var backgroundGradient: LinearGradient {
            LinearGradient(colors: [background, backgroundSecondary], startPoint: .top, endPoint: .bottom)
        }

        static var subtleGradient: LinearGradient {
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Typography
    enum Typography {
        static let titleLarge = Font.system(.largeTitle, design: .rounded, weight: .black)
        static let titleMain  = Font.system(.title2, design: .rounded, weight: .bold)
        static let titleSection = Font.system(.title3, design: .rounded, weight: .bold)
        static let headline   = Font.headline.weight(.semibold)
        static let body       = Font.body
        static let bodyRounded = Font.system(.body, design: .rounded)
        static let caption    = Font.caption.weight(.medium)
        static let captionSmall = Font.caption2.weight(.medium)
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
        static let iconCircleSmall: CGFloat = 36
        static let iconCircleMedium: CGFloat = 44
        static let iconCircleLarge: CGFloat = 52
    }

    // MARK: - Shadows
    enum Shadow {
        static func card(_ color: Color = .black) -> some View {
            Color.clear.shadow(color: color.opacity(0.2), radius: 8, y: 4)
        }
    }

    // MARK: - Animation
    enum Animation {
        static let smooth = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let quick = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.75)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.5)
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

    /// Subtle press effect for interactive cards
    func ljPressable() -> some View {
        self.buttonStyle(LJPressableButtonStyle())
    }
}

/// A button style that provides a subtle scale + opacity press effect
struct LJPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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

// MARK: - Premium Icon Circle

struct LJIconCircle: View {
    let icon: String
    let color: Color
    var size: CGFloat = DesignSystem.Size.iconCircleMedium
    var iconScale: CGFloat = 0.42

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: size * iconScale, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Shimmer Effect (premium loading)

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

extension View {
    func ljShimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
