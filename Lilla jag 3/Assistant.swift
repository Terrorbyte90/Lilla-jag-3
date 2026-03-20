// Assistant.swift
// Lilla Jag – AI KBT-Terapeut

import SwiftUI

// MARK: - AssistantView (navbar-tab)

// OBS: .withNavbar(dest: .chat) läggs till av RootContainer – ej här
struct AssistantView: View {
    var body: some View {
        AITherapistView()
    }
}

// MARK: - AITherapistView

struct AITherapistView: View {
    @StateObject private var ai = LillaJagAIService.shared
    @State private var inputText = ""
    @State private var showStarters = true
    @State private var scrollProxy: ScrollViewProxy? = nil
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            WarmBackground()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.15)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if ai.messages.isEmpty {
                                welcomeSection
                            }

                            ForEach(ai.messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }

                            if ai.isThinking {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .padding(.bottom, 8)
                    }
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: ai.messages.count) {
                        scrollToBottom(proxy)
                    }
                    .onChange(of: ai.isThinking) {
                        if ai.isThinking { scrollToBottom(proxy) }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { inputBar }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Avatar med färganimation baserat på emotion
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (ai.currentEmotion?.color ?? Color.warmLavender).opacity(0.35),
                                (ai.currentEmotion?.color ?? Color.warmLavender).opacity(0.08)
                            ],
                            center: .center, startRadius: 0, endRadius: 24
                        )
                    )
                    .frame(width: 46, height: 46)
                    .animation(DesignSystem.Animation.smooth, value: ai.currentEmotion?.dominant.name)
                    .overlay(
                        Circle()
                            .stroke((ai.currentEmotion?.color ?? Color.warmLavender).opacity(0.25), lineWidth: 1)
                            .animation(DesignSystem.Animation.smooth, value: ai.currentEmotion?.dominant.name)
                    )
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ai.currentEmotion?.color ?? Color.warmLavender)
                    .animation(DesignSystem.Animation.smooth, value: ai.currentEmotion?.dominant.name)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("KBT-Assistenten")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 5) {
                    PulsingDot(color: .green, size: 5)
                    if let emotion = ai.currentEmotion, !ai.messages.isEmpty {
                        Text("Känsla: \(emotion.dominant.name)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    } else {
                        Text("Lokal AI · 100% privat")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .animation(DesignSystem.Animation.gentle, value: ai.currentEmotion?.dominant.name)
            }

            Spacer()

            Button {
                LJHaptic.light()
                withAnimation(DesignSystem.Animation.smooth) {
                    ai.newSession()
                    showStarters = true
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(LJPressableButtonStyle())
            .accessibilityLabel("Ny konversation")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Welcome section

    private var welcomeSection: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                // Animerad avatar-ikon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.warmLavender.opacity(0.25), Color.warmLavender.opacity(0.04)],
                                center: .center, startRadius: 0, endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(Circle().stroke(Color.warmLavender.opacity(0.2), lineWidth: 1))
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.warmLavender)
                }
                .padding(.bottom, 4)
                .padding(.top, 24)

                Text("Jag är här för dig")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-0.3)

                Text("Berätta vad du bär på, eller välj ett ämne nedan.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Conversation starters med bättre grid
            let starters = ConversationStarter.allCases.filter { $0 != .krisplan }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(starters, id: \.rawValue) { starter in
                    StarterChip(starter: starter) {
                        sendMessage(starter.rawValue)
                    }
                }
            }

            // Krisstöd-knapp – tydligare och mer åtkomlig
            Button {
                sendMessage(ConversationStarter.krisplan.rawValue)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFF5B5B))
                    Text("Jag mår akut dåligt")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hex: 0xFF5B5B).opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: 0xFF5B5B).opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(LJPressableButtonStyle())
            .accessibilityLabel("Akut stöd – jag mår dåligt")
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 12)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Berätta hur du mår...", text: $inputText, axis: .vertical)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .tint(Color.warmLavender)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(
                                    inputFocused
                                    ? Color.warmLavender.opacity(0.35)
                                    : Color.white.opacity(0.10),
                                    lineWidth: 1
                                )
                        )
                )
                .animation(DesignSystem.Animation.gentle, value: inputFocused)

            let canSend = !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !ai.isThinking
            Button {
                LJHaptic.medium()
                sendMessage(inputText)
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? Color.warmLavender : Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSend ? .black : .white.opacity(0.3))
                }
                .shadow(color: canSend ? Color.warmLavender.opacity(0.4) : .clear, radius: 8, y: 2)
            }
            .buttonStyle(LJPressableButtonStyle())
            .disabled(!canSend)
            .animation(DesignSystem.Animation.quick, value: canSend)
            .accessibilityLabel("Skicka meddelande")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.08)
        }
    }

    // MARK: - Actions

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        withAnimation(.spring(response: 0.3)) {
            showStarters = false
        }
        inputText = ""
        inputFocused = false

        // Räkna chat-sessioner för achievements (räkna vid första meddelandet i en session)
        if ai.messages.isEmpty {
            let prev = UserDefaults.standard.integer(forKey: "lj_chat_session_count")
            UserDefaults.standard.set(prev + 1, forKey: "lj_chat_session_count")
            AchievementsStore.shared.checkAndUnlock(
                streakDays: 0,
                moodLogCount: 0,
                journalCount: 0,
                breathingCount: 0,
                chatCount: prev + 1
            )
        }

        Task {
            await ai.addUserMessage(trimmed)
            let response = await ai.generateResponse(to: trimmed)
            withAnimation(.spring(response: 0.4)) {
                ai.addAssistantMessage(response)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let last = ai.messages.last {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            } else if ai.isThinking {
                withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
            }
        }
    }
}

