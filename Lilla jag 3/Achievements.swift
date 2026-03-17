// Achievements.swift
// Lilla Jag
// Achievements and badges system

import SwiftUI
import Combine

// MARK: - Achievement Model

struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String        // SF Symbol name
    let colorHex: UInt      // for Color(hex:)
    var isUnlocked: Bool
    var unlockedDate: Date?
}

// MARK: - AchievementsStore

final class AchievementsStore: ObservableObject {

    static let shared = AchievementsStore()

    @Published var achievements: [Achievement]
    @Published var newlyUnlocked: Achievement?

    private let userDefaultsKey = "lj_achievements"

    private init() {
        if let data = UserDefaults.standard.data(forKey: "lj_achievements"),
           let decoded = try? JSONDecoder().decode([Achievement].self, from: data) {
            // Merge saved unlock state onto the canonical list so new achievements
            // added in future updates also appear for existing users.
            let savedMap = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
            self.achievements = AchievementsStore.defaultAchievements.map { base in
                if let saved = savedMap[base.id] {
                    var merged = base
                    merged.isUnlocked = saved.isUnlocked
                    merged.unlockedDate = saved.unlockedDate
                    return merged
                }
                return base
            }
        } else {
            self.achievements = AchievementsStore.defaultAchievements
        }
    }

    // MARK: Predefined achievements

