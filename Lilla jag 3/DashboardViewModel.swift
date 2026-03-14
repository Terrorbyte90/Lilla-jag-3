import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var affirmation: String = AffirmationManager.random()
    @Published var showChatty = false
    @Published var showNumbers = false
    @Published var showCrisisPlan = false
    @Published var showDonation = false
    @Published var showForum = false
    @Published var showPsykolog = false
    @Published var showUkraine = false
    @Published var showSocial = false
    @Published var showBreathing = false

    // Streak
    @Published var currentStreak: Int = 0
    @Published var hasCheckedInToday: Bool = false

    // Quick mood check-in
    @Published var selectedQuickMood: QuickMood? = nil
    @Published var showMoodConfirmation = false

    private var cancellables = Set<AnyCancellable>()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let streakKey = "lj_streak_dates"

    init() {
        timer
            .sink { [weak self] _ in
                self?.affirmation = AffirmationManager.random()
            }
            .store(in: &cancellables)
        loadStreak()
    }

    // MARK: - Streak

    func recordCheckIn() {
        var dates = loadStreakDates()
        let today = Calendar.current.startOfDay(for: .now)
        if !dates.contains(today) {
            dates.append(today)
            saveStreakDates(dates)
        }
        loadStreak()
    }

    private func loadStreak() {
        let dates = loadStreakDates().sorted().reversed()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        hasCheckedInToday = dates.contains(today)

        var streak = 0
        var checkDate = today
        for date in dates {
            if cal.isDate(date, inSameDayAs: checkDate) {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
            } else if date < checkDate {
                break
            }
        }
        currentStreak = streak
    }

    private func loadStreakDates() -> [Date] {
        guard let data = UserDefaults.standard.data(forKey: streakKey),
              let dates = try? JSONDecoder().decode([Date].self, from: data) else { return [] }
        return dates
    }

    private func saveStreakDates(_ dates: [Date]) {
        if let data = try? JSONEncoder().encode(dates) {
            UserDefaults.standard.set(data, forKey: streakKey)
        }
    }
}

// MARK: - Quick Mood

enum QuickMood: String, CaseIterable {
    case great = "Fantastiskt"
    case good = "Bra"
    case okay = "Okej"
    case low = "Nere"
    case bad = "Dåligt"

    var emoji: String {
        switch self {
        case .great: return "😊"
        case .good:  return "🙂"
        case .okay:  return "😐"
        case .low:   return "😔"
        case .bad:   return "😢"
        }
    }

    var color: Color {
        switch self {
        case .great: return .warmGold
        case .good:  return .warmSage
        case .okay:  return .warmLavender
        case .low:   return .warmCoral
        case .bad:   return .warmRose
        }
    }
}
