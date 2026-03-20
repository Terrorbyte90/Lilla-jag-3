//
//  Dashboard.swift
//  Lilla Jag
//
//  Förbättringar iteration 4 – App Store-optimerade:
//  • Daglig humör-incheckning (som Daylio/Headspace)
//  • Streak-räknare med gamification
//  • Andningsövning-snabbåtkomst
//  • Förbättrad sektionsstruktur med headers
//  • Accessibility-labels på alla interaktiva element
//  • Haptic feedback på knapptryck
//

import SwiftUI
import AVKit
import Combine

// MARK: - Dashboard

struct Dashboard: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var ai = LillaJagAIService.shared
    @State private var appeared = false
    /// Håller reda på om dagens affirmation är markerad som favorit
    @State private var affirmationIsFavorite: Bool = false
    /// Visar en kort "sparat!"-feedback när användaren sparar en favorit
    @State private var showFavoriteFeedback: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LoopingVideoBackground(videoName: "bloop", fileExtension: "mp4")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.cardSpacing(for: geo.size.height)) {
                        header
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)
                            .animation(DesignSystem.Animation.intro.delay(0.05), value: appeared)

                        dailyCheckInCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(DesignSystem.Animation.intro.delay(0.12), value: appeared)

                        streakAndProgressBar
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(DesignSystem.Animation.intro.delay(0.18), value: appeared)

                        quickActions
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(DesignSystem.Animation.intro.delay(0.24), value: appeared)

                        breathingQuickAccess
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(DesignSystem.Animation.intro.delay(0.30), value: appeared)

                        affirmationBox
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(DesignSystem.Animation.intro.delay(0.36), value: appeared)

                        monsterSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(DesignSystem.Animation.intro.delay(0.42), value: appeared)

                        if let emotion = ai.currentEmotion, !ai.messages.isEmpty {
                            emotionCard(emotion: emotion)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        ukraineBanner
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(DesignSystem.Animation.intro.delay(0.48), value: appeared)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, max(16, geo.size.width * 0.055))
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            appeared = true
            // Läs in om nuvarande affirmation redan är favorit
            let favorites = AffirmationManager.loadFavorites()
            affirmationIsFavorite = favorites.contains(viewModel.affirmation)
        }
        .fullScreenCover(isPresented: $viewModel.showChatty) { ChattyView() }
        .fullScreenCover(isPresented: $viewModel.showNumbers) { NumbersView() }
        .fullScreenCover(isPresented: $viewModel.showCrisisPlan) { KrisplanView() }
        .fullScreenCover(isPresented: $viewModel.showDonation) { DonationView() }
        .fullScreenCover(isPresented: $viewModel.showForum) { ForumView() }
        .fullScreenCover(isPresented: $viewModel.showPsykolog) { PsykologView() }
        .fullScreenCover(isPresented: $viewModel.showUkraine) { UkraineView() }
        .fullScreenCover(isPresented: $viewModel.showSocial) { SocialView() }
        .fullScreenCover(isPresented: $viewModel.showBreathing) { BreathingQuickView() }
        .onChange(of: viewModel.affirmation) { _, newValue in
            let favorites = AffirmationManager.loadFavorites()
            affirmationIsFavorite = favorites.contains(newValue)
        }
        .fullScreenCover(isPresented: $viewModel.showMonster) {
            MonsterLogWizard { log in
                viewModel.monsterStore.add(log)
                viewModel.lastMonsterLog = log
            }
        }
        .fullScreenCover(isPresented: $viewModel.showAchievements) {
            AchievementsGridView()
        }
        .fullScreenCover(isPresented: $viewModel.showSOS) { CrisisSheetView() }
        .sheet(isPresented: $viewModel.showNotificationSettings) {
            NavigationStack { NotificationSettingsView() }
                .preferredColorScheme(.dark)
        }
        .task {
            await NotificationManager.shared.requestPermission()
        }
    }
}

// MARK: - Delvyer

