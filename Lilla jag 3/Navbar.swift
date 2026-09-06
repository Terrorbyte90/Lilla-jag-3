//
//  Navbar.swift
//  Lilla Jag
//
//  ➜  Så använder du den:
//
//  1.  Lägg den här filen i projektet.
//  2.  I varje huvudsida lägger du **en rad**:
//
//          .withNavbar(dest: .chat)   // välj .home/.diary/.diagnoses/.chat/.mood
//
//      Exempel:
//
//          struct AssistantView: View {
//              var body: some View {
//                  Color.yellow.opacity(0.2)
//                      .overlay(Text("Prata").font(.largeTitle))
//                      .withNavbar(dest: .chat)      // ← en rad räcker
//              }
//          }
//
//  3.  Ha en enda “RootContainer” som staplar alla fem sidor i en ZStack
//      – modifieraren gör att bara den aktiva visas, resten är tomma.
//      Se preview längst ned.
//
//  Resultat:  Varje sida kan leva helt fristående, men växlar snyggt via NavRouter.
//

import SwiftUI

// MARK: - 1  Destinations­enum
enum NavDestination: String, CaseIterable, Identifiable {
    case home, diary, diagnoses, chat, mood
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .home:       return "Hem"
        case .diary:      return "Dagbok"
        case .diagnoses:  return "Diagnoser"
        case .chat:       return "Prata"
        case .mood:       return "Humör"
        }
    }
    var icon: String {
        switch self {
        case .home:       return "house.fill"
        case .diary:      return "book.closed.fill"
        case .diagnoses:  return "cross.case.fill"
        case .chat:       return "bubble.left.and.bubble.right.fill"
        case .mood:       return "face.smiling.fill"
        }
    }
}

// MARK: - 2  Global router (delad instans)
@Observable
final class NavRouter {
    static let shared = NavRouter()
    var current: NavDestination = .home
}

// MARK: - 3.5  Morphing Ring View
struct MorphingRingView: View {
    let isActive: Bool
    let trigger: Bool
    let gradient: LinearGradient

    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Outer morphing ring
            Circle()
                .stroke(gradient, lineWidth: 2.5)
                .frame(width: 56, height: 56)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            // Inner ripple
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xBB86FC).opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 32
                    )
                )
                .frame(width: 50, height: 50)
                .scaleEffect(ringScale * 0.9)
                .opacity(ringOpacity * 0.6)
        }
        .onChange(of: trigger) { _, newValue in
            guard newValue else {
                withAnimation(.easeOut(duration: 0.25)) {
                    ringScale = 0.5
                    ringOpacity = 0
                }
                return
            }
            // Morph sequence: expand → ripple → fade
            withAnimation(.easeOut(duration: 0.12)) {
                ringScale = 1.4
                ringOpacity = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    ringScale = 1.7
                    ringOpacity = 0.0
                }
            }
        }
    }
}

// MARK: - 3.6  Floating Action Button with Pulse Ring
struct FloatingActionButton: View {
    let action: () -> Void
    @State private var isPressed: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    @State private var isPulsing: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let fabGradient = LinearGradient(
        colors: [Color(hex: 0xBB86FC), Color(hex: 0xFF6B8A)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            // Outer pulse ring - expanding and fading
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: 0xBB86FC).opacity(0.5), Color(hex: 0xFF6B8A).opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 72, height: 72)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)

            // Second pulse ring (offset for wave effect)
            Circle()
                .stroke(Color(hex: 0xFF6B8A).opacity(0.3), lineWidth: 1.5)
                .frame(width: 80, height: 80)
                .scaleEffect(pulseScale * 0.9)
                .opacity(pulseOpacity * 0.5)

            // Main FAB button
            Button(action: {
                LJHaptic.impact(.medium)
                action()
            }) {
                ZStack {
                    // Glass background
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 56, height: 56)

                    // Gradient border
                    Circle()
                        .stroke(fabGradient, lineWidth: 2.5)
                        .frame(width: 56, height: 56)

                    // Inner glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: 0xBB86FC).opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 28
                            )
                        )
                        .frame(width: 52, height: 52)

                    // Icon
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(fabGradient)
                        .rotationEffect(.degrees(isPressed ? 45 : 0))
                }
                .shadow(color: Color(hex: 0xBB86FC).opacity(0.5), radius: isPressed ? 8 : 12, y: 4)
            }
            .buttonStyle(FABButtonStyle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .onAppear {
            guard !reduceMotion else { return }
            startPulseAnimation()
        }
    }

    private func startPulseAnimation() {
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
            pulseScale = 1.5
            pulseOpacity = 0.0
        }
    }
}

