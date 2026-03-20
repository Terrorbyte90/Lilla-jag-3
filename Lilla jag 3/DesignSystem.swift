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
        static let titleLarge   = Font.system(.largeTitle, design: .rounded, weight: .black)
        static let titleMain    = Font.system(.title2, design: .rounded, weight: .bold)
        static let titleSection = Font.system(.title3, design: .rounded, weight: .bold)
        static let headline     = Font.headline.weight(.semibold)
        static let body         = Font.body
        static let bodyRounded  = Font.system(.body, design: .rounded)
        static let caption      = Font.caption.weight(.medium)
        static let captionSmall = Font.caption2.weight(.medium)
        // Hero display – används för siffror och hero-element
        static let heroNumber   = Font.system(.largeTitle, design: .rounded, weight: .black)
    }

    // MARK: - Corner Radii
    enum Radius {
        static let small: CGFloat      = 12
        static let medium: CGFloat     = 18
        static let large: CGFloat      = 24
        static let extraLarge: CGFloat = 28
    }

    // MARK: - Adaptive Spacing (strikt 8pt-grid)
    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48

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
        static let minTapTarget: CGFloat    = 44
        static let iconCircleSmall: CGFloat  = 36
        static let iconCircleMedium: CGFloat = 44
        static let iconCircleLarge: CGFloat  = 52
    }

    // MARK: - Animation – kalibrerade spring-värden
    enum Animation {
        // Standard interaktiv respons – likt UIKit spring
        static let smooth = SwiftUI.Animation.spring(response: 0.38, dampingFraction: 0.82)
        // Snabb, tight – för toggle/selection
        static let quick  = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.72)
        // Mjuk intro – för cards som flyger in
        static let intro  = SwiftUI.Animation.spring(response: 0.55, dampingFraction: 0.78)
        // Linjär fade
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.45)
        // Overlay/dismiss
        static let overlay = SwiftUI.Animation.easeOut(duration: 0.3)
    }
}

// MARK: - Reduce Motion helper

extension EnvironmentValues {
    // Kortnamn för bekväm åtkomst i views
    var reduceMotion: Bool { accessibilityReduceMotion }
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

// Premium glasskort med subtil inre ljusreflex längs toppen
struct PremiumGlassModifier: ViewModifier {
    var radius: CGFloat
    var accentColor: Color

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    DesignSystem.Colors.glassFill
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.45)
                    )
                }
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                accentColor.opacity(0.12),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func ljGlassCard(radius: CGFloat = DesignSystem.Radius.medium) -> some View {
        modifier(GlassModifier(radius: radius))
    }

    func ljPremiumCard(radius: CGFloat = DesignSystem.Radius.medium, accent: Color = .white) -> some View {
        modifier(PremiumGlassModifier(radius: radius, accentColor: accent))
    }

    /// Subtle press effect for interactive cards
    func ljPressable() -> some View {
        self.buttonStyle(LJPressableButtonStyle())
    }

    /// Reduce-motion-aware animation helper
    func ljAnimate<V: Equatable>(
        _ animation: SwiftUI.Animation = DesignSystem.Animation.smooth,
        value: V
    ) -> some View {
        self.modifier(ReduceMotionAnimationModifier(animation: animation, value: value))
    }
}

private struct ReduceMotionAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: SwiftUI.Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .none : animation, value: value)
    }
}

/// A button style that provides a subtle scale + opacity press effect
struct LJPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Haptic helpers

enum LJHaptic {
    static func light()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func soft()      { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success()   { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()   { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
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
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.25), color.opacity(0.08)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
            Image(systemName: icon)
                .font(.system(size: size * iconScale, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Section Header – konsekvent i hela appen

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let trailing, let action = trailingAction {
                Button(action: action) {
                    Text(trailing)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.warmLavender.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 2)
    }
}

// MARK: - Shimmer Effect (premium loading)

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -300

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.3),
                            .init(color: .white.opacity(0.1), location: 0.5),
                            .init(color: .clear, location: 0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase)
                    .onAppear {
                        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                            phase = geo.size.width + 300
                        }
                    }
                }
                .mask(content)
            )
    }
}

extension View {
    func ljShimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton placeholder

struct LJSkeletonRow: View {
    var width: CGFloat = .infinity
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: width == .infinity ? .infinity : width, minHeight: height, maxHeight: height)
            .ljShimmer()
    }
}

// MARK: - Pulsating dot (online-indikator o.d.)

struct PulsingDot: View {
    var color: Color = .green
    var size: CGFloat = 8
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(pulsing ? 1.4 : 1.0)
                .opacity(pulsing ? 0 : 0.6)
                .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulsing)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear { pulsing = true }
    }
}
