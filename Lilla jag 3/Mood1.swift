//
//  Mood1.swift
//  LillaJag
//
//  Redesignad mars 2026 – Premium dashboard med AHA-insikter, heatmap & flödeslogg.
//  Datamodell och buisness-logik är oförändrad.
//

import SwiftUI
import Charts
import AVKit
import Foundation
import UIKit

// MARK: - Datamodell
struct MoodEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    // Kvalitetsindex (0-1)
    var moodQuality    : Double
    var anxietyLevel   : Double
    var sleepQuality   : Double
    var outdoorQuality : Double
    var socialQuality  : Double
    var routineQuality : Double
    // Utökade spårningar
    var energyLevel    : Double
    var emotions       : [String]
    var tags           : [String]
    var notes          : String
    // Övrig data
    var sleepHours     : Int
    var activities     : [String]
    var socialPeople   : [String]
    var outdoorMinutes : Int
    var trainingType   : String?
    var mealsCount     : Int
    // Vanor / mål
    var habitsDone     : [String]
    // Reflektioner
    var positives      : [String]
    var negatives      : [String]
    var wished         : [String]
    // GPT
    var summary        : String
    var insights       : [String]
    var advice         : [String]
}

// MARK: - Store
@MainActor
final class MoodStore: ObservableObject {
    @Published private(set) var entries: [MoodEntry] = []
    private let url: URL
    init() {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = doc.appendingPathComponent("mood_entries.json")
        load()
    }
    func add(_ entry: MoodEntry) { entries.append(entry); save() }
    func replace(_ entry: MoodEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
            save()
        }
    }
    private var lastWeek: [MoodEntry] {
        guard let since = Calendar.current.date(byAdding: .day, value: -6, to: .now) else { return [] }
        return entries.filter { Calendar.current.isDate($0.date, inSameDayAsOrAfter: since) }
    }
    var avgMood    : Double { lastWeek.map(\.moodQuality   ).average(default: 0.5) }
    var avgAnxiety : Double { lastWeek.map(\.anxietyLevel  ).average(default: 0.5) }
    var avgSleep   : Double { lastWeek.map(\.sleepQuality  ).average(default: 0.5) }
    var avgOutdoor : Double { lastWeek.map(\.outdoorQuality).average(default: 0.5) }
    var avgSocial  : Double { lastWeek.map(\.socialQuality ).average(default: 0.5) }
    var avgRoutine : Double { lastWeek.map(\.routineQuality).average(default: 0.5) }
    var avgEnergy  : Double { lastWeek.map(\.energyLevel   ).average(default: 0.5) }

    var avgSleepHours: Double {
        let d = lastWeek.filter { $0.sleepHours > 0 }
        guard !d.isEmpty else { return 0 }
        return Double(d.map(\.sleepHours).reduce(0, +)) / Double(d.count)
    }

    var last30: [MoodEntry] {
        guard let since = Calendar.current.date(byAdding: .day, value: -29, to: .now) else { return [] }
        return entries.filter { Calendar.current.isDate($0.date, inSameDayAsOrAfter: since) }
            .sorted { $0.date < $1.date }
    }
    var last90: [MoodEntry] {
        guard let since = Calendar.current.date(byAdding: .day, value: -89, to: .now) else { return [] }
        return entries
            .filter { Calendar.current.isDate($0.date, inSameDayAsOrAfter: since) }
            .sorted { $0.date < $1.date }
    }

    private func save() { try? JSONEncoder().encode(entries).write(to: url) }
    private func load() {
        guard let d = try? Data(contentsOf: url),
              let e = try? JSONDecoder().decode([MoodEntry].self, from: d) else { return }
        entries = e
    }

    // MARK: - Statistik
    struct ActivityCount: Identifiable { let id = UUID(); let name: String; let count: Int }
    func activityFrequencies(window: [MoodEntry]? = nil) -> [ActivityCount] {
        let data = window ?? last30
        var freq: [String:Int] = [:]
        for e in data {
            for a in e.activities { freq[a, default: 0] += 1 }
            for h in e.habitsDone { freq["Vana: \(h)", default: 0] += 1 }
        }
        return freq.map { ActivityCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    struct MoodCorrelation: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let delta: Double
        let present: Int
        let total: Int
    }

    func correlations(window: [MoodEntry]? = nil) -> [MoodCorrelation] {
        let data = window ?? last90
        guard !data.isEmpty else { return [] }
        var factors = Set<String>()
        for e in data {
            e.activities.forEach { factors.insert("Aktivitet: \($0)") }
            e.habitsDone.forEach { factors.insert("Vana: \($0)") }
            factors.insert("Sömn≥7h"); factors.insert("Utomhus≥30m")
            factors.insert("Socialt≥medel"); factors.insert("Energi≥medel")
            if let t = e.trainingType { factors.insert("Träning: \(t)") }
        }
        func factorPresent(_ f: String, _ e: MoodEntry) -> Bool {
            if f.hasPrefix("Aktivitet: ") { return e.activities.contains(String(f.dropFirst(11))) }
            if f.hasPrefix("Vana: ")      { return e.habitsDone.contains(String(f.dropFirst(6))) }
            if f == "Sömn≥7h"             { return e.sleepHours >= 7 }
            if f == "Utomhus≥30m"         { return e.outdoorMinutes >= 30 }
            if f == "Socialt≥medel"       { return e.socialQuality >= 0.6 }
            if f == "Energi≥medel"        { return e.energyLevel >= 0.6 }
            if f.hasPrefix("Träning: ")   { return e.trainingType == String(f.dropFirst(9)) }
            return false
        }
        var result: [MoodCorrelation] = []
        for f in factors {
            var presentVals: [Double] = []; var absentVals: [Double] = []
            for e in data { factorPresent(f, e) ? presentVals.append(e.moodQuality) : absentVals.append(e.moodQuality) }
            guard !presentVals.isEmpty, !absentVals.isEmpty else { continue }
            let delta = presentVals.average(default: 0) - absentVals.average(default: 0)
            result.append(.init(name: f, delta: delta, present: presentVals.count, total: data.count))
        }
        return result.sorted { abs($0.delta) > abs($1.delta) }
    }

    func moodOn(_ date: Date) -> Double? {
        let day = entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        guard !day.isEmpty else { return nil }
        return day.map(\.moodQuality).average(default: 0.5)
    }

    var currentStreak: Int {
        guard !entries.isEmpty else { return 0 }
        let days = Set(entries.map { Calendar.current.startOfDay(for: $0.date) })
        var streak = 0
        var d = Calendar.current.startOfDay(for: Date())
        while days.contains(d) { streak += 1; d = Calendar.current.date(byAdding: .day, value: -1, to: d)! }
        return streak
    }
    var longestStreak: Int {
        guard !entries.isEmpty else { return 0 }
        let days = Set(entries.map { Calendar.current.startOfDay(for: $0.date) })
        var best = 0
        for start in days {
            var len = 1
            var d = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            while days.contains(d) { len += 1; d = Calendar.current.date(byAdding: .day, value: 1, to: d)! }
            best = max(best, len)
        }
        return best
    }

    // Topp-veckodagen (0=Måndag … 6=Söndag)
    var bestWeekday: (name: String, avg: Double)? {
        guard last30.count >= 3 else { return nil }
        let names = ["Måndag","Tisdag","Onsdag","Torsdag","Fredag","Lördag","Söndag"]
        var groups: [Int: [Double]] = [:]
        for e in last30 {
            let wd = (Calendar.current.component(.weekday, from: e.date) + 5) % 7
            groups[wd, default: []].append(e.moodQuality)
        }
        guard let best = groups.max(by: { $0.value.average(default: 0) < $1.value.average(default: 0) }) else { return nil }
        return (names[best.key], best.value.average(default: 0))
    }
}