    static let defaultAchievements: [Achievement] = [
        Achievement(
            id: "first_step",
            title: "Första steget",
            description: "Logga ditt mående för första gången",
            icon: "star.fill",
            colorHex: 0xFFD166,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Achievement(
            id: "streak_3",
            title: "3 dagar i rad",
            description: "Logga mående 3 dagar i följd",
            icon: "flame.fill",
            colorHex: 0xFF6B35,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Achievement(
            id: "streak_7",
            title: "En vecka stark",
            description: "Håll en 7-dagarsstreak",
            icon: "trophy.fill",
            colorHex: 0xFFE566,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Achievement(
            id: "streak_30",
            title: "Månadshjälte",
            description: "Håll en 30-dagarsstreak",
            icon: "crown.fill",
            colorHex: 0xA78BFA,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Achievement(
            id: "journal_5",
            title: "Dagboksskribent",
            description: "Skriv 5 dagboksinlägg",
            icon: "book.fill",
            colorHex: 0x2DD4BF,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Achievement(
            id: "breathing_10",
            title: "Andningsexpert",
            description: "Slutför 10 andningsövningar",
            icon: "wind",
            colorHex: 0x60A5FA,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Achievement(
            id: "mood_10",
            title: "Reflektiv",
            description: "Logga ditt mående 10 gånger",
            icon: "heart.fill",
            colorHex: 0xFB7185,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Achievement(
            id: "chat_5",
            title: "Konversatör",
            description: "Chatta med AI-assistenten 5 gånger",
            icon: "bubble.left.fill",
            colorHex: 0xC4B5FD,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Achievement(
            id: "mood_30",
            title: "Månadslogger",
            description: "Logga ditt mående 30 gånger",
            icon: "calendar.badge.checkmark",
            colorHex: 0x4ADE80,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Achievement(
            id: "pioneer",
            title: "Välmåendepionjär",
            description: "Lås upp 5 andra prestationer",
            icon: "sparkles",
            colorHex: 0xFFD166,
            isUnlocked: false,
            unlockedDate: nil
        )
    ]

    // MARK: Check and unlock

    func checkAndUnlock(
        streakDays: Int,
        moodLogCount: Int,
        journalCount: Int,
        breathingCount: Int,
        chatCount: Int
    ) {
        var didUnlockAny = false

        // "Första steget" – at least one mood log
        if moodLogCount >= 1 {
            didUnlockAny = unlock("first_step") || didUnlockAny
        }
        // "3 dagar i rad"
        if streakDays >= 3 {
            didUnlockAny = unlock("streak_3") || didUnlockAny
        }
        // "En vecka stark"
        if streakDays >= 7 {
            didUnlockAny = unlock("streak_7") || didUnlockAny
        }
        // "Månadshjälte"
        if streakDays >= 30 {
            didUnlockAny = unlock("streak_30") || didUnlockAny
        }
        // "Dagboksskribent"
        if journalCount >= 5 {
            didUnlockAny = unlock("journal_5") || didUnlockAny
        }
        // "Andningsexpert"
        if breathingCount >= 10 {
            didUnlockAny = unlock("breathing_10") || didUnlockAny
        }
        // "Reflektiv"
        if moodLogCount >= 10 {
            didUnlockAny = unlock("mood_10") || didUnlockAny
        }
        // "Konversatör"
        if chatCount >= 5 {
            didUnlockAny = unlock("chat_5") || didUnlockAny
        }
        // "Månadslogger"
        if moodLogCount >= 30 {
            didUnlockAny = unlock("mood_30") || didUnlockAny
        }
        // "Välmåendepionjär" – unlock 5 other achievements first, then check
        let unlockedCount = achievements.filter { $0.isUnlocked && $0.id != "pioneer" }.count
        if unlockedCount >= 5 {
            didUnlockAny = unlock("pioneer") || didUnlockAny
        }

        if didUnlockAny {
            save()
        }
    }

    // Marks a single achievement as unlocked. Returns true if it was newly unlocked.
    @discardableResult
    func markUnlocked(_ id: String) -> Bool {
        guard let index = achievements.firstIndex(where: { $0.id == id }),
              !achievements[index].isUnlocked else { return false }

        achievements[index].isUnlocked = true
        achievements[index].unlockedDate = Date()
        newlyUnlocked = achievements[index]
        save()
        return true
    }

    // MARK: Private helpers

    @discardableResult
    private func unlock(_ id: String) -> Bool {
        guard let index = achievements.firstIndex(where: { $0.id == id }),
              !achievements[index].isUnlocked else { return false }

        achievements[index].isUnlocked = true
        achievements[index].unlockedDate = Date()

        // Trigger popup for the most recently unlocked achievement
        newlyUnlocked = achievements[index]
        return true
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    var unlockedCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }
}

// MARK: - AchievementBadgeView

struct AchievementBadgeView: View {
    let achievement: Achievement

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        achievement.isUnlocked
                            ? Color(hex: achievement.colorHex).opacity(0.18)
                            : Color.gray.opacity(0.10)
                    )
                    .frame(width: 64, height: 64)

                Circle()
                    .strokeBorder(
                        achievement.isUnlocked
                            ? Color(hex: achievement.colorHex).opacity(0.55)
                            : Color.gray.opacity(0.25),
                        lineWidth: 2
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: achievement.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(
                        achievement.isUnlocked
                            ? Color(hex: achievement.colorHex)
                            : Color.gray.opacity(0.40)
                    )
                    .symbolRenderingMode(.hierarchical)

                if !achievement.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray.opacity(0.50))
                        .offset(x: 20, y: 20)
                }
            }
            .frame(width: 64, height: 64)
            .scaleEffect(appeared ? 1.0 : 0.85)
            .animation(
                achievement.isUnlocked
                    ? .spring(response: 0.45, dampingFraction: 0.55)
                    : .none,
                value: appeared
            )

            Text(achievement.title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 80)
        }
        .frame(width: 80, height: 90)
        .onAppear {
            if achievement.isUnlocked {
                appeared = true
            }
        }
        .onChange(of: achievement.isUnlocked) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - AchievementsGridView

struct AchievementsGridView: View {
    @StateObject private var store = AchievementsStore.shared
    @State private var showPopup = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header summary
                        HStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color(hex: 0xFFD166))
                                .symbolRenderingMode(.hierarchical)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(store.unlockedCount) av \(store.achievements.count) upplåsta")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)

                                ProgressView(
                                    value: Double(store.unlockedCount),
                                    total: Double(store.achievements.count)
                                )
                                .tint(Color(hex: 0xFFD166))
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // Grid
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(store.achievements) { achievement in
                                AchievementBadgeView(achievement: achievement)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Dina prestationer")
            .navigationBarTitleDisplayMode(.large)
            .overlay(alignment: .bottom) {
                if showPopup, let achievement = store.newlyUnlocked {
                    AchievementUnlockPopup(achievement: achievement)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            )
                        )
                        .padding(.bottom, 24)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showPopup)
            .onChange(of: store.newlyUnlocked?.id) { _, newID in
                guard newID != nil else { return }
                showPopup = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showPopup = false
                    }
                }
            }
        }
    }
}

// MARK: - AchievementUnlockPopup

struct AchievementUnlockPopup: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: achievement.colorHex).opacity(0.20))
                    .frame(width: 52, height: 52)

                Image(systemName: achievement.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: achievement.colorHex))
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Ny prestation upplåst!")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(achievement.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(achievement.description)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(Color(hex: achievement.colorHex))
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            Color(hex: achievement.colorHex).opacity(0.35),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color(hex: achievement.colorHex).opacity(0.18), radius: 16, x: 0, y: 6)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview("Achievements Grid") {
    AchievementsGridView()
}

#Preview("Badge – unlocked") {
    let a = Achievement(
        id: "preview_unlocked",
        title: "Första steget",
        description: "Logga ditt mående för första gången",
        icon: "star.fill",
        colorHex: 0xFFD166,
        isUnlocked: true,
        unlockedDate: Date()
    )
    return AchievementBadgeView(achievement: a)
        .padding()
}

#Preview("Badge – locked") {
    let a = Achievement(
        id: "preview_locked",
        title: "Månadshjälte",
        description: "Håll en 30-dagarsstreak",
        icon: "crown.fill",
        colorHex: 0xA78BFA,
        isUnlocked: false,
        unlockedDate: nil
    )
    return AchievementBadgeView(achievement: a)
        .padding()
}

#Preview("Unlock Popup") {
    let a = Achievement(
        id: "preview_popup",
        title: "En vecka stark",
        description: "Håll en 7-dagarsstreak",
        icon: "trophy.fill",
        colorHex: 0xFFE566,
        isUnlocked: true,
        unlockedDate: Date()
    )
    return ZStack(alignment: .bottom) {
        Color.gray.opacity(0.15).ignoresSafeArea()
        AchievementUnlockPopup(achievement: a)
            .padding(.bottom, 40)
    }
}
