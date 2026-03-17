// NotificationManager.swift
// Lilla Jag – Push-notiser & påminnelseinställningar

import SwiftUI
import UIKit
import UserNotifications

// MARK: - NotificationManager

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published var isPermissionGranted: Bool = false

    private let notificationIdentifier = "se.lillaJag.dailyMoodReminder"

    private let reminderMessages: [String] = [
        "Hur mår du idag? Ta en minut att reflektera – du förtjänar det. 💛",
        "Dags för din dagliga incheckning! Logga ditt mående och håll streaket vid liv. 🌿",
        "En liten stund för dig själv. Hur känns det i kroppen och sinnet just nu?",
        "Påminnelse: Att sätta ord på känslor är ett steg mot välmående. Öppna Lilla Jag! 🌸",
        "Du har klarat dagen – hur gick den? Logga ditt mående innan du somnar. ✨"
    ]

    private init() {
        Task {
            await refreshPermissionStatus()
        }
    }

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isPermissionGranted = granted
        } catch {
            isPermissionGranted = false
        }
    }

    func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isPermissionGranted = settings.authorizationStatus == .authorized
    }

    // MARK: - Scheduling

    /// Schemalägger en daglig påminnelse vid angiven timme och minut (24-timmarsformat).
    /// Standardvärde: 20:00 (kväll).
    func scheduleDailyReminder(hour: Int = 20, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()

        // Ta bort eventuell befintlig påminnelse
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        // Välj ett meddelande baserat på aktuell veckodag för variation
        let weekday = Calendar.current.component(.weekday, from: Date())
        let messageIndex = (weekday - 1) % reminderMessages.count
        let messageBody = reminderMessages[messageIndex]

        let content = UNMutableNotificationContent()
        content.title = "Lilla Jag"
        content.body = messageBody
        content.sound = .default
        content.badge = 1

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[NotificationManager] Fel vid schemaläggning: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cancel

    func cancelAllReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    // MARK: - Pending check

    func hasPendingReminder() async -> Bool {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.contains { $0.identifier == notificationIdentifier }
    }
}

// MARK: - NotificationSettingsView

struct NotificationSettingsView: View {

    @StateObject private var manager = NotificationManager.shared
    @State private var remindersEnabled: Bool = false
    @State private var selectedTime: Date = defaultReminderTime()
    @State private var isLoading: Bool = true

    private static func defaultReminderTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 20
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        ZStack {
            // Bakgrund
            LinearGradient(
                colors: [Color(hex: 0x1A1025), Color(hex: 0x221535)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    permissionSection
                    if manager.isPermissionGranted {
                        reminderToggleSection
                        if remindersEnabled {
                            timePickerSection
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Påminnelser")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCurrentState()
        }
        .onChange(of: selectedTime) { _, _ in
            if remindersEnabled {
                applyReminder()
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.warmGold.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.warmGold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dagliga påminnelser")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Håll din streak vid liv")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.warmGold.opacity(0.2), lineWidth: 1)
        )
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Notistillstånd", systemImage: "lock.shield")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 10) {
                Circle()
                    .fill(manager.isPermissionGranted ? Color.warmSage : Color.warmCoral)
                    .frame(width: 10, height: 10)
                Text(manager.isPermissionGranted ? "Tillåtna" : "Ej tillåtna")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                if !manager.isPermissionGranted {
                    Button(action: openSystemSettings) {
                        Text("Öppna Inställningar")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.warmLavender)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.warmLavender.opacity(0.15), in: Capsule())
                    }
                }
            }

            if !manager.isPermissionGranted {
                Text("För att få påminnelser behöver Lilla Jag tillåtelse att skicka notiser. Gå till Inställningar och aktivera notiser för appen.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: requestPermission) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Begär tillåtelse")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.warmGold, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var reminderToggleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $remindersEnabled) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.warmLavender.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: remindersEnabled ? "bell.fill" : "bell.slash")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.warmLavender)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aktivera påminnelse")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(remindersEnabled ? "Varje dag vid vald tid" : "Inaktiverad")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .tint(Color.warmLavender)
            .onChange(of: remindersEnabled) { _, enabled in
                if enabled {
                    applyReminder()
                } else {
                    manager.cancelAllReminders()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var timePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Välj tid", systemImage: "clock")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            DatePicker(
                "Påminnelsetid",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .colorScheme(.dark)
            .tint(Color.warmGold)
            .frame(maxWidth: .infinity)

            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Color.warmGold.opacity(0.8))
                Text("Du får en påminnelse varje dag vid denna tid.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Helpers

    private func loadCurrentState() async {
        await manager.refreshPermissionStatus()
        let hasPending = await manager.hasPendingReminder()
        remindersEnabled = hasPending
        isLoading = false
    }

    private func requestPermission() {
        Task {
            await manager.requestPermission()
            if manager.isPermissionGranted && remindersEnabled {
                applyReminder()
            }
        }
    }

    private func applyReminder() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)
        manager.scheduleDailyReminder(hour: hour, minute: minute)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