// MARK: - Bakgrund (konsekvent med resten av appen)
struct AppBackground: View {
    var body: some View {
        WarmBackground()
    }
}

// MARK: - AHA Insight Model
struct AHAInsight: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let detail: String
    let accentColor: Color
}

// MARK: - AHA Insights Generator
@MainActor
struct AHAInsightsGenerator {
    static func generate(store: MoodStore) -> [AHAInsight] {
        let data = store.last30
        guard data.count >= 3 else { return [] }

        var insights: [AHAInsight] = []

        // 1. Sömn-mående korrelation
        let sleepCorr = store.correlations().first(where: { $0.name == "Sömn≥7h" })
        if let sc = sleepCorr, abs(sc.delta) > 0.08 {
            let dir = sc.delta > 0 ? "förbättrar" : "sänker"
            let pct = Int(abs(sc.delta) * 100)
            insights.append(AHAInsight(
                emoji: "🌙",
                title: "Sömn \(dir) ditt mående med \(pct)%",
                detail: "När du sover 7+ timmar är ditt snittmående märkbart \(sc.delta > 0 ? "högre" : "lägre").",
                accentColor: Color.warmLavender
            ))
        }

        // 2. Tränings-mående korrelation
        let trainCorrs = store.correlations().filter { $0.name.hasPrefix("Träning:") || $0.name.hasPrefix("Aktivitet: Tränat") }
        if let tc = trainCorrs.first, tc.delta > 0.05 {
            let pct = Int(tc.delta * 100)
            insights.append(AHAInsight(
                emoji: "💪",
                title: "Du är \(pct)% gladare på träningsdagar",
                detail: "Rörelse har en tydlig positiv effekt på ditt humör.",
                accentColor: Color.warmSage
            ))
        }

        // 3. Utomhus-korrelation
        let outdoorCorr = store.correlations().first(where: { $0.name == "Utomhus≥30m" })
        if let oc = outdoorCorr, oc.delta > 0.05 {
            let pct = Int(oc.delta * 100)
            insights.append(AHAInsight(
                emoji: "🌿",
                title: "Utomhustid = +\(pct)% bättre humör",
                detail: "30+ minuter utomhus korrelerar starkt med bättre mående för dig.",
                accentColor: Color.warmSage
            ))
        }

        // 4. Bästa veckodag
        if let best = store.bestWeekday {
            let pct = Int(best.avg * 100)
            insights.append(AHAInsight(
                emoji: "📅",
                title: "Du mår bäst på \(best.name)",
                detail: "Snittmående \(pct)/100 – ditt bästa mönster i veckan.",
                accentColor: Color.warmGold
            ))
        }

        // 5. Trenderinsikt (senaste 7 vs föregående 7)
        let last7 = store.last7()
        let prev7 = store.entries
            .filter {
                guard let from = Calendar.current.date(byAdding: .day, value: -14, to: .now),
                      let to = Calendar.current.date(byAdding: .day, value: -7, to: .now) else { return false }
                return $0.date >= from && $0.date < to
            }
        if last7.count >= 3, prev7.count >= 3 {
            let delta = last7.map(\.moodQuality).average(default: 0) - prev7.map(\.moodQuality).average(default: 0)
            if abs(delta) > 0.06 {
                let dir = delta > 0 ? "bättre" : "svårare"
                let pct = Int(abs(delta) * 100)
                insights.append(AHAInsight(
                    emoji: delta > 0 ? "📈" : "📉",
                    title: "Senaste veckan: \(pct)% \(dir) än förra",
                    detail: delta > 0
                        ? "Bra jobbat – trenden pekar uppåt!"
                        : "Du verkar ha en tuffare period just nu. Ta hand om dig.",
                    accentColor: delta > 0 ? Color.warmSage : Color.warmCoral
                ))
            }
        }

        // 6. Social korrelation
        let socialCorr = store.correlations().first(where: { $0.name == "Socialt≥medel" })
        if let sc = socialCorr, sc.delta > 0.05 {
            let pct = Int(sc.delta * 100)
            insights.append(AHAInsight(
                emoji: "🤝",
                title: "Sociala dagar ger +\(pct)% bättre mående",
                detail: "Meningsfulla samtal verkar ha stor inverkan på hur du mår.",
                accentColor: Color.warmRose
            ))
        }

        return Array(insights.prefix(4))
    }
}

// MARK: - Dashboard
struct Mood1View: View {
    @StateObject private var viewModel = MoodViewModel()
    @StateObject private var store = MoodStore()
    @State private var heroAppeared = false

    private var todayLogged: Bool {
        store.entries.contains { Calendar.current.isDateInToday($0.date) }
    }