// MARK: - Message Bubble
// Innovation 2: Meddelande-reaktioner och kopiera-citat.
// Håll ned ett AI-svar för att se alternativ: 👍 Hjälpsam, 💡 Spara insikt, 📋 Kopiera.
// Sparade insikter lagras i UserDefaults och visas som ett gulmarkerat citat under meddelandet.

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    /// Visar kontextmenyn (long-press)
    @State private var showActions = false
    /// Indikerar om det här meddelandet är markerat som hjälpsamt
    @State private var isHelpful: Bool = false
    /// Indikerar om insikten är sparad
    @State private var isSaved: Bool = false
    /// Kort feedback-text visad efter åtgärd
    @State private var feedbackText: String? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            if !isUser {
                ZStack {
                    Circle().fill(Color.warmLavender.opacity(0.2)).frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.warmLavender)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Bubblan – AI-svar kan håller man ned för kontextmeny
                Text(message.content)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                        ? AnyShapeStyle(LinearGradient(colors: [Color.warmLavender, Color(hex: 0x9B6FD6)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(isHelpful ? Color.warmSage.opacity(0.12) : Color.white.opacity(0.08))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isHelpful
                                    ? Color.warmSage.opacity(0.3)
                                    : (isUser ? Color.clear : Color.white.opacity(0.1)),
                                lineWidth: 1
                            )
                    )
                    // Lång tryckning öppnar reaktions-menyn för AI-svar
                    .onLongPressGesture(minimumDuration: 0.4) {
                        guard !isUser else { return }
                        LJHaptic.medium()
                        withAnimation(.spring(response: 0.3)) { showActions = true }
                    }

                // Reaktions-rad (visas efter lång tryckning på AI-svar)
                if showActions && !isUser {
                    HStack(spacing: 6) {
                        // Hjälpsam-reaktion
                        reactionButton(
                            icon: isHelpful ? "hand.thumbsup.fill" : "hand.thumbsup",
                            label: "Hjälpsam",
                            color: Color.warmSage
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                isHelpful.toggle()
                            }
                            LJHaptic.light()
                            showFeedback(isHelpful ? "Tack för återkopplingen!" : "")
                        }

                        // Spara insikt till UserDefaults
                        reactionButton(
                            icon: isSaved ? "bookmark.fill" : "bookmark",
                            label: "Spara",
                            color: Color.warmGold
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                isSaved.toggle()
                            }
                            LJHaptic.light()
                            SavedInsightsStore.toggle(message.content)
                            showFeedback(isSaved ? "Insikt sparad!" : "Borttagen")
                        }

                        // Kopiera till urklipp
                        reactionButton(icon: "doc.on.doc", label: "Kopiera", color: Color.warmLavender) {
                            UIPasteboard.general.string = message.content
                            LJHaptic.light()
                            showFeedback("Kopierat!")
                            withAnimation(.easeOut.delay(1.2)) { showActions = false }
                        }

                        // Stäng reaktionsraden
                        Button {
                            withAnimation(.spring(response: 0.25)) { showActions = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(6)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

                // Feedback-text (t.ex. "Insikt sparad!")
                if let fb = feedbackText {
                    Text(fb)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.warmGold)
                        .transition(.opacity)
                }

                // Sparad-insikt-indikator
                if isSaved {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.warmGold.opacity(0.7))
                        Text("Sparad insikt")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.warmGold.opacity(0.7))
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Emotion badge for user messages
                if isUser, let emotion = message.emotion, emotion.dominant.value > 0.45 {
                    HStack(spacing: 4) {
                        Image(systemName: emotion.icon)
                            .font(.system(size: 9, weight: .medium))
                        Text(emotion.dominant.name)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(emotion.color.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(emotion.color.opacity(0.15), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                }
            }

            if !isUser { Spacer(minLength: 48) }
        }
        .transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
        .onAppear {
            // Återställ sparad-status från UserDefaults vid rendering
            isSaved = SavedInsightsStore.contains(message.content)
        }
    }

    /// Bygger en reaktionsknapp med ikon, label och färg
    @ViewBuilder
    private func reactionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// Visar kortvarig feedbacktext och döljer den sedan
    private func showFeedback(_ text: String) {
        guard !text.isEmpty else { return }
        withAnimation { feedbackText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { feedbackText = nil }
        }
    }
}

// MARK: - SavedInsightsStore
// Enkel UserDefaults-baserad lagring för sparade AI-insikter.
// Används av MessageBubble för att persista "bokmärkta" svar mellan sessioner.

struct SavedInsightsStore {
    private static let key = "lj_saved_insights"

    static func loadAll() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func contains(_ text: String) -> Bool {
        loadAll().contains(text)
    }

    static func toggle(_ text: String) {
        var all = loadAll()
        if let i = all.firstIndex(of: text) {
            all.remove(at: i)
        } else {
            // Begränsa till 50 sparade insikter för att hålla nere minnesanvändningen
            if all.count >= 50 { all.removeFirst() }
            all.append(text)
        }
        UserDefaults.standard.set(all, forKey: key)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0
    @State private var appeared = false
    let timer = Timer.publish(every: 0.38, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.warmLavender.opacity(0.3), Color.warmLavender.opacity(0.06)],
                            center: .center, startRadius: 0, endRadius: 18
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(Color.warmLavender.opacity(0.2), lineWidth: 1))
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.warmLavender)
            }

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(phase == i ? 0.85 : 0.25))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.3 : 1.0)
                        .offset(y: phase == i ? -2 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: phase)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

            Spacer(minLength: 48)
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.85, anchor: .leading)
        .animation(DesignSystem.Animation.smooth, value: appeared)
        .onAppear { appeared = true }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

// MARK: - Starter Chip

struct StarterChip: View {
    let starter: ConversationStarter
    let action: () -> Void

    var body: some View {
        Button(action: {
            LJHaptic.light()
            action()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(starter.color.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: starter.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(starter.color)
                }
                Text(starter.rawValue)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(13)
            .background {
                ZStack {
                    starter.color.opacity(0.08)
                    LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(starter.color.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(LJPressableButtonStyle())
        .frame(minHeight: 72)
    }
}

// MARK: - ChattyView (används från Dashboard som anonym chatt)

struct ChattyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AITherapistView()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(16)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview("AI-terapeut") {
    AITherapistView()
        .preferredColorScheme(.dark)
}

#Preview("Med meddelanden") {
    let view = AITherapistView()
    // Lägg till förhandsgranskningsmesssages manuellt i Preview
    return view.preferredColorScheme(.dark)
}