// MARK: - FAB Button Style
struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 3  Premium Navbar
struct Navbar: View {
    @State private var router = NavRouter.shared
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 10
    @Namespace private var tabAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeTabPulse: Bool = false
    @State private var previousTab: NavDestination = .home
    @State private var fabExpanded: Bool = false

    private let gradient = LinearGradient(
        colors: [Color(hex: 0xBB86FC), Color(hex: 0xFF6B8A)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    @ViewBuilder
    private func navButton(for dest: NavDestination) -> some View {
        let isActive = router.current == dest
        Button {
            if router.current != dest {
                previousTab = router.current
                activeTabPulse = true
                LJHaptic.selection()
                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72)) {
                    router.current = dest
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    activeTabPulse = false
                }
            }
        } label: {
            ZStack {
                // Morphing ring animation vid tab-byte
                MorphingRingView(
                    isActive: isActive,
                    trigger: activeTabPulse,
                    gradient: gradient
                )

                VStack(spacing: 3) {
                    Image(systemName: dest.icon)
                        .font(.system(size: min(iconSize, 22), weight: isActive ? .semibold : .regular))
                        .scaleEffect(isActive ? 1.08 : 1.0)
                        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: isActive)
                    Text(dest.title)
                        .font(.system(size: min(labelSize, 10), weight: isActive ? .semibold : .regular, design: .rounded))
                        .opacity(isActive ? 1.0 : 0.65)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.5))
            .background(
                Group {
                    if isActive {
                        // Premium gradient background med glow
                        ZStack {
                            gradient
                                .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            // Inner glow highlight
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.15), Color.clear],
                                        startPoint: .top,
                                        endPoint: UnitPoint(x: 0.5, y: 0.6)
                                    )
                                )
                                .matchedGeometryEffect(id: "activeTabGlow", in: tabAnimation)
                        }
                        .shadow(color: Color(hex: 0xBB86FC).opacity(0.4), radius: 10, y: 3)
                    } else {
                        Color.clear
                    }
                }
            )
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: router.current)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dest.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left side - Home & Diary
            ForEach([NavDestination.home, .diary]) { dest in
                navButton(for: dest)
            }

            // Center - Floating Action Button
            ZStack {
                FloatingActionButton {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        fabExpanded.toggle()
                    }
                }
            }
            .frame(width: 72)

            // Right side - Diagnoses, Chat, Mood
            ForEach([NavDestination.diagnoses, .chat, .mood]) { dest in
                navButton(for: dest)
            }
        }
        .padding(6)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // Gradient sliding indicator line under navbar
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                let totalWidth = geo.size.width - 28 // Account for horizontal padding
                let indicatorWidth = totalWidth / CGFloat(NavDestination.allCases.count)
                let progress = CGFloat(NavDestination.allCases.firstIndex(of: router.current) ?? 0) + 0.5
                let centerX = (progress / CGFloat(NavDestination.allCases.count)) * totalWidth + 14

                // Animated gradient line
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0xBB86FC).opacity(0.0),
                                Color(hex: 0xBB86FC),
                                Color(hex: 0xFF6B8A),
                                Color(hex: 0xFF6B8A).opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: indicatorWidth * 0.6, height: 3)
                    .position(x: centerX, y: -2)
                    .shadow(color: Color(hex: 0xBB86FC).opacity(0.6), radius: 6, y: 0)
                    .animation(.spring(response: 0.38, dampingFraction: 0.75), value: router.current)
            }
            .frame(height: 4)
        }
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .padding(.horizontal, 14)
    }
}

// MARK: - 4  Modifierare som växlar vyer
private struct NavbarModifier: ViewModifier {
    let dest: NavDestination
    @State private var router = NavRouter.shared

    func body(content: Content) -> some View {
        Group {
            if router.current == dest {
                content
                    .safeAreaInset(edge: .bottom) {
                        Navbar()
                            .padding(.bottom, 6)
                    }
                    .transition(.opacity)
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - 5  Publik helper
extension View {
    /// Använd på din sida så här:
    /// `.withNavbar(dest: .chat)`
    func withNavbar(dest: NavDestination) -> some View {
        modifier(NavbarModifier(dest: dest))
    }
}


// MARK: - 7  Root‑container som staplar alla vyer
struct RootContainer: View {
    var body: some View {
        ZStack {
            Dashboard().withNavbar(dest: .home)
            DagbokDashboardView().withNavbar(dest: .diary)
            DiagnoserView().withNavbar(dest: .diagnoses)
            AssistantView().withNavbar(dest: .chat)
            Mood1View().withNavbar(dest: .mood)
        }
        .animation(.easeInOut(duration: 0.25), value: NavRouter.shared.current)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - 8  Preview
#Preview {
    RootContainer()
        .preferredColorScheme(.dark)
}