    private var todayDateString: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "EEEE d MMMM"
        return df.string(from: Date()).capitalized(with: df.locale)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        heroCard
                        kpiRow
                        ahaInsightsSection
                        calendarHeatmap
                        trendChartSection
                        logButton
                    }
                    .frame(maxWidth: 640)
                    .padding(.top, 20)
                    .padding(.horizontal, DesignSystem.Spacing.horizontalPadding(for: geo.size.width))
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $viewModel.showLogger) {
            MoodLogFlowView(store: store) { newEntry in store.add(newEntry) }
        }
        .fullScreenCover(item: $viewModel.popupEntry) { entry in
            SummaryPopup(entry: entry)
        }
    }

    // MARK: - Hero Card helpers

    private var heroQuickMoodRow: some View {
        HStack(spacing: 0) {
            ForEach(quickMoodOptions, id: \.emoji) { opt in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.showLogger = true
                } label: {
                    VStack(spacing: 6) {
                        Text(opt.emoji).font(.system(size: 34))
                        Text(opt.label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(LJPressableButtonStyle())
            }
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }

    private var heroCheckedInBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.warmSage)
            Text("Loggat idag ✓")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.warmSage)
            Spacer()
            Text("Logga igen")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.warmSage.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0x3D1A6E), Color(hex: 0x1A1025), Color(hex: 0x2A1A3E)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.warmLavender.opacity(0.25), lineWidth: 1))

            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hur mår du idag?")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        Text(todayDateString)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    if store.currentStreak > 0 {
                        VStack(spacing: 2) {
                            Text("🔥").font(.title2)
                            Text("\(store.currentStreak)d")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.warmGold)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.warmGold.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.warmGold.opacity(0.3), lineWidth: 1))
                    }
                }
                heroQuickMoodRow
                if todayLogged { heroCheckedInBadge }
            }
            .padding(22)
        }
        .shadow(color: Color.warmLavender.opacity(0.15), radius: 20, y: 8)
        .opacity(heroAppeared ? 1 : 0)
        .offset(y: heroAppeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.05)) { heroAppeared = true }
        }
    }

    private let quickMoodOptions: [(emoji: String, label: String)] = [
        ("😊", "Bra"),
        ("🙂", "Okej"),
        ("😐", "Neutralt"),
        ("😔", "Lågt"),
        ("😢", "Svårt")
    ]

    // MARK: - KPI Row
    private var kpiRow: some View {
        HStack(spacing: 10) {
            kpiCard(
                icon: "heart.fill",
                color: Color.warmRose,
                value: String(format: "%.1f", store.avgMood * 10),
                unit: "/10",
                label: "Veckosnitt"
            )
            kpiCard(
                icon: "moon.fill",
                color: Color.warmLavender,
                value: String(format: "%.1f", store.avgSleepHours),
                unit: "h",
                label: "Sömnsnitt"
            )
            kpiCard(
                icon: "flame.fill",
                color: Color.warmGold,
                value: "\(store.currentStreak)",
                unit: "d",
                label: "Streak"
            )
        }
    }

    private func kpiCard(icon: String, color: Color, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.08), radius: 8, y: 4)
    }

    // MARK: - AHA Insights
    private var ahaInsightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                Text("🔍")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dina mönster & insikter")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Genererat från dina loggade dagar")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
            }

            let insights = AHAInsightsGenerator.generate(store: store)

            if insights.isEmpty {
                // Placeholder
                HStack(spacing: 14) {
                    Text("🌱")
                        .font(.title)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Logga 3 dagar för att se dina mönster")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Dina personliga insikter dyker upp här efter ett par dagar.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { idx, insight in
                        ahaInsightRow(insight: insight, delay: Double(idx) * 0.07)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.warmGold.opacity(0.5), Color.warmGold.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
        )
        .shadow(color: Color.warmGold.opacity(0.08), radius: 16, y: 6)
    }

    private func ahaInsightRow(insight: AHAInsight, delay: Double) -> some View {
        HStack(spacing: 14) {
            // Färgad vänsterkant
            RoundedRectangle(cornerRadius: 3)
                .fill(insight.accentColor)
                .frame(width: 4)
                .frame(height: 46)

            Text(insight.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(insight.detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Calendar Heatmap helpers

    private func heatmapCell(day: Date) -> some View {
        let mood = store.moodOn(day)
        let isToday = Calendar.current.isDateInToday(day)
        return ZStack {
            Circle().fill(heatmapColor(for: mood)).frame(width: 28, height: 28)
            if isToday {
                Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5).frame(width: 30, height: 30)
            }
            Text(String(Calendar.current.component(.day, from: day)))
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(mood != nil ? .white : .white.opacity(0.2))
        }
        .frame(width: 28, height: 28)
        .onTapGesture {
            if let e = store.entries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.popupEntry = e
            }
        }
    }

    private var calendarGrid: some View {
        let weekdays = ["Må","Ti","On","To","Fr","Lö","Sö"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(weekdays, id: \.self) { wd in
                Text(wd)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(height: 16)
            }
            ForEach(Array(heatmapCells.enumerated()), id: \.offset) { _, cellDate in
                if let day = cellDate { heatmapCell(day: day) }
                else { Color.clear.frame(width: 28, height: 28) }
            }
        }
    }

    // MARK: - Calendar Heatmap
    private var calendarHeatmap: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(heatmapMonthTitle)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(heatmapLegend, id: \.label) { item in
                        HStack(spacing: 4) {
                            Circle().fill(item.color).frame(width: 8, height: 8)
                            Text(item.label)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
            }
            calendarGrid
        }
        .padding(20)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var heatmapMonthTitle: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "LLLL yyyy"
        return df.string(from: Date()).capitalized(with: df.locale)
    }

    private var heatmapCells: [Date?] {
        var cells: [Date?] = []
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: Date()) else { return cells }
        let first = interval.start
        let weekdayOfFirst = (cal.component(.weekday, from: first) + 5) % 7
        cells.append(contentsOf: Array(repeating: nil, count: weekdayOfFirst))
        var day = first
        while day < interval.end {
            cells.append(day)
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return cells
    }

    private func heatmapColor(for mood: Double?) -> Color {
        guard let m = mood else { return Color.white.opacity(0.08) }
        if m >= 0.75 { return Color.warmSage.opacity(0.8) }
        if m >= 0.5  { return Color.warmGold.opacity(0.7) }
        if m >= 0.3  { return Color.warmCoral.opacity(0.65) }
        return Color(hex: 0xFF5B5B).opacity(0.6)
    }

    private let heatmapLegend: [(label: String, color: Color)] = [
        ("Bra", Color.warmSage.opacity(0.8)),
        ("Ok", Color.warmGold.opacity(0.7)),
        ("Lågt", Color.warmCoral.opacity(0.65))
    ]

    // MARK: - Trend Chart helpers

    private func trendBarEntry(_ entry: MoodEntry, barW: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4).fill(Color.warmLavender.opacity(0.3))
                    .frame(width: barW * 0.45, height: h * 0.88)
                RoundedRectangle(cornerRadius: 4).fill(Color.warmLavender.opacity(0.7))
                    .frame(width: barW * 0.45, height: max(4, h * 0.88 * entry.sleepQuality))
            }
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6).fill(Color.warmRose.opacity(0.2))
                    .frame(width: barW, height: h * 0.88)
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Color.warmRose, Color.warmCoral], startPoint: .bottom, endPoint: .top))
                    .frame(width: barW, height: max(4, h * 0.88 * entry.moodQuality))
            }
        }
        .frame(width: barW)
        .overlay(alignment: .bottom) {
            Text(dayLabel(entry.date))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .offset(y: 16)
        }
    }

    private func trendBarsGeometry(days: [MoodEntry]) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let barW: CGFloat = min(24, (w - CGFloat(days.count - 1) * 8) / CGFloat(days.count))
            let spacing: CGFloat = days.count > 1 ? (w - barW * CGFloat(days.count)) / CGFloat(days.count - 1) : 0
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ForEach([0.75, 0.5, 0.25], id: \.self) { _ in
                        Spacer()
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    }
                    Spacer()
                }
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { _, entry in
                        trendBarEntry(entry, barW: barW, h: h)
                    }
                }
            }
        }
        .frame(height: 110)
        .padding(.bottom, 22)
    }

    // MARK: - Trend Chart (senaste 7 dagar)
    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Senaste 7 dagarna")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 12) {
                    legendDot(color: Color.warmRose, label: "Mående")
                    legendDot(color: Color.warmLavender, label: "Sömn")
                }
            }
            let days = store.last7()
            if days.isEmpty {
                Text("Logga ditt första mående för att se din trend.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                trendBarsGeometry(days: days)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "EE"
        return String(df.string(from: date).prefix(2))
    }

    // MARK: - Log Button
    private var logButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            viewModel.showLogger = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Logga ditt mående →")
                    .font(.system(.body, design: .rounded, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(
                    colors: [Color.warmGold, Color.warmCoral],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .shadow(color: Color.warmGold.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(LJPressableButtonStyle())
    }
}

// MARK: - Margins
struct ScrollContentMargins: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .contentMargins(.vertical, 28, for: .scrollContent)
        } else { content }
    }
}

