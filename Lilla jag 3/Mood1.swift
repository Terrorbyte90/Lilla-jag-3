//
//  Mood1.swift
//  LillaJag
//
//  Skapad 24 jul 2025 av ChatGPT (o3)
//  Reviderad 1 sep 2025 – Fix: bottenbarens safe area, vit text i alla sektioner,
//  kortare segmentetiketter, kompaktare KPI & grid, lätt nedskalad logg.
//

import SwiftUI
import Charts
import AVKit
import Foundation

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
}

// MARK: - Bakgrund (konsekvent med resten av appen)
struct AppBackground: View {
    var body: some View {
        WarmBackground()
    }
}

// MARK: - Dashboard
struct Mood1View: View {
    @StateObject private var viewModel = MoodViewModel()
    @StateObject private var store = MoodStore() // Behövs för att skicka till logger och andra vyer om de inte använder VM än

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.cardSpacing(for: geo.size.height)) {
                        heroWelcomeCard
                        kpiRow
                        metricChart
                        calendarSection
                        statsSection
                        insightsSection
                        weeklyAISection
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            viewModel.showLogger = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Logga mående")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.warmGold, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(LJPressableButtonStyle())
                    }
                    .frame(maxWidth: 640)
                    .padding(.vertical, 20)
                    .padding(.horizontal, DesignSystem.Spacing.horizontalPadding(for: geo.size.width))
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showLogger) {
            MoodLogFlowView { newEntry in store.add(newEntry) }
        }
    }

    // MARK: Hero
    private var heroWelcomeCard: some View {
        VStack(spacing: 14) {
            LJIconCircle(icon: "face.smiling.fill", color: .warmSage, size: 56, iconScale: 0.5)
            Text("Välkommen tillbaka")
                .font(DesignSystem.Typography.titleMain)
                .foregroundStyle(.white)
            Text("Redo att logga hur du mår idag? Dina insikter uppdateras direkt.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.showLogger = true
            } label: {
                Text("Börja logga")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.warmGold, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(LJPressableButtonStyle())
        }
        .ljGlassCard()
    }

    private var kpiRow: some View {
        HStack(spacing: 10) {
            kpi("Mående", store.avgMood)
            kpi("Sömn", store.avgSleep)
            kpi("Socialt", store.avgSocial)
            kpi("Energi", store.avgEnergy)
            VStack(alignment: .leading, spacing: 2) {
                Text("Streak").font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7).allowsTightening(true)
                HStack(spacing: 2) {
                    Text("\(store.currentStreak)").font(.headline).monospacedDigit().foregroundStyle(.white)
                    Text("d /").font(.caption2).foregroundStyle(.secondary)
                    Text("\(store.longestStreak)").font(.headline).monospacedDigit().foregroundStyle(.white)
                    Text("d").font(.caption2).foregroundStyle(.secondary)
                }.lineLimit(1).minimumScaleFactor(0.7).allowsTightening(true)
            }
            .padding(8)
            .ljGlassCard(radius: 12)
        }
        .ljGlassCard()
    }
    private func kpi(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.65).allowsTightening(true)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", value * 100)).font(.headline).monospacedDigit().foregroundStyle(.white)
                Text("/100").font(.caption2).foregroundStyle(.secondary)
            }.lineLimit(1).minimumScaleFactor(0.7).allowsTightening(true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ljGlassCard(radius: 12)
    }

    // MARK: Linjediagram
    private var metricChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Kortare etiketter så allt ryms
            Picker("", selection: $viewModel.selectedMetric) {
                ForEach(Metric.allCases) { Text($0.shortLabel).tag($0) }
            }
            .pickerStyle(.segmented)
            .tint(.pink)
            .ljGlassCard()

            Chart(store.last30) { entry in
                LineMark(
                    x: .value("Datum", entry.date, unit: .day),
                    y: .value(viewModel.selectedMetric.label, viewModel.selectedMetric.value(entry))
                )
                PointMark(
                    x: .value("Datum", entry.date, unit: .day),
                    y: .value(viewModel.selectedMetric.label, viewModel.selectedMetric.value(entry))
                )
            }
            .chartYScale(domain: 0...1)
            .frame(height: UIScreen.main.bounds.height > 800 ? 180 : 140)
        }
        .foregroundStyle(.white)
        .ljGlassCard()
    }

    // MARK: AI-insikter
    private var insightsSection: some View {
        if let latest = store.entries.last, !(latest.insights.isEmpty && latest.advice.isEmpty && latest.summary.isEmpty) {
            return AnyView(
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI-sammanfattning").font(.title3.bold())
                    if !latest.summary.isEmpty {
                        Text(latest.summary).foregroundStyle(.white).ljGlassCard()
                    }
                    if !latest.insights.isEmpty {
                        Divider().background(.white.opacity(0.25))
                        Text("Insikter").font(.headline).foregroundStyle(.white)
                        ForEach(latest.insights, id: \.self) { Text("• \($0)").foregroundStyle(.white) }
                    }
                    if !latest.advice.isEmpty {
                        Divider().background(.white.opacity(0.25))
                        Text("Rekommendationer").font(.headline).foregroundStyle(.white)
                        ForEach(latest.advice, id: \.self) { Text("→ \($0)").foregroundStyle(.white) }
                    }
                }
                .ljGlassCard()
            )
        }
        return AnyView(EmptyView())
    }

    // MARK: Kalender
    private var calendarSection: some View {
        VStack(spacing: 8) {
            Text(monthTitle(for: viewModel.calendarMonth))
                .font(.headline).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)
            if viewModel.calendarExpanded {
                CalendarGridView(entries: store.entries, currentMonth: $viewModel.calendarMonth) { tapped in
                    viewModel.popupEntry = tapped
                }
                .frame(maxHeight: 360)
                .padding(.horizontal, 2) // gör plats för pilarna även på smala skärmar
            }
        }
        .onTapGesture { withAnimation { viewModel.calendarExpanded.toggle() } }
        .ljGlassCard()
        .fullScreenCover(item: $viewModel.popupEntry) { entry in SummaryPopup(entry: entry) }
    }

    // MARK: Statistik
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistik").font(.title2.bold()).foregroundStyle(.white)
            if !store.last30.isEmpty {
                let topCounts = Array(store.activityFrequencies().prefix(10))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vanligaste aktiviteter & vanor (30 dagar)").font(.headline).foregroundStyle(.white)
                    Chart(topCounts, id: \.id) { item in
                        BarMark(x: .value("Frekvens", item.count), y: .value("Aktivitet", item.name))
                    }
                    .frame(height: CGFloat(24 * max(4, topCounts.count)))
                }
                .ljGlassCard()
            }
            if !store.last90.isEmpty {
                let corrs = store.correlations()
                let topPos = Array(corrs.filter { $0.delta > 0 }.prefix(5))
                let topNeg = Array(corrs.filter { $0.delta < 0 }.prefix(5))
                VStack(alignment: .leading, spacing: 10) {
                    Text("Korrelationer (90 dagar)").font(.headline).foregroundStyle(.white)
                    if topPos.isEmpty && topNeg.isEmpty {
                        Text("För lite data ännu – logga fler dagar.").foregroundStyle(.secondary)
                    } else {
                        if !topPos.isEmpty {
                            Text("Topp +").font(.subheadline.bold()).foregroundStyle(.white)
                            ForEach(topPos) { c in
                                HStack {
                                    Text(c.name)
                                    Spacer()
                                    Text(String(format: "%+.0f", c.delta * 100)) + Text(" p").foregroundStyle(.secondary)
                                }.foregroundStyle(.white)
                            }
                        }
                        if !topNeg.isEmpty {
                            Divider().background(.white.opacity(0.12))
                            Text("Topp −").font(.subheadline.bold()).foregroundStyle(.white)
                            ForEach(topNeg) { c in
                                HStack {
                                    Text(c.name)
                                    Spacer()
                                    Text(String(format: "%+.0f", c.delta * 100)) + Text(" p").foregroundStyle(.secondary)
                                }.foregroundStyle(.white)
                            }
                        }
                        Text("Δ = skillnad i snittmående när faktor finns vs saknas.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .ljGlassCard()
            }
        }
        .ljGlassCard()
    }

    // MARK: Vecko-AI
    private var weeklyAISection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI-Veckorapport").font(.title3.bold()).foregroundStyle(.white)
            if !viewModel.weeklyReportText.isEmpty {
                Text(viewModel.weeklyReportText).foregroundStyle(.white).ljGlassCard()
            }
            HStack {
                if viewModel.generatingWeekly { ProgressView().progressViewStyle(.circular) }
                Button("Generera veckorapport") {
                    Task {
                        await viewModel.generateWeeklyReport()
                    }
                }
                .buttonStyle(GradientButtonStyle())
            }
        }
        .ljGlassCard()
    }

    private func monthTitle(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "LLLL yyyy"
        return df.string(from: date).capitalized(with: df.locale)
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
    /// Kortare etiketter för segmentkontrollen
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

// MARK: - Kalender-grid
struct CalendarGridView: View {
    let entries: [MoodEntry]
    @Binding var currentMonth: Date
    let onTap: (MoodEntry) -> Void

    private var monthCells: [Date?] {
        var cells: [Date?] = []
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: currentMonth) else { return cells }
        let first = interval.start
        let weekdayOfFirst = (cal.component(.weekday, from: first) + 6) % 7  // måndag=0
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

// MARK: - Humörlogg
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
    // new fields
    @State private var energySel = ""
    @State private var emotionsSel: [String] = []
    @State private var habitsSel: [String] = []
    @State private var tagsSel: [String] = []
    @State private var notesTxt: String = ""
    // loading / GPT
    @State private var loadingProgress = 0
    @State private var gptSummary = ""
    @State private var gptInsights: [String] = []
    @State private var gptAdvice  : [String] = []
    private let habitCandidates = ["7+ timmar sömn","30+ min utomhus","10+ min meditation","Träning","Grönsaker till 2 måltider"]

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 20) {
                    switch step {
                    case 0: generalStep
                    case 1: sleepStep
                    case 2: dayStep
                    case 3: socialStep
                    case 4: outdoorStep
                    case 5: trainingStep
                    case 6: foodStep
                    case 7: energyStep
                    case 8: emotionsStep
                    case 9: habitsStep
                    case 10: tagsStep
                    case 11: notesStep
                    case 12: loadingStep
                    case 13: summaryStep
                    case 14: recommendationsStep
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: 620)
                .padding(.vertical, 22)
                .padding(.horizontal, 18)
                .scaleEffect(0.96) // kompakt så allt ryms
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding([.horizontal], 16)
            .animation(.easeInOut, value: step)
        }
        // Bottenbar som alltid lämnar plats för home-indikatorn
        .safeAreaInset(edge: .bottom) {
            FooterContainer {
                HStack {
                    if step > 0 && step < 12 {
                        Button("Bakåt") { step -= 1 }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    if step < 11 {
                        Button("Nästa") { step += 1 }
                            .buttonStyle(GradientButtonStyle())
                            .frame(maxWidth: 220)
                    } else if step == 11 {
                        Button("Sammanfatta") { step = 12 }
                            .buttonStyle(GradientButtonStyle())
                            .frame(maxWidth: 260)
                    }
                }
            }
        }
    }

    // MARK: Steg
    private var generalStep: some View {
        VStack(spacing: 16) {
            TitleText("Hur har du mått idag?")
            ButtonGrid(single: true,
                       options: ["Fantastiskt","Bra","Helt okej","Lite låg","Mycket låg","Energifylld"],
                       selection: $generalMood)

            Divider().background(.white.opacity(0.2))

            TitleText("Har du haft ångest idag?")
            ButtonGrid(single: true,
                       options: ["Inte alls","Lite","Mellan","Hög","Mycket hög","Extrem"],
                       selection: $hadAnxiety)

            TitleText("Andra negativa känslor?")
            ButtonGrid(single: true,
                       options: ["Inga","Oro","Ilska","Sorg","Besvikelse","Stress"],
                       selection: $negativeFeel)

            InfoText("Det är normalt att uppleva olika känslor under olika dagar – du är bara människa. Kämpa på!")
        }
    }

    private var sleepStep: some View {
        VStack(spacing: 16) {
            TitleText("Hur många timmar sov du?")
            ButtonGrid(single: true,
                       options: ["0-3 h","4-5 h","6-7 h","8 h","9-10 h","11+ h"],
                       selection: $sleepHourSel)

            TitleText("Kvalitet på nattsömn")
            ButtonGrid(single: true,
                       options: ["Utmärkt","Bra","Godkänd","Orolig","Dålig","Mycket dålig"],
                       selection: $sleepState)

            InfoText("Tillräcklig sömn förbättrar minne, immunförsvar och humör.")
        }
    }

    private var dayStep: some View {
        VStack(spacing: 16) {
            TitleText("Vad har du gjort idag?")
            ButtonGrid(single: false,
                       options: ["Jobbat","Studerat","Tränat","Läst","Skapat","Umgåtts familj","Spelat","Tagit det lugnt","Städat","Handlat","Promenerat","Meditation","Lagat mat","Sett film","Volontärarbete"],
                       selection: $selectedActivities)
            InfoText("Mening + framsteg → bättre välmående.")
        }
    }

    private var socialStep: some View {
        VStack(spacing: 16) {
            TitleText("Meningsfulla sociala samtal?")
            ButtonGrid(single: true,
                       options: ["Flera samtal","Ett par samtal","Ett kort samtal","Inga samtal","Djupa samtal","Småprat"],
                       selection: $meaningfulSocial)
            TitleText("Vilka har du pratat med?")
            ButtonGrid(single: false,
                       options: ["Familj","Partner","Barn","Vänner","Kollegor","Nya bekanta","Grannar","Online-vänner","Husdjur"],
                       selection: $socialPeopleSel)
        }
    }

    private var outdoorStep: some View {
        VStack(spacing: 16) {
            TitleText("Har du varit utomhus idag?")
            ButtonGrid(single: true, options: ["Ja","Nej"], selection: $beenOutside)
            TitleText("Hur länge?")
            ButtonGrid(single: true,
                       options: ["<10 min","10-30 min","30-60 min","60-90 min","90+ min","2+ tim"],
                       selection: $outsideDuration)
            TitleText("Solljus på huden?")
            ButtonGrid(single: true, options: ["Ja","Litegrann","Nej"], selection: $hadSun)
        }
    }

    private var trainingStep: some View {
        VStack(spacing: 16) {
            TitleText("Har du tränat idag?")
            ButtonGrid(single: true,
                       options: ["Ingen","Stretching","Lätt","Mellan","Hård","Återhämtning"],
                       selection: $trained)
            TitleText("Hur kändes träningen?")
            ButtonGrid(single: true,
                       options: ["Energigivande","Kul","Neutralt","Utmanande","Tungt","Lättsamt"],
                       selection: $trainingFeel)
        }
    }

    private var foodStep: some View {
        VStack(spacing: 16) {
            TitleText("Hur bra upplevde du dagens mat?")
            ButtonGrid(single: true,
                       options: ["Utmärkt","Mycket bra","Bra","Okej","Behövde förbättras","Dålig"],
                       selection: $ateToday)
            TitleText("Hur många måltider?")
            ButtonGrid(single: true, options: ["1","2","3","4","5","6+"], selection: $mealsToday)
        }
    }

    private var energyStep: some View {
        VStack(spacing: 16) {
            TitleText("Hur var din energi idag?")
            ButtonGrid(single: true, options: ["Mycket låg","Låg","Lagom","Hög","Mycket hög"], selection: $energySel)
        }
    }

    private var emotionsStep: some View {
        VStack(spacing: 16) {
            TitleText("Vilka känslor kände du idag?")
            ButtonGrid(single: false,
                       options: ["Glad","Tacksam","Lugn","Fokuserad","Motiverad","Stressad","Orolig","Arg","Ledsen","Trött","Överväldigad","Hoppfull"],
                       selection: $emotionsSel)
        }
    }

    private var habitsStep: some View {
        VStack(spacing: 16) {
            TitleText("Vanor du klarade idag?")
            ButtonGrid(single: false, options: habitCandidates, selection: $habitsSel)
        }
    }

    private var tagsStep: some View {
        VStack(spacing: 16) {
            TitleText("Taggar (välj det som passar)")
            ButtonGrid(single: false,
                       options: ["Rutiner","Fokus","Återhämtning","Relationer","Kreativitet","Jobb","Hälsa","Ekonomi"],
                       selection: $tagsSel)
        }
    }

    private var notesStep: some View {
        VStack(spacing: 8) {
            TitleText("Anteckning (valfritt)")
            TextEditor(text: $notesTxt)
                .frame(minHeight: 120)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 0.5))
                .foregroundStyle(.white)
            InfoText("Skriv några rader om något viktigt från dagen (valfritt).")
        }
    }

    private var loadingStep: some View {
        VStack(spacing: 20) {
            ProgressView().progressViewStyle(.circular).scaleEffect(2)
            Text(statusText).foregroundStyle(.white).font(.headline)
        }
        .onAppear {
            Task {
                for i in 1...4 { try await Task.sleep(nanoseconds: 800_000_000); loadingProgress = i }
                await summariseWithGPT()
            }
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            TitleText("Sammanfattning av din dag")
            Text(gptSummary).multilineTextAlignment(.leading).foregroundStyle(.white).glass()
            if let url = Bundle.main.url(forResource: "bipolar", withExtension: "mp4") {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.bottom, 12)
            }
            Button("Gå vidare") { step = 14 }.buttonStyle(GradientButtonStyle())
        }
    }

    private var recommendationsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            TitleText("Insikter")
            ForEach(gptInsights, id: \.self) { Text("• \($0)").foregroundStyle(.white) }
            Divider().background(.white.opacity(0.25))
            TitleText("Rekommendationer")
            ForEach(gptAdvice, id: \.self) { Text("→ \($0)").foregroundStyle(.white) }
            Spacer()
            Button("Spara & stäng") { onSave(entry); dismiss() }
                .buttonStyle(GradientButtonStyle())
        }
        .glass()
        .foregroundStyle(.white)
    }

    // Status-text
    private var statusText: String {
        switch loadingProgress {
        case 0: "Sammanställer din dag…"
        case 1: "Analyserar data…"
        case 2: "Skapar insikter…"
        case 3: "Formulerar rekommendationer…"
        default: "Klart!"
        }
    }

    // GPT-anrop
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
        entry.moodQuality   = scale(["Mycket låg":0.15,"Lite låg":0.35,"Helt okej":0.55,"Bra":0.75,"Fantastiskt":0.92,"Energifylld":0.85], key: generalMood)
        entry.anxietyLevel  = scale(["Inte alls":0.05,"Lite":0.25,"Mellan":0.5,"Hög":0.7,"Mycket hög":0.85,"Extrem":0.95], key: hadAnxiety)
        entry.sleepQuality   = scale(["Mycket dålig":0.15,"Dålig":0.3,"Orolig":0.45,"Godkänd":0.6,"Bra":0.78,"Utmärkt":0.92], key: sleepState)
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
    private func scale(_ dict:[String:Double], key:String)->Double { dict[key] ?? 0.5 }
}

// MARK: - AI-service (lokal – 100% offline via LillaJagAI)
struct OpenAIService {
    /// Analyserar en moodEntry och returnerar (sammanfattning, insikter, råd)
    /// via den lokala KBT-motorn – ingen nätverkstrafik.
    static func summarise(entry: MoodEntry) async throws -> (String, [String], [String]) {
        let description = "Mående: \(Int(entry.moodQuality * 100))%, Sömn: \(entry.sleepHours)h, Ångest: \(Int(entry.anxietyLevel * 100))%"
        return await LillaJagAIService.shared.analyzeMoodEntry(description)
    }

    /// Vecklig rapport – delegerar till LillaJagAIService
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
                LinearGradient(colors: selected ? [.pink, .purple]
                               : [Color.white.opacity(0.08),
                                  Color.white.opacity(0.08)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(selected ? 0.25 : 0.05), radius: selected ? 6 : 2, y: selected ? 3 : 1)
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
            .foregroundStyle(.white.opacity(0.8))
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

// En kapsel för bottenbaren som tar höjd för home-indikatorn även på äldre iOS
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

// Hjälp: senaste 7 dagar
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
