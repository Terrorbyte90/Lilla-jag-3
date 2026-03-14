// MeditationView.swift
// Lilla Jag – Andningsövningar & Mindfulness

import SwiftUI

// MARK: - Övningsmodell

struct BreathingExercise: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color
    let steps: [BreathStep]
    let totalRounds: Int
}

struct BreathStep: Identifiable {
    let id = UUID()
    let action: String
    let seconds: Int
    let color: Color
}

private let exercises: [BreathingExercise] = [
    BreathingExercise(
        name: "4-7-8 Andning",
        description: "Lugnar nervsystemet snabbt. Utmärkt vid ångest och sömnproblem.",
        icon: "lungs.fill",
        color: Color.warmLavender,
        steps: [
            BreathStep(action: "Andas in", seconds: 4, color: Color(hex: 0x6ECFF6)),
            BreathStep(action: "Håll andan", seconds: 7, color: Color.warmLavender),
            BreathStep(action: "Andas ut", seconds: 8, color: Color.warmSage)
        ],
        totalRounds: 4
    ),
    BreathingExercise(
        name: "Box Breathing",
        description: "Används av militär och idrottare. Återställer fokus och kontroll.",
        icon: "square.fill",
        color: Color.warmSage,
        steps: [
            BreathStep(action: "Andas in", seconds: 4, color: Color(hex: 0x6ECFF6)),
            BreathStep(action: "Håll andan", seconds: 4, color: Color.warmLavender),
            BreathStep(action: "Andas ut", seconds: 4, color: Color.warmSage),
            BreathStep(action: "Håll andan", seconds: 4, color: Color.warmGold)
        ],
        totalRounds: 4
    ),
    BreathingExercise(
        name: "5-4-3-2-1 Grounding",
        description: "Jordar dig i nuet vid panikattack. Engagerar alla sinnen.",
        icon: "hand.raised.fill",
        color: Color.warmGold,
        steps: [
            BreathStep(action: "5 saker du ser", seconds: 10, color: Color.warmGold),
            BreathStep(action: "4 du kan ta på", seconds: 10, color: Color.warmCoral),
            BreathStep(action: "3 du hör", seconds: 10, color: Color.warmLavender),
            BreathStep(action: "2 du luktar", seconds: 10, color: Color.warmSage),
            BreathStep(action: "1 du smakar", seconds: 8, color: Color.warmRose)
        ],
        totalRounds: 1
    ),
    BreathingExercise(
        name: "Lugn andning",
        description: "Enkel diafragmaandning för daglig stressprevention.",
        icon: "wind",
        color: Color.warmCoral,
        steps: [
            BreathStep(action: "Andas in sakta", seconds: 4, color: Color(hex: 0x6ECFF6)),
            BreathStep(action: "Andas ut sakta", seconds: 6, color: Color.warmSage)
        ],
        totalRounds: 6
    )
]

// MARK: - MeditationView (huvudvy)

struct MeditationView: View {
    @State private var selectedExercise: BreathingExercise? = nil
    @State private var completedExerciseNames: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Andning &\nMindfulness")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Vetenskapliga övningar för ångest och stress.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.top, 8)

                        if !completedExerciseNames.isEmpty {
                            completedBanner
                        }

                        ForEach(exercises) { exercise in
                            ExerciseCard(exercise: exercise,
                                         isDone: completedExerciseNames.contains(exercise.name)) {
                                selectedExercise = exercise
                            }
                        }

                        mindfulnessSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .fullScreenCover(item: $selectedExercise) { exercise in
                BreathingSession(exercise: exercise) {
                    completedExerciseNames.insert(exercise.name)
                }
            }
        }
    }

    private var completedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.warmSage)
            Text("\(completedExerciseNames.count) övning\(completedExerciseNames.count > 1 ? "ar" : "") avklarad idag – bra jobbat!")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
        .padding(12)
        .background(Color.warmSage.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.warmSage.opacity(0.2), lineWidth: 1))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var mindfulnessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Snabba mindfulness-tips")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            ForEach(mindfulnessTips, id: \.title) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Text(tip.icon)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tip.title)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(tip.text)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineSpacing(2)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

private struct MindfulnessTip { let icon: String; let title: String; let text: String }
private let mindfulnessTips = [
    MindfulnessTip(icon: "☕️", title: "En kopp i taget", text: "Drick din nästa kaffe/te utan telefon. Känn värmen, lukten, smaken."),
    MindfulnessTip(icon: "🚶", title: "Medveten promenad", text: "Gå ut i 5 minuter och fokusera bara på stegen och omgivningen."),
    MindfulnessTip(icon: "✍️", title: "Tre saker", text: "Skriv tre konkreta saker du är tacksam för idag – hur litet som helst."),
    MindfulnessTip(icon: "📱", title: "Digital paus", text: "Stäng av notiser i 30 minuter och märk skillnaden i din ångestnivå.")
]

// MARK: - Exercise Card