// MARK: - Linjediagram-metrics
enum Metric: String, CaseIterable, Identifiable {
    case mood, sleep, outdoor, social, anxiety, energy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .mood: return "Mående"
        case .sleep: return "Sömn"
        case .outdoor: return "Utomhus"
        case .social: return "Socialt"
        case .anxiety: return "Ångest"
        case .energy: return "Energi"
        }
    }
    var shortLabel: String {
        switch self {
        case .mood: return "Må."
        case .sleep: return "Sömn"
        case .outdoor: return "Ute"
        case .social: return "Socialt"
        case .anxiety: return "Ång."
        case .energy: return "Energi"
        }
    }
    func value(_ e: MoodEntry) -> Double {
        switch self {
        case .mood: return e.moodQuality
        case .sleep: return e.sleepQuality
        case .outdoor: return e.outdoorQuality
        case .social: return e.socialQuality
        case .anxiety: return e.anxietyLevel
        case .energy: return e.energyLevel
        }
    }
}

// MARK: - Kalender-grid (legacy, används i SummaryPopup)
struct CalendarGridView: View {
    let entries: [MoodEntry]
    @Binding var currentMonth: Date
    let onTap: (MoodEntry) -> Void

    private var monthCells: [Date?] {
        var cells: [Date?] = []
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: currentMonth) else { return cells }
        let first = interval.start
        let weekdayOfFirst = (cal.component(.weekday, from: first) + 6) % 7
        cells.append(contentsOf: Array(repeating: nil, count: weekdayOfFirst))
        var day = first
        while day < interval.end {
            cells.append(day)
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return cells
    }
    private func entry(on date: Date) -> MoodEntry? { entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    private func avgMood(on date: Date) -> Double? {
        let day = entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        guard !day.isEmpty else { return nil }
        return day.map(\.moodQuality).average(default: 0.5)
    }
    private func moodColor(_ v: Double) -> Color {
        let r = max(0, 1.0 - v); let g = v
        return Color(red: r, green: g, blue: 0.1)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    withAnimation { currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth)! }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .padding(8)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                Spacer()
                Button {
                    withAnimation { currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)! }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .padding(8)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
            }
            .padding(.bottom, 2)

            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                let weekdays = ["Må","Ti","On","To","Fr","Lö","Sö"]
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, label in
                    Text(label).foregroundStyle(.secondary)
                }
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, cellDate in
                    if let day = cellDate {
                        let isToday = Calendar.current.isDateInToday(day)
                        let mood = avgMood(on: day)
                        let bg = mood.map(moodColor) ?? Color.clear
                        ZStack {
                            Circle().fill(bg.opacity(mood == nil ? 0.0 : 0.8)).frame(width: 34, height: 34)
                            if isToday {
                                Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5).frame(width: 36, height: 36)
                            }
                            Text(String(Calendar.current.component(.day, from: day))).font(.caption.bold()).foregroundStyle(.white)
                        }
                        .frame(height: 40)
                        .contentShape(Rectangle())
                        .onTapGesture { if let e = entry(on: day) { onTap(e) } }
                    } else {
                        Color.clear.frame(height: 20)
                    }
                }
            }
        }
    }
}

