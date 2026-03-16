import SwiftUI

// MARK: - Design System

struct DesignSystem {

    // MARK: - Colors
    enum Colors {
        // Bakgrunder
        static let background          = Color(hex: 0x110D1C)   // djupare, varmare
        static let backgroundSecondary = Color(hex: 0x1C1630)
        static let backgroundElevated  = Color(hex: 0x251D3A)   // lyft yta (kort etc.)

        // Brand accenter
        static let accent          = Color(hex: 0xC084FC)   // varm lavendel
        static let accentSecondary = Color(hex: 0xF472B6)   // varm ros
        static let accentGold      = Color(hex: 0xFFD166)   // guld
        static let accentSage      = Color(hex: 0x7EC8A4)   // sage

        // Text
        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.70)
        static let textTertiary  = Color.white.opacity(0.42)

        // Glassmorphism
        static let glassStroke   = Color.white.opacity(0.12)
        static let glassFill     = Color.white.opacity(0.05)
        static let glassMedium   = Color.white.opacity(0.09)

        // Semantic
        static let success = Color(hex: 0x4ADE80)
        static let warning = Color(hex: 0xFBBF24)
        static let error   = Color(hex: 0xF87171)
        static let info    = Color(hex: 0x60A5FA)

        // Gradients
        static var brandGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: 0xC084FC), Color(hex: 0xF472B6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        static var brandGradientReversed: LinearGradient {
            LinearGradient(
                colors: [Color(hex: 0xF472B6), Color(hex: 0xC084FC)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        static var backgroundGradient: LinearGradient {
            LinearGradient(colors: [background, backgroundSecondary], startPoint: .top, endPoint: .bottom)
        }
        static var goldGradient: LinearGradient {
            LinearGradient(colors: [Color(hex: 0xFFD166), Color(hex: 0xFFA94D)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        static var sageGradient: LinearGradient {
            LinearGradient(colors: [Color(hex: 0x7EC8A4), Color(hex: 0x34D399)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: - Typography
    enum Typography {
        static let displayLarge = Font.system(size: 40, weight: .black, design: .rounded)
        static let titleLarge   = Font.system(.largeTitle, design: .rounded, weight: .black)
        static let titleMain    = Font.system(.title2,    design: .rounded, weight: .bold)
        static let titleSmall   = Font.system(.title3,    design: .rounded, weight: .bold)
        static let headline     = Font.system(.headline,  design: .rounded, weight: .semibold)
        static let body         = Font.system(.body,      design: .rounded)
        static let bodyMedium   = Font.system(.body,      design: .rounded, weight: .medium)
        static let subheadline  = Font.system(.subheadline, design: .rounded, weight: .medium)
        static let caption      = Font.system(.caption,   design: .rounded, weight: .medium)
        static let caption2     = Font.system(.caption2,  design: .rounded, weight: .semibold)
        static let overline     = Font.system(size: 11,   weight: .semibold, design: .rounded)
    }

    // MARK: - Spacing  (4pt grid)
    enum Spacing {
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 16
        static let lg:   CGFloat = 24
        static let xl:   CGFloat = 32
        static let xxl:  CGFloat = 48

        static func horizontalPadding(for width: CGFloat) -> CGFloat {
            max(16, width * 0.055)
        }

        static func cardSpacing(for height: CGFloat) -> CGFloat {
            height > 800 ? 24 : 16
        }
    }

    // MARK: - Corner Radii
    enum Radius {
        static let xs:         CGFloat = 8
        static let small:      CGFloat = 12
        static let medium:     CGFloat = 18
        static let large:      CGFloat = 24
        static let extraLarge: CGFloat = 32
        static let pill:       CGFloat = 999
    }

    // MARK: - Shadows
    enum Shadow {
        static func small(color: Color = .black)  -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color.opacity(0.25), 4, 0, 2)
        }
        static func medium(color: Color = .black) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color.opacity(0.35), 12, 0, 4)
        }
        static func large(color: Color = .black)  -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color.opacity(0.45), 24, 0, 8)
        }
        static func colored(_ color: Color) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color.opacity(0.4), 16, 0, 4)
        }
    }

    // MARK: - Adaptive Sizes
    enum Size {
        static func heroHeight(for screenHeight: CGFloat) -> CGFloat {
            min(max(screenHeight * 0.28, 180), 280)
        }
        static let minTapTarget: CGFloat = 44
        static let iconSmall:  CGFloat = 16
        static let iconMedium: CGFloat = 20
        static let iconLarge:  CGFloat = 28
    }
}

// MARK: - View Modifiers

struct GlassModifier: ViewModifier {
    var radius: CGFloat
    var fill: Color
    func body(content: Content) -> some View {
        content
            .background(fill)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(DesignSystem.Colors.glassStroke, lineWidth: 1)
            )
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.08), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: (phase - 1) * geo.size.width * 2)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func ljGlassCard(radius: CGFloat = DesignSystem.Radius.medium,
                     fill: Color = DesignSystem.Colors.glassFill) -> some View {
        modifier(GlassModifier(radius: radius, fill: fill))
    }

    func ljShimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func ljShadowSmall(color: Color = .black) -> some View {
        let s = DesignSystem.Shadow.small(color: color)
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    func ljShadowMedium(color: Color = .black) -> some View {
        let s = DesignSystem.Shadow.medium(color: color)
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    func ljShadowColored(_ color: Color) -> some View {
        let s = DesignSystem.Shadow.colored(color)
        return self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// MARK: - Typography Extensions

extension Text {
    func ljTitle() -> some View {
        self.font(DesignSystem.Typography.titleMain)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }

    func ljHeadline() -> some View {
        self.font(DesignSystem.Typography.headline)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }

    func ljCaption() -> some View {
        self.font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
    }

    func ljOverline() -> some View {
        self.font(DesignSystem.Typography.overline)
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .tracking(1.0)
            .textCase(.uppercase)
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

struct LJSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.overline)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)
                .textCase(.uppercase)
            Spacer()
            if let t = trailing {
                Text(t)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
        }
    }
}

struct LJEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionLabel: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.10))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.accent.opacity(0.7))
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            if let label = actionLabel, let action = onAction {
                Button(action: action) {
                    Text(label)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(DesignSystem.Colors.accent.opacity(0.12),
                                    in: Capsule())
                        .overlay(Capsule().stroke(DesignSystem.Colors.accent.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Button Styles

struct GradientButtonStyle: ButtonStyle {
    var gradient: LinearGradient = DesignSystem.Colors.brandGradient
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous))
            .shadow(
                color: Color(hex: 0xC084FC).opacity(configuration.isPressed ? 0.15 : 0.35),
                radius: configuration.isPressed ? 4 : 14, x: 0, y: configuration.isPressed ? 1 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(DesignSystem.Colors.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(DesignSystem.Colors.accent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                    .stroke(DesignSystem.Colors.accent.opacity(0.30), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Card

struct LJCard<Content: View>: View {
    let content: Content
    let radius: CGFloat

    init(radius: CGFloat = DesignSystem.Radius.medium, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignSystem.Spacing.md)
            .ljGlassCard(radius: radius, fill: DesignSystem.Colors.glassMedium)
            .ljShadowSmall()
    }
}

// MARK: - Skeleton placeholder

struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.07))
                .frame(width: 40, height: 40)
                .ljShimmer()
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 12)
                    .ljShimmer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 10)
                    .ljShimmer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .ljGlassCard()
    }
}