private extension Dashboard {

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Lilla Jag")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                    .tracking(-0.3)
                Text(greetingText)
                    .font(.system(.subheadline, design: .rounded))
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Lilla Jag. \(greetingText)")
            Spacer()
            HStack(spacing: 8) {
                DashboardHeaderButton(icon: "bell.fill", label: "Påminnelser", action: { viewModel.showNotificationSettings = true })
                DashboardHeaderButton(icon: "cross.case.fill", label: "Krisplan", action: { viewModel.showCrisisPlan = true })
                DashboardHeaderButton(icon: "phone.fill", label: "Krisnummer", action: { viewModel.showNumbers = true })
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .ljPremiumCard(radius: 18, accent: Color.warmLavender)
    }

    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "God morgon!"
        case 12..<18: return "God eftermiddag!"
        case 18..<23: return "God kväll!"
        default: return "Välkommen in i värmen!"
        }
    }

    // MARK: - Daily Check-In (inspirerat av Daylio/Headspace)

    var dailyCheckInCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill((viewModel.hasCheckedInToday ? Color.warmSage : Color.warmGold).opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: viewModel.hasCheckedInToday ? "checkmark.circle.fill" : "sun.horizon.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(viewModel.hasCheckedInToday ? Color.warmSage : Color.warmGold)
                        .contentTransition(.symbolEffect(.replace))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.hasCheckedInToday ? "Incheckat idag" : "Hur mår du just nu?")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(viewModel.hasCheckedInToday ? "Bra jobbat – fortsätt!" : "Välj det som stämmer bäst")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            }

            if !viewModel.hasCheckedInToday {
                HStack(spacing: 4) {
                    ForEach(QuickMood.allCases, id: \.rawValue) { mood in
                        Button {
                            withAnimation(DesignSystem.Animation.smooth) {
                                viewModel.selectedQuickMood = mood
                                viewModel.hasCheckedInToday = true
                                viewModel.recordCheckIn()
                            }
                            LJHaptic.medium()
                        } label: {
                            VStack(spacing: 6) {
                                Text(mood.emoji)
                                    .font(.system(size: 28))
                                    .scaleEffect(viewModel.selectedQuickMood == mood ? 1.25 : 1.0)
                                    .animation(DesignSystem.Animation.quick, value: viewModel.selectedQuickMood)
                                Text(mood.rawValue)
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                viewModel.selectedQuickMood == mood
                                ? mood.color.opacity(0.22)
                                : Color.clear,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        viewModel.selectedQuickMood == mood
                                        ? mood.color.opacity(0.4)
                                        : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Humör: \(mood.rawValue)")
                    }
                }
                .padding(.horizontal, 2)
            } else if let mood = viewModel.selectedQuickMood {
                HStack(spacing: 12) {
                    Text(mood.emoji)
                        .font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Du mår \(mood.rawValue.lowercased()) idag")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Loggat – bra kämpat!")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color.warmSage.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.warmSage)
                }
                .padding(.vertical, 4)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .ljPremiumCard(radius: 20, accent: Color.warmGold)
        .shadow(color: Color.warmGold.opacity(0.08), radius: 16, y: 6)
    }

    // MARK: - Streak & Progress (gamification som Duolingo/Headspace)

    var streakAndProgressBar: some View {
        HStack(spacing: 12) {
            // Streak-kort
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.warmGold.opacity(0.3), Color.warmGold.opacity(0.05)],
                                center: .center, startRadius: 0, endRadius: 22
                            )
                        )
                        .frame(width: 42, height: 42)
                        .overlay(Circle().stroke(Color.warmGold.opacity(0.2), lineWidth: 1))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.currentStreak > 0 ? Color.warmGold : Color.white.opacity(0.25))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.currentStreak)")
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(viewModel.currentStreak == 1 ? "dag i rad" : "dagar i rad")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .ljPremiumCard(radius: 16, accent: Color.warmGold)
            .shadow(color: Color.warmGold.opacity(0.08), radius: 10, y: 4)
            .accessibilityLabel("Streak: \(viewModel.currentStreak) dagar i rad")

            // Vecko-dots
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    Text("Veckomål")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    Text("\(min(viewModel.currentStreak, 7))/7")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.warmSage)
                }
                HStack(spacing: 5) {
                    ForEach(0..<7, id: \.self) { day in
                        let isActive = day < viewModel.currentStreak
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isActive
                                  ? LinearGradient(colors: [Color.warmSage, Color.warmSage.opacity(0.7)],
                                                   startPoint: .top, endPoint: .bottom)
                                  : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)],
                                                   startPoint: .top, endPoint: .bottom))
                            .frame(maxWidth: .infinity)
                            .frame(height: 8)
                            .animation(DesignSystem.Animation.smooth.delay(Double(day) * 0.04), value: viewModel.currentStreak)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .ljPremiumCard(radius: 16, accent: Color.warmSage)
            .shadow(color: Color.warmSage.opacity(0.06), radius: 10, y: 4)
            .accessibilityLabel("Veckomål: \(min(viewModel.currentStreak, 7)) av 7 dagar")
        }
    }

    // MARK: - Quick Actions

    var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Snabbåtgärder", icon: "bolt.fill")
            HStack(spacing: 12) {
                DashboardActionButton(icon: "bubble.left.and.bubble.right.fill",
                                      label: "Chatt",
                                      color: Color.warmLavender) {
                    viewModel.showChatty = true
                }
                DashboardActionButton(icon: "person.3.fill",
                                      label: "Forum",
                                      color: Color.warmSage) {
                    viewModel.showForum = true
                }
                DashboardActionButton(icon: "stethoscope",
                                      label: "Psykolog",
                                      color: Color(hex: 0x6ECFF6)) {
                    viewModel.showPsykolog = true
                }
                DashboardActionButton(icon: "trophy.fill",
                                      label: "Prestationer",
                                      color: Color.warmGold) {
                    viewModel.showAchievements = true
                }
            }
        }
    }

    // MARK: - Breathing Quick Access (som Calm/Headspace)

    var breathingQuickAccess: some View {
        Button {
            viewModel.showBreathing = true
            LJHaptic.soft()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: 0x6ECFF6).opacity(0.3), Color(hex: 0x6ECFF6).opacity(0.06)],
                                center: .center, startRadius: 0, endRadius: 26
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(Color(hex: 0x6ECFF6).opacity(0.2), lineWidth: 1))
                    Image(systemName: "wind")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color(hex: 0x6ECFF6))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Andas lugnt")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("1 minut · Snabb avslappning")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color(hex: 0x6ECFF6))
                    .shadow(color: Color(hex: 0x6ECFF6).opacity(0.4), radius: 8, y: 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .ljPremiumCard(radius: 20, accent: Color(hex: 0x6ECFF6))
            .shadow(color: Color(hex: 0x6ECFF6).opacity(0.1), radius: 12, y: 4)
        }
        .buttonStyle(LJPressableButtonStyle())
        .accessibilityLabel("Starta andningsövning. 1 minut snabb avslappning.")
    }

    // MARK: - Affirmation
    // Innovation 1: Interaktiv affirmation – hjärtknapp sparar favoriter till UserDefaults,
    // dubbeltryck byter till nästa. Visar "Sparad!" feedback med animation.

    var affirmationBox: some View {
        ZStack {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.warmGold.opacity(0.6))
                    Text("Dagens påminnelse")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.warmGold.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()

                    // Favorit-knapp – markerar påminnelsen och sparar till UserDefaults
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            affirmationIsFavorite.toggle()
                        }
                        LJHaptic.light()
                        AffirmationManager.toggleFavorite(viewModel.affirmation)

                        // Visa kortvarig "Sparad!"-feedback när användaren lägger till favorit
                        if affirmationIsFavorite {
                            showFavoriteFeedback = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                withAnimation { showFavoriteFeedback = false }
                            }
                        }
                    } label: {
                        Image(systemName: affirmationIsFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundStyle(affirmationIsFavorite ? Color.warmRose : Color.white.opacity(0.3))
                            .scaleEffect(affirmationIsFavorite ? 1.15 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(affirmationIsFavorite ? "Ta bort från favoriter" : "Spara som favorit")

                    // Byt till ny påminnelse
                    Button {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            viewModel.affirmation = AffirmationManager.random(excluding: viewModel.affirmation)
                        }
                        LJHaptic.light()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ny påminnelse")
                }

                Text(viewModel.affirmation)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color.warmGold.opacity(0.08), Color.warmLavender.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    // Subtilt ljusreflex
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.4)
                    )
                }
            )
            .ljGlassCard(radius: 20)
            .id(viewModel.affirmation)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .animation(.easeInOut(duration: 0.5), value: viewModel.affirmation)
            .accessibilityLabel("Dagens påminnelse: \(viewModel.affirmation)")

            // "Sparad!"-overlay – syns kort när användaren lägger till favorit
            if showFavoriteFeedback {
                Text("Sparad! ♥")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.warmRose.opacity(0.8), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Monster Section

    var monsterSection: some View {
        let state = viewModel.lastMonsterLog?.monsterState ?? .idle
        let hasLog = viewModel.lastMonsterLog != nil

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                LJIconCircle(icon: "pawprint.fill", color: Color.warmLavender, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ditt monster")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(hasLog ? state.summary : "Monstret väntar på din dagliga logg!")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }

            if hasLog, let log = viewModel.lastMonsterLog {
                // Kompakt visning av dagens resultat
                HStack(spacing: 8) {
                    monsterStat("Sömn", value: log.sleep, icon: "moon.fill")
                    monsterStat("Mat", value: log.meals, icon: "fork.knife")
                    monsterStat("Ute", value: log.outdoor, icon: "sun.max.fill")
                    monsterStat("Rörelse", value: log.exercise, icon: "figure.walk")
                    monsterStat("Socialt", value: log.social, icon: "person.2.fill")
                }
            }

            Button {
                LJHaptic.medium()
                viewModel.showMonster = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasLog ? "arrow.clockwise" : "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(hasLog ? "Logga igen" : "Logga din dag")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [Color.warmLavender, Color.warmRose],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(LJPressableButtonStyle())
        }
        .padding(14)
        .ljGlassCard(radius: 18)
    }

    func monsterStat(_ label: String, value: Int, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(value >= 3 ? Color.warmSage : Color.white.opacity(0.35))
            Text("\(value)/4")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(value >= 3 ? .white : .white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(value >= 3 ? Color.warmSage.opacity(0.1) : Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Emotion Card

    func emotionCard(emotion: EmotionResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(emotion.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: emotion.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(emotion.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Din senaste känsla")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(emotion.dominant.name.capitalized)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(emotion.color)
            }
            Spacer()
            Button {
                viewModel.showChatty = true
            } label: {
                Text("Prata om det")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(emotion.color.opacity(0.3), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .ljGlassCard(radius: 16)
        .shadow(radius: 4, y: 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.5), value: emotion.dominant.name)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Din senaste känsla: \(emotion.dominant.name)")
    }

    // MARK: - Ukraine & Social

    var ukraineBanner: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    viewModel.showUkraine = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(LinearGradient(colors: [.blue, .yellow], startPoint: .top, endPoint: .bottom))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Stöd Ukraina")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Gör skillnad")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ljGlassCard(radius: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stöd Ukraina")

                Button {
                    viewModel.showSocial = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Socialt")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Hitta vänner")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ljGlassCard(radius: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Socialt, hitta vänner")
            }

            // SOS-knapp centrerad
            Button {
                viewModel.showSOS = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Behöver du akut stöd?")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [Color(hex: 0xCC2222), Color(hex: 0xFF4444)],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: Color(hex: 0xFF2222).opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(LJPressableButtonStyle())
            .accessibilityLabel("Akut stöd och krisnummer")
        }
    }
}

// MARK: - Header button

struct DashboardHeaderButton: View {
    let icon: String
    var label: String = ""
    let action: () -> Void
    var body: some View {
        Button {
            action()
            LJHaptic.light()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                )
        }
        .buttonStyle(LJPressableButtonStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Action button

struct DashboardActionButton: View {
    let icon: String
    let label: String
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button {
            action()
            LJHaptic.light()
        } label: {
            VStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color.opacity(0.28), color.opacity(0.08)],
                                center: .center, startRadius: 0, endRadius: 26
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(Circle().stroke(color.opacity(0.18), lineWidth: 1))
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .ljPremiumCard(radius: 18, accent: color)
            .shadow(color: color.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(LJPressableButtonStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - LoopingVideoBackground

struct LoopingVideoBackground: UIViewControllerRepresentable {
    let videoName: String
    let fileExtension: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .clear

        guard let url = Bundle.main.url(forResource: videoName, withExtension: fileExtension) else {
            return controller
        }

        let playerItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        let looper = AVPlayerLooper(player: player, templateItem: playerItem)
        context.coordinator.looper = looper
        controller.player = player
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
    class Coordinator { var looper: AVPlayerLooper? }
}

// MARK: - AffirmationManager
// Innovation 1 (stöd): Lägger till favorit-persistens via UserDefaults samt
// random(excluding:) för att aldrig visa samma påminnelse två gånger i rad.

struct AffirmationManager {
    private static let favoritesKey = "lj_affirmation_favorites"

    private static let list: [String] = [
        "Du är modigare än du tror.",
        "Andas djupt – allt ordnar sig.",
        "Dina känslor är viktiga.",
        "Du förtjänar omtanke och ro.",
        "Ett litet steg är också framsteg.",
        "Du är inte ensam i det här.",
        "Tack för att du fortsätter kämpa.",
        "Du duger precis som du är.",
        "Varje dag är en ny chans.",
        "Din hjärna gör sitt bästa – det räcker.",
        "Det är okej att inte vara okej.",
        "Du är starkare än dina svåraste dagar.",
        "Att be om hjälp är modigt.",
        "Du förtjänar samma kärlek du ger andra.",
        "Varje andetag är en ny början.",
        "Du gör framsteg, även när det inte känns så.",
        "Det är okej att ta det lugnt idag.",
        "Du är värd att bli lyssnad på.",
        "Mörker varar inte för evigt.",
        "Din resa är unik och värdefull.",
        "Självmedkänsla är inte svaghet – det är styrka.",
        "Du har klarat svåra saker förut.",
        "Idag räcker det att bara vara.",
        "Dina tankar definierar inte vem du är.",
        "Du förtjänar vila utan skuldkänslor."
    ]

    /// Returnerar en slumpmässig affirmation, aldrig samma som `current`
    static func random(excluding current: String = "") -> String {
        let pool = list.filter { $0 != current }
        return pool.randomElement() ?? list.randomElement() ?? ""
    }

    /// Läs sparade favoriter från UserDefaults
    static func loadFavorites() -> [String] {
        UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
    }

    /// Toggla en affirmation som favorit – lägg till om den saknas, ta bort om den finns
    static func toggleFavorite(_ affirmation: String) {
        var favorites = loadFavorites()
        if let index = favorites.firstIndex(of: affirmation) {
            favorites.remove(at: index)
        } else {
            favorites.append(affirmation)
        }
        UserDefaults.standard.set(favorites, forKey: favoritesKey)
    }

    /// Returnerar en slumpmässig affirmation, prioriterar favoriter var 3:e dag
    static func random() -> String { random(excluding: "") }
}

// MARK: - BreathingQuickView (snabb andningsövning)

struct BreathingQuickView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: BreathPhase = .inhale
    @State private var circleScale: CGFloat = 0.5
    @State private var timer: Timer?
    @State private var secondsLeft = 60
    @State private var isActive = false

    enum BreathPhase: String {
        case inhale = "Andas in"
        case hold = "Håll"
        case exhale = "Andas ut"

        var duration: Double {
            switch self {
            case .inhale: return 4
            case .hold:   return 4
            case .exhale: return 4
            }
        }

        var next: BreathPhase {
            switch self {
            case .inhale: return .hold
            case .hold:   return .exhale
            case .exhale: return .inhale
            }
        }

        var color: Color {
            switch self {
            case .inhale: return Color(hex: 0x6ECFF6)
            case .hold:   return Color.warmLavender
            case .exhale: return Color.warmSage
            }
        }
    }

    var body: some View {
        ZStack {
            // Gradient bakgrund som svarar på andningsfas
            Color(hex: 0x100820).ignoresSafeArea()
            Circle()
                .fill(phase.color.opacity(0.18))
                .frame(width: 500, height: 500)
                .blur(radius: 100)
                .scaleEffect(circleScale * 0.9 + 0.1)
                .animation(.easeInOut(duration: phase.duration), value: circleScale)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if isActive {
                        Text(timeString)
                            .font(.system(.callout, design: .monospaced, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .monospacedDigit()
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                // Andningscirkel – 3 lager med pulsande glöd
                ZStack {
                    // Yttersta ring
                    Circle()
                        .fill(phase.color.opacity(0.05))
                        .frame(width: 280, height: 280)
                        .scaleEffect(circleScale * 0.15 + 0.9)
                        .animation(.easeInOut(duration: phase.duration), value: circleScale)
                    // Mellanlager
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [phase.color.opacity(0.2), phase.color.opacity(0.04)],
                                center: .center, startRadius: 0, endRadius: 100
                            )
                        )
                        .frame(width: 210, height: 210)
                        .scaleEffect(circleScale * 0.3 + 0.7)
                        .animation(.easeInOut(duration: phase.duration), value: circleScale)
                    // Kärncirkel
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [phase.color.opacity(0.55), phase.color.opacity(0.15)],
                                center: .center, startRadius: 0, endRadius: 75
                            )
                        )
                        .frame(width: 150, height: 150)
                        .scaleEffect(circleScale)
                        .animation(.easeInOut(duration: phase.duration), value: circleScale)
                        .shadow(color: phase.color.opacity(0.4), radius: 24, y: 0)
                    // Fas-text
                    VStack(spacing: 4) {
                        Text(phase.rawValue)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .id(phase.rawValue)
                            .transition(.opacity)
                            .animation(DesignSystem.Animation.gentle, value: phase.rawValue)
                    }
                }
                .frame(height: 290)

                Spacer()

                if !isActive {
                    VStack(spacing: 16) {
                        Text("Box-andning · 1 min")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .textCase(.uppercase)
                            .tracking(1)

                        Button {
                            startBreathing()
                            LJHaptic.medium()
                        } label: {
                            Text("Starta")
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(LJPressableButtonStyle())
                        .padding(.horizontal, 32)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("Följ cirkeln – andas lugnt")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .transition(.opacity)
                }

                Spacer(minLength: 50)
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { timer?.invalidate() }
    }

    private var timeString: String {
        let m = secondsLeft / 60
        let s = secondsLeft % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startBreathing() {
        isActive = true
        advancePhase()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                secondsLeft -= 1
                if secondsLeft <= 0 {
                    timer?.invalidate()
                    dismiss()
                }
            }
        }
    }

    private func advancePhase() {
        // Set scale based on phase
        withAnimation(.easeInOut(duration: phase.duration)) {
            switch phase {
            case .inhale: circleScale = 1.0
            case .hold:   circleScale = 1.0
            case .exhale: circleScale = 0.5
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + phase.duration) {
            if isActive && secondsLeft > 0 {
                phase = phase.next
                advancePhase()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Dashboard()
        .preferredColorScheme(.dark)
}