// MARK: - Dag-popup
struct SummaryPopup: View {
    @Environment(\.dismiss) private var dismiss
    let entry: MoodEntry
    private var dateString: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "EEEE d MMMM yyyy"
        return df.string(from: entry.date).capitalized(with: df.locale)
    }
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 24) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        TitleText(dateString)
                        HStack(spacing: 10) {
                            chip("Mående \(Int(entry.moodQuality*100))")
                            chip("Sömn \(entry.sleepHours)h")
                            chip("Energi \(Int(entry.energyLevel*100))")
                        }
                        if !entry.activities.isEmpty {
                            TitleText("Aktiviteter")
                            WrapChips(items: entry.activities)
                        }
                        if !entry.habitsDone.isEmpty {
                            TitleText("Vanor")
                            WrapChips(items: entry.habitsDone.map { "✓ \($0)" })
                        }
                        if !entry.emotions.isEmpty {
                            TitleText("Känslor")
                            WrapChips(items: entry.emotions)
                        }
                        if !entry.tags.isEmpty {
                            TitleText("Taggar")
                            WrapChips(items: entry.tags)
                        }
                        if !entry.notes.isEmpty {
                            TitleText("Anteckning")
                            Text(entry.notes).foregroundStyle(.white).glass()
                        }
                        if !entry.summary.isEmpty {
                            Divider()
                            TitleText("AI-sammanfattning")
                            Text(entry.summary).foregroundStyle(.white)
                        }
                        if !entry.insights.isEmpty {
                            Divider()
                            TitleText("Insikter")
                            ForEach(entry.insights, id: \.self) { Text("• \($0)").foregroundStyle(.white) }
                        }
                        if !entry.advice.isEmpty {
                            Divider()
                            TitleText("Rekommendationer")
                            ForEach(entry.advice, id: \.self) { Text("→ \($0)").foregroundStyle(.white) }
                        }
                    }
                }
                Button("Stäng") { dismiss() }
                    .buttonStyle(GradientButtonStyle())
                    .padding(.bottom, 40)
            }
            .padding()
        }
    }
    private func chip(_ t: String) -> some View {
        Text(t).font(.footnote).padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

// MARK: - Humörlogg (MoodLogFlowView)
struct MoodLogFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var entry = MoodEntry(
        id: UUID(), date: Date(),
        moodQuality: 0.5, anxietyLevel: 0.5, sleepQuality: 0.5, outdoorQuality: 0.5,
        socialQuality: 0.5, routineQuality: 0.5,
        energyLevel: 0.5, emotions: [], tags: [], notes: "",
        sleepHours: 0, activities: [], socialPeople: [], outdoorMinutes: 0,
        trainingType: nil, mealsCount: 0, habitsDone: [],
        positives: [], negatives: [], wished: [],
        summary: "", insights: [], advice: []
    )
    let store: MoodStore
    let onSave: (MoodEntry) -> Void

    // selections
    @State private var generalMood = ""
    @State private var hadAnxiety = ""
    @State private var negativeFeel = ""
    @State private var sleepState = ""
    @State private var sleepHourSel = ""
    @State private var selectedActivities: [String] = []
    @State private var meaningfulSocial = ""
    @State private var socialPeopleSel: [String] = []
    @State private var beenOutside = ""
    @State private var outsideDuration = ""
    @State private var hadSun = ""
    @State private var trained = ""
    @State private var trainingFeel = ""
    @State private var ateToday = ""
    @State private var mealsToday = ""
    @State private var positivesSel: [String] = []
    @State private var negativesSel: [String] = []
    @State private var wishedSel: [String] = []
    @State private var energySel = ""
    @State private var emotionsSel: [String] = []
    @State private var habitsSel: [String] = []
    @State private var tagsSel: [String] = []
    @State private var notesTxt: String = ""
    @State private var loadingProgress = 0
    @State private var gptSummary = ""
    @State private var gptInsights: [String] = []
    @State private var gptAdvice  : [String] = []
    private let habitCandidates = ["7+ timmar sömn","30+ min utomhus","10+ min meditation","Träning","Grönsaker till 2 måltider"]

    private let totalSteps = 12

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Progress pill
                if step < 12 {
                    progressPill
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                }

                ScrollView {
                    VStack(spacing: 24) {
                        switch step {
                        case 0:  generalStep
                        case 1:  sleepStep
                        case 2:  dayStep
                        case 3:  socialStep
                        case 4:  outdoorStep
                        case 5:  trainingStep
                        case 6:  foodStep
                        case 7:  energyStep
                        case 8:  emotionsStep
                        case 9:  habitsStep
                        case 10: tagsStep
                        case 11: notesStep
                        case 12: loadingStep
                        case 13: summaryStep
                        case 14: recommendationsStep
                        default: EmptyView()
                        }
                    }
                    .frame(maxWidth: 620)
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
                .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .safeAreaInset(edge: .bottom) {
            FooterContainer {
                HStack {
                    if step > 0 && step < 12 {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.3)) { step -= 1 }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.caption.weight(.semibold))
                                Text("Bakåt")
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                    }
                    Spacer()
                    if step < 11 {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
                        } label: { Text("Nästa →") }
                            .buttonStyle(GradientButtonStyle())
                            .frame(maxWidth: 220)
                    } else if step == 11 {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.3)) { step = 12 }
                        } label: { Text("Sammanfatta ✨") }
                            .buttonStyle(GradientButtonStyle())
                            .frame(maxWidth: 260)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Progress Pill
    private var progressPill: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Steg \(step + 1) av \(totalSteps)")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.warmLavender, Color.warmRose],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * (CGFloat(step + 1) / CGFloat(totalSteps)), height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Steg 0 helpers
    private func moodTile(opt: (emoji: String, label: String, value: String)) -> some View {
        let isSelected = generalMood == opt.value
        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.3)) { generalMood = opt.value }
        } label: {
            VStack(spacing: 8) {
                Text(opt.emoji).font(.system(size: 32))
                Text(opt.label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected
                    ? LinearGradient(colors: [Color.warmLavender.opacity(0.4), Color.warmRose.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.warmLavender.opacity(0.6) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var moodEmojiTilesRow: some View {
        HStack(spacing: 10) {
            ForEach(moodEmojiOptions, id: \.value) { opt in moodTile(opt: opt) }
        }
    }

    // MARK: - Steg 0: Generellt mående
    private var generalStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "💭", title: "Hur har du mått idag?", subtitle: "Välj det som stämmer bäst")
            moodEmojiTilesRow
            logDivider("Ångest idag?")
            ButtonGrid(single: true,
                       options: ["Inte alls","Lite","Mellan","Hög","Mycket hög","Extrem"],
                       selection: $hadAnxiety)
            logDivider("Andra negativa känslor?")
            ButtonGrid(single: true,
                       options: ["Inga","Oro","Ilska","Sorg","Besvikelse","Stress"],
                       selection: $negativeFeel)
            InfoText("Det är normalt att uppleva olika känslor under olika dagar – du är bara människa.")
        }
        .logCard()
    }

    private let moodEmojiOptions: [(emoji: String, label: String, value: String)] = [
        ("😊", "Bra", "Bra"),
        ("🙂", "Okej", "Helt okej"),
        ("😐", "Neutralt", "Neutralt"),
        ("😔", "Lågt", "Lite låg"),
        ("😢", "Svårt", "Mycket låg")
    ]

    // MARK: - Steg 1: Sömn
    private var sleepStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "🌙", title: "Hur sov du?", subtitle: "Sömn är grunden för välmående")

            logDivider("Antal timmar")
            // Visuell timmar-väljare
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                ForEach(["0-3 h","4-5 h","6-7 h","8 h","9-10 h","11+ h"], id: \.self) { opt in
                    sleepHourTile(opt)
                }
            }

            logDivider("Sömnkvalitet")
            ButtonGrid(single: true,
                       options: ["Utmärkt","Bra","Godkänd","Orolig","Dålig","Mycket dålig"],
                       selection: $sleepState)

            InfoText("Tillräcklig sömn förbättrar minne, immunförsvar och humör.")
        }
        .logCard()
    }

    private func sleepHourTile(_ opt: String) -> some View {
        let selected = sleepHourSel == opt
        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.3)) { sleepHourSel = opt }
        } label: {
            VStack(spacing: 6) {
                Text("🌙")
                    .font(.title2)
                    .opacity(selected ? 1 : 0.4)
                Text(opt)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(selected ? .white : .white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                selected
                    ? Color.warmLavender.opacity(0.25)
                    : Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.warmLavender.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Steg 2: Aktiviteter
    private var dayStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "🌟", title: "Vad har du gjort idag?", subtitle: "Välj alla som stämmer")
            ButtonGrid(single: false,
                       options: ["Jobbat","Studerat","Tränat","Läst","Skapat","Umgåtts familj","Spelat","Tagit det lugnt","Städat","Handlat","Promenerat","Meditation","Lagat mat","Sett film","Volontärarbete"],
                       selection: $selectedActivities)
            InfoText("Mening + framsteg → bättre välmående.")
        }
        .logCard()
    }

    // MARK: - Steg 3: Socialt
    private var socialStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "🤝", title: "Sociala kontakter", subtitle: "Relationer påverkar ditt mående")
            logDivider("Meningsfulla samtal?")
            ButtonGrid(single: true,
                       options: ["Flera samtal","Ett par samtal","Ett kort samtal","Inga samtal","Djupa samtal","Småprat"],
                       selection: $meaningfulSocial)
            logDivider("Vilka har du pratat med?")
            ButtonGrid(single: false,
                       options: ["Familj","Partner","Barn","Vänner","Kollegor","Nya bekanta","Grannar","Online-vänner","Husdjur"],
                       selection: $socialPeopleSel)
        }
        .logCard()
    }

    // MARK: - Steg 4: Utomhus
    private var outdoorStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "🌿", title: "Utomhus & natur", subtitle: "Frisk luft gör skillnad")
            logDivider("Har du varit utomhus idag?")
            ButtonGrid(single: true, options: ["Ja","Nej"], selection: $beenOutside)
            logDivider("Hur länge?")
            ButtonGrid(single: true,
                       options: ["<10 min","10-30 min","30-60 min","60-90 min","90+ min","2+ tim"],
                       selection: $outsideDuration)
            logDivider("Solljus på huden?")
            ButtonGrid(single: true, options: ["Ja","Litegrann","Nej"], selection: $hadSun)
        }
        .logCard()
    }

    // MARK: - Steg 5: Träning
    private var trainingStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "💪", title: "Träning & rörelse", subtitle: "Rörelse boostar humöret")
            logDivider("Har du tränat idag?")
            ButtonGrid(single: true,
                       options: ["Ingen","Stretching","Lätt","Mellan","Hård","Återhämtning"],
                       selection: $trained)
            logDivider("Hur kändes träningen?")
            ButtonGrid(single: true,
                       options: ["Energigivande","Kul","Neutralt","Utmanande","Tungt","Lättsamt"],
                       selection: $trainingFeel)
        }
        .logCard()
    }

    // MARK: - Steg 6: Mat
    private var foodStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "🥗", title: "Mat & näring", subtitle: "Vad du äter påverkar hur du mår")
            logDivider("Hur var dagens mat?")
            ButtonGrid(single: true,
                       options: ["Utmärkt","Mycket bra","Bra","Okej","Behövde förbättras","Dålig"],
                       selection: $ateToday)
            logDivider("Hur många måltider?")
            ButtonGrid(single: true, options: ["1","2","3","4","5","6+"], selection: $mealsToday)
        }
        .logCard()
    }

    // MARK: - Steg 7 helpers
    private func energyTile(opt: (emoji: String, label: String)) -> some View {
        let isSelected = energySel == opt.label
        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation { energySel = opt.label }
        } label: {
            VStack(spacing: 8) {
                Text(opt.emoji).font(.title)
                Text(opt.label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color.warmGold.opacity(0.2) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.warmGold.opacity(0.5) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var energyTilesRow: some View {
        HStack(spacing: 10) {
            ForEach(energyOptions, id: \.label) { opt in energyTile(opt: opt) }
        }
    }

    // MARK: - Steg 7: Energi
    private var energyStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "⚡", title: "Din energi idag", subtitle: "Hur pigg och levande kändes du?")
            energyTilesRow
        }
        .logCard()
    }

    private let energyOptions: [(emoji: String, label: String)] = [
        ("😴", "Mycket låg"),
        ("😑", "Låg"),
        ("😊", "Lagom"),
        ("⚡", "Hög"),
        ("🚀", "Mycket hög")
    ]

    // MARK: - Steg 8: Känslor
    private var emotionsStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "🎭", title: "Dina känslor idag", subtitle: "Välj alla du kände")
            ButtonGrid(single: false,
                       options: ["Glad","Tacksam","Lugn","Fokuserad","Motiverad","Stressad","Orolig","Arg","Ledsen","Trött","Överväldigad","Hoppfull"],
                       selection: $emotionsSel)
        }
        .logCard()
    }

    // MARK: - Steg 9: Vanor
    private var habitsStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "✅", title: "Vanor du klarade", subtitle: "Små steg bygger stora resultat")
            ButtonGrid(single: false, options: habitCandidates, selection: $habitsSel)
        }
        .logCard()
    }

    // MARK: - Steg 10: Taggar
    private var tagsStep: some View {
        VStack(spacing: 20) {
            stepHeader(emoji: "🏷️", title: "Taggar", subtitle: "Välj det som passar dagen")
            ButtonGrid(single: false,
                       options: ["Rutiner","Fokus","Återhämtning","Relationer","Kreativitet","Jobb","Hälsa","Ekonomi"],
                       selection: $tagsSel)
        }
        .logCard()
    }

    // MARK: - Steg 11: Anteckningar
    private var notesStep: some View {
        VStack(spacing: 16) {
            stepHeader(emoji: "📝", title: "Fri anteckning", subtitle: "Skriv vad som helst om din dag")
            TextEditor(text: $notesTxt)
                .frame(minHeight: 140)
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
            InfoText("Valfritt – skriv några rader om något viktigt från dagen.")
        }
        .logCard()
    }

    // MARK: - Steg 12: Laddning
    private var loadingStep: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.warmLavender.opacity(0.1))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.8)
                    .tint(Color.warmLavender)
            }
            VStack(spacing: 8) {
                Text(statusText)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("Din dag analyseras…")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .onAppear {
            Task {
                for i in 1...4 { try await Task.sleep(nanoseconds: 800_000_000); loadingProgress = i }
                await summariseWithGPT()
            }
        }
    }

    // MARK: - Steg 13: Sammanfattning
    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(emoji: "✨", title: "Sammanfattning av din dag", subtitle: "Genererat av din lokala AI")
            Text(gptSummary)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.white)
                .padding(16)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            Button("Gå vidare →") { step = 14 }
                .buttonStyle(GradientButtonStyle())
        }
        .logCard()
    }

    // MARK: - Steg 14: Rekommendationer + AHA
    private var recommendationsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(emoji: "💡", title: "Dina insikter", subtitle: "Baserat på dagens logg")

            // AHA-insikt för just denna post
            personalAHACard

            if !gptInsights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insikter")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    ForEach(gptInsights, id: \.self) {
                        insightRow($0)
                    }
                }
            }
            if !gptAdvice.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rekommendationer")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    ForEach(gptAdvice, id: \.self) {
                        adviceRow($0)
                    }
                }
            }

            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSave(entry)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Spara & stäng")
                }
            }
            .buttonStyle(GradientButtonStyle())
        }
        .logCard()
        .foregroundStyle(.white)
    }

    // Den personliga AHA-kortet i slutet av loggen
    private var personalAHACard: some View {
        let avgStoreSleep = store.avgSleepHours
        let todaySleep = Double(entry.sleepHours)
        let sleepDiff = todaySleep - avgStoreSleep
        let trainDays = store.last30.filter { $0.trainingType != nil && $0.trainingType != "Ingen" && $0.trainingType != "" }.count
        let trainAvgMood = trainDays > 0
            ? store.last30.filter { $0.trainingType != nil && $0.trainingType != "Ingen" && $0.trainingType != "" }.map(\.moodQuality).average(default: 0)
            : 0.0
        let didTrain = entry.trainingType != nil && entry.trainingType != "Ingen" && entry.trainingType != ""

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("⭐")
                    .font(.title2)
                Text("Din personliga AHA-insikt")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.warmGold)
            }

            VStack(alignment: .leading, spacing: 8) {
                if abs(sleepDiff) >= 0.5 && avgStoreSleep > 0 {
                    let dir = sleepDiff > 0 ? "mer" : "mindre"
                    let h = String(format: "%.1f", abs(sleepDiff))
                    insightChip("🌙 Idag sov du \(h)h \(dir) än ditt snitt (\(String(format: "%.1f", avgStoreSleep))h)")
                }
                if didTrain && trainDays >= 3 {
                    let pct = Int(trainAvgMood * 100)
                    insightChip("💪 Du tränade idag – ditt mående är i snitt \(pct)/100 på träningsdagar")
                }
                if entry.outdoorMinutes >= 30 {
                    insightChip("🌿 Bra jobbat med utomhustiden idag!")
                }
                if entry.moodQuality >= 0.75 {
                    insightChip("😊 Du mådde riktigt bra idag – vad bidrog till det?")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.warmGold.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.warmGold.opacity(0.4), lineWidth: 1.5)
                )
        )
    }

    private func insightChip(_ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.warmGold)
                .frame(width: 3, height: 30)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 4)
    }

    private func insightRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkle")
                .font(.caption)
                .foregroundStyle(Color.warmLavender)
                .padding(.top, 2)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 4)
    }

    private func adviceRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.warmSage)
                .padding(.top, 2)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Hjälpvyer
    private func stepHeader(emoji: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 44))
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private func logDivider(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: - Status
    private var statusText: String {
        switch loadingProgress {
        case 0: "Sammanställer din dag…"
        case 1: "Analyserar data…"
        case 2: "Skapar insikter…"
        case 3: "Formulerar rekommendationer…"
        default: "Klart!"
        }
    }

    // MARK: - GPT
    private func summariseWithGPT() async {
        mapSelectionsToEntry()
        do {
            let (summary, insights, advice) = try await OpenAIService.summarise(entry: entry)
            gptSummary  = summary
            gptInsights = insights
            gptAdvice   = advice
            entry.summary = summary; entry.insights = insights; entry.advice = advice
            step = 13
        } catch {
            gptSummary = "Sammanfattning kunde inte hämtas."
            step = 13
        }
    }

    private func mapSelectionsToEntry() {
        entry.moodQuality   = scale(["Mycket låg":0.15,"Lite låg":0.35,"Helt okej":0.55,"Bra":0.75,"Fantastiskt":0.92,"Energifylld":0.85,"Okej":0.55,"Neutralt":0.5,"Lågt":0.35,"Svårt":0.2], key: generalMood)
        entry.anxietyLevel  = scale(["Inte alls":0.05,"Lite":0.25,"Mellan":0.5,"Hög":0.7,"Mycket hög":0.85,"Extrem":0.95], key: hadAnxiety)
        entry.sleepQuality  = scale(["Mycket dålig":0.15,"Dålig":0.3,"Orolig":0.45,"Godkänd":0.6,"Bra":0.78,"Utmärkt":0.92], key: sleepState)
        entry.outdoorQuality = scale(["Nej":0.2,"Litegrann":0.5,"Ja":0.8], key: hadSun)
        entry.socialQuality  = scale(["Inga samtal":0.2,"Ett kort samtal":0.4,"Ett par samtal":0.6,"Flera samtal":0.78,"Djupa samtal":0.9,"Småprat":0.5], key: meaningfulSocial)
        entry.routineQuality = scale(["Mycket låg":0.2,"Lite låg":0.4,"Helt okej":0.6,"Bra":0.8,"Fantastiskt":0.92,"Energifylld":0.82], key: generalMood)
        entry.energyLevel    = scale(["Mycket låg":0.2,"Låg":0.4,"Lagom":0.6,"Hög":0.8,"Mycket hög":0.92], key: energySel)

        if sleepHourSel == "11+ h" { entry.sleepHours = 11 }
        else if sleepHourSel == "8 h" { entry.sleepHours = 8 }
        else {
            let cleaned = sleepHourSel.replacingOccurrences(of: " h", with: "")
            let parts = cleaned.split(separator: "-")
            entry.sleepHours = Int(parts.last ?? Substring("0")) ?? 0
        }

        entry.activities = selectedActivities
        entry.socialPeople = socialPeopleSel
        let outsideMap: [String:Int] = ["<10 min":5,"10-30 min":20,"30-60 min":45,"60-90 min":75,"90+ min":95,"2+ tim":120]
        entry.outdoorMinutes = outsideMap[outsideDuration] ?? 0
        entry.trainingType = trained
        entry.mealsCount = { mealsToday == "6+" ? 6 : (Int(mealsToday) ?? 0) }()

        entry.emotions = emotionsSel
        entry.habitsDone = habitsSel
        entry.tags = tagsSel
        entry.notes = notesTxt.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.positives = positivesSel
        entry.negatives = negativesSel
        entry.wished = wishedSel
    }
    private func scale(_ dict: [String:Double], key: String) -> Double { dict[key] ?? 0.5 }
}

