//
//  Navbar.swift
//  Lilla Jag
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
    var activeColor: Color {
        switch self {
        case .home:       return .warmLavender
        case .diary:      return .warmGold
        case .diagnoses:  return Color(hex: 0x6ECFF6)
        case .chat:       return .warmLavender
        case .mood:       return .warmRose
        }
    }
}

// MARK: - 2  Global router

final class NavRouter: ObservableObject {
    static let shared = NavRouter()
    @Published var current: NavDestination = .home
}

// MARK: - 3  Premium Navbar

struct Navbar: View {
    @ObservedObject private var router = NavRouter.shared
    @Namespace private var pillNS

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NavDestination.allCases) { dest in
                NavItem(dest: dest, isActive: router.current == dest, namespace: pillNS) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        router.current = dest
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.large, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 20)
    }
}

// MARK: - Nav Item

private struct NavItem: View {
    let dest: NavDestination
    let isActive: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 10

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: dest.icon)
                    .font(.system(size: min(iconSize, 20), weight: isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? dest.activeColor : Color.white.opacity(0.45))
                    .scaleEffect(isActive ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)

                Text(dest.title)
                    .font(.system(size: min(labelSize, 10), weight: isActive ? .bold : .medium,
                                  design: .rounded))
                    .foregroundStyle(isActive ? dest.activeColor : Color.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous)
                            .fill(dest.activeColor.opacity(0.14))
                            .matchedGeometryEffect(id: "navPill", in: namespace)
                            .shadow(color: dest.activeColor.opacity(0.25), radius: 8, x: 0, y: 2)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 4  Modifier

private struct NavbarModifier: ViewModifier {
    let dest: NavDestination
    @ObservedObject private var router = NavRouter.shared

    func body(content: Content) -> some View {
        Group {
            if router.current == dest {
                content
                    .safeAreaInset(edge: .bottom) {
                        Navbar()
                            .padding(.bottom, 6)
                    }
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - 5  Public helper

extension View {
    func withNavbar(dest: NavDestination) -> some View {
        modifier(NavbarModifier(dest: dest))
    }
}

// MARK: - 6  Root container

struct RootContainer: View {
    var body: some View {
        ZStack {
            Dashboard().withNavbar(dest: .home)
            DagbokDashboardView().withNavbar(dest: .diary)
            DiagnoserView().withNavbar(dest: .diagnoses)
            AssistantView().withNavbar(dest: .chat)
            Mood1View().withNavbar(dest: .mood)
        }
        .animation(.easeInOut(duration: 0.22), value: NavRouter.shared.current)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - 7  Preview

#Preview {
    RootContainer()
        .preferredColorScheme(.dark)
}