struct ExerciseCard: View {
    let exercise: BreathingExercise
    let isDone: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(exercise.color.opacity(isDone ? 0.3 : 0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: isDone ? "checkmark" : exercise.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(exercise.color)
                        .contentTransition(.symbolEffect(.replace))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        if isDone {
                            Text("Klar")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.warmSage)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.warmSage.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(exercise.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        ForEach(exercise.steps.prefix(4)) { step in
                            Text("\(step.seconds)s")
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(step.color.opacity(0.2), in: Capsule())
                                .foregroundStyle(step.color)
                        }
                        if exercise.totalRounds > 1 {
                            Text("×\(exercise.totalRounds)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }

                Spacer()
                Image(systemName: isDone ? "arrow.clockwise.circle" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(exercise.color.opacity(isDone ? 0.6 : 1.0))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(14)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(exercise.color.opacity(isDone ? 0.35 : 0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Breathing Session

struct BreathingSession: View {
    let exercise: BreathingExercise
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var currentStepIndex = 0
    @State private var timeLeft = 0
    @State private var round = 1
    @State private var isRunning = false
    @State private var isFinished = false
    @State private var scale: CGFloat = 1.0
    @State private var timer: Timer? = nil
    @State private var aiTip: String = ""
    @State private var loadingTip = false
    @State private var progressFraction: CGFloat = 0.0

    private var currentStep: BreathStep {
        exercise.steps[currentStepIndex % exercise.steps.count]
    }

    private var totalStepsAllRounds: Int {
        exercise.steps.count * exercise.totalRounds
    }

    private var completedSteps: Int {
        (round - 1) * exercise.steps.count + currentStepIndex
    }

    var body: some View {
        ZStack {
            Color(hex: 0x110820).ignoresSafeArea()

            // Progress arc behind breathing circle
            ZStack {
                // Outer ripple rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(currentStep.color.opacity(0.04 - Double(i) * 0.01))
                        .frame(width: 290 + CGFloat(i * 60), height: 290 + CGFloat(i * 60))
                        .scaleEffect(scale)
                        .animation(.easeInOut(duration: Double(currentStep.seconds)).repeatCount(1, autoreverses: false), value: scale)
                }

                // Progress ring
                Circle()
                    .stroke(currentStep.color.opacity(0.15), lineWidth: 6)
                    .frame(width: 240, height: 240)
                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(currentStep.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progressFraction)

                // Main breathing circle
                Circle()
                    .fill(
                        RadialGradient(colors: [currentStep.color.opacity(0.6), currentStep.color.opacity(0.08)],
                                       center: .center, startRadius: 20, endRadius: 120)
                    )
                    .frame(width: 220, height: 220)
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: Double(currentStep.seconds)), value: scale)

                VStack(spacing: 8) {
                    if isFinished {
                        Text("🎉")
                            .font(.system(size: 48))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(currentStep.action)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                            .id(currentStep.id)
                        Text("\(timeLeft)s")
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                }
            }
            .frame(width: 290, height: 290)

            VStack {
                // Header
                HStack {
                    Button {
                        stopTimer()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(exercise.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    if exercise.totalRounds > 1 {
                        Text("Runda \(round)/\(exercise.totalRounds)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Spacer().frame(width: 80)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Step dots
                HStack(spacing: 8) {
                    ForEach(0..<exercise.steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentStepIndex % exercise.steps.count
                                  ? currentStep.color : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentStepIndex)
                    }
                }

                Spacer().frame(height: 40)

                if isFinished {
                    VStack(spacing: 16) {
                        Text("Bra jobbat!")
                            .font(.system(.title, design: .rounded, weight: .black))
                            .foregroundStyle(.white)
                        Text("Du har slutfört \(exercise.name).")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)

                        // AI tip after exercise
                        if loadingTip {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Lilla Jag hämtar ett tips...")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        } else if !aiTip.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.warmGold)
                                    .font(.caption)
                                    .padding(.top, 2)
                                Text(aiTip)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineSpacing(3)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(12)
                            .background(Color.warmGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.warmGold.opacity(0.2), lineWidth: 1))
                            .padding(.horizontal, 8)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Button("Klar") {
                            onComplete()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                        }
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 200)
                        .padding(.vertical, 14)
                        .background(Color.warmGold)
                        .clipShape(Capsule())
                        .shadow(color: Color.warmGold.opacity(0.4), radius: 10, y: 4)
                    }
                    .transition(.opacity.combined(with: .scale))
                    .padding(.horizontal, 20)
                } else if !isRunning {
                    Button("Starta övning") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        startExercise()
                    }
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(exercise.color)
                    .clipShape(Capsule())
                    .shadow(color: exercise.color.opacity(0.4), radius: 10, y: 4)
                }

                Spacer().frame(height: 60)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func startExercise() {
        currentStepIndex = 0
        round = 1
        isRunning = true
        isFinished = false
        progressFraction = 0
        startStep()
    }

    private func startStep() {
        let step = exercise.steps[currentStepIndex]
        timeLeft = step.seconds
        progressFraction = 0

        withAnimation(.easeInOut(duration: Double(step.seconds))) {
            scale = step.action.contains("ut") ? 0.7 : (step.action.contains("Håll") ? scale : 1.3)
        }

        let total = Double(step.seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if timeLeft > 1 {
                    timeLeft -= 1
                    progressFraction = CGFloat(total - Double(timeLeft - 1)) / CGFloat(total)
                    UISelectionFeedbackGenerator().selectionChanged()
                } else {
                    stopTimer()
                    nextStep()
                }
            }
        }
    }

    private func nextStep() {
        let nextIndex = currentStepIndex + 1
        if nextIndex < exercise.steps.count {
            currentStepIndex = nextIndex
            startStep()
        } else if round < exercise.totalRounds {
            round += 1
            currentStepIndex = 0
            startStep()
        } else {
            progressFraction = 1.0
            withAnimation(.spring(response: 0.5)) { isFinished = true }
            isRunning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { await fetchAITip() }
        }
    }

    private func fetchAITip() async {
        loadingTip = true
        let prompt = "Ge ett kort, varmt och uppmuntrande tips (1-2 meningar) på svenska om hur man kan behålla lugnet från andningsövningen \(exercise.name) under dagen."
        aiTip = await LillaJagAIService.shared.generateResponse(to: prompt)
        loadingTip = false
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Preview

#Preview {
    MeditationView()
        .preferredColorScheme(.dark)
}