// MARK: - Log Card Modifier
extension View {
    func logCard() -> some View {
        self
            .padding(20)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - AI-service (lokal – 100% offline via LillaJagAI)
struct OpenAIService {
    static func summarise(entry: MoodEntry) async throws -> (String, [String], [String]) {
        var parts: [String] = [
            "Mående: \(Int(entry.moodQuality * 100))%",
            "Sömn: \(entry.sleepHours)h (kvalitet \(Int(entry.sleepQuality * 100))%)",
            "Ångest: \(Int(entry.anxietyLevel * 100))%",
            "Energi: \(Int(entry.energyLevel * 100))%",
            "Socialt: \(Int(entry.socialQuality * 100))%"
        ]
        if !entry.emotions.isEmpty { parts.append("Känslor: \(entry.emotions.joined(separator: ", "))") }
        if !entry.activities.isEmpty { parts.append("Aktiviteter: \(entry.activities.joined(separator: ", "))") }
        if entry.outdoorMinutes > 0 { parts.append("Utomhus: \(entry.outdoorMinutes) min") }
        return await LillaJagAIService.shared.analyzeMoodEntry(parts.joined(separator: ". "))
    }

    static func weeklyReport(entries: [MoodEntry], correlations: [MoodStore.MoodCorrelation]) async throws -> String {
        let avgMood = entries.map(\.moodQuality).average(default: 0)
        let summary = "Veckosnitt mående: \(Int(avgMood * 100))% (\(entries.count) dagar loggade)"
        return await LillaJagAIService.shared.weeklyReport(summary: summary)
    }
}

// MARK: - UI-komponenter
struct MoodOptionButton: View {
    let label: String
    let selected: Bool
    var body: some View {
        Text(label)
            .font(.callout.weight(.medium))
            .lineLimit(1).minimumScaleFactor(0.7).allowsTightening(true)
            .padding(.vertical, 12).padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: selected ? [Color.warmLavender.opacity(0.5), Color.warmRose.opacity(0.4)]
                               : [Color.white.opacity(0.07), Color.white.opacity(0.07)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color.warmLavender.opacity(0.5) : Color.clear, lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(selected ? 0.2 : 0.04), radius: selected ? 5 : 2, y: selected ? 2 : 1)
    }
}

struct ButtonGrid: View {
    var single: Bool
    let options: [String]
    @Binding var selection: String
    @Binding var multiSelection: [String]

    init(single: Bool, options: [String], selection: Binding<String>) {
        self.single = single; self.options = options
        _selection = selection; _multiSelection = .constant([])
    }
    init(single: Bool, options: [String], selection: Binding<[String]>) {
        self.single = single; self.options = options
        _selection = .constant(""); _multiSelection = selection
    }

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 220), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options, id: \.self) { opt in
                let isSel = single ? opt == selection : multiSelection.contains(opt)
                MoodOptionButton(label: opt, selected: isSel)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.easeOut(duration: 0.2)) {
                            if single { selection = opt }
                            else {
                                if isSel { multiSelection.removeAll { $0 == opt } }
                                else { multiSelection.append(opt) }
                            }
                        }
                    }
            }
        }
    }
}

struct WrapChips: View {
    let items: [String]
    var body: some View {
        let cols = [GridItem(.adaptive(minimum: 90), spacing: 8)]
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.footnote)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }
}

struct TitleText: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoText: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func glass(corner: CGFloat = 18) -> some View {
        self
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }
}

// Bottenbar med safe area
struct FooterContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        let bottom = UIApplication.safeBottomInset
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: 640)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(Divider().opacity(0.2), alignment: .top)
        .padding(.bottom, max(8, bottom))
    }
}

extension UIApplication {
    static var safeBottomInset: CGFloat {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else { return 0 }
        return window.safeAreaInsets.bottom
    }
}

extension Collection where Element == Double {
    func average(default def: Double) -> Double { isEmpty ? def : reduce(0,+) / Double(count) }
}

extension Calendar {
    func isDate(_ d: Date, inSameDayAsOrAfter start: Date) -> Bool {
        let sd = startOfDay(for: start)
        let dd = startOfDay(for: d)
        return dd >= sd
    }
}

extension MoodStore {
    func last7() -> [MoodEntry] {
        guard let since = Calendar.current.date(byAdding: .day, value: -6, to: .now) else { return [] }
        return entries.filter { $0.date >= since }.sorted { $0.date < $1.date }
    }
}

typealias PrimaryButton = GradientButtonStyle

// MARK: - Preview
#Preview {
    Mood1View()
        .environment(\.colorScheme, .dark)
}
