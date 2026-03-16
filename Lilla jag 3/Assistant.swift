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
    @ObservedObject private var ai = LillaJagAIService.shared
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
                    .onChange(of: ai.messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: ai.isThinking) { _, thinking in
                        if thinking { scrollToBottom(proxy) }
                    }
                }

                inputBar
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Avatar with animated emotion ring
            ZStack {
                Circle()
                    .stroke(
                        (ai.currentEmotion?.color ?? DesignSystem.Colors.accent).opacity(0.4),
                        lineWidth: 2
                    )
                    .frame(width: 46, height: 46)
                    .animation(.spring(response: 0.5), value: ai.currentEmotion?.dominant.name)

                Circle()
                    .fill((ai.currentEmotion?.color ?? DesignSystem.Colors.accent).opacity(0.15))
                    .frame(width: 42, height: 42)
                    .animation(.spring(response: 0.5), value: ai.currentEmotion?.dominant.name)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(ai.currentEmotion?.color ?? DesignSystem.Colors.accent)
                    .animation(.spring(response: 0.5), value: ai.currentEmotion?.dominant.name)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("KBT-Assistenten")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                HStack(spacing: 5) {
                    Circle()
                        .fill(DesignSystem.Colors.success)
                        .frame(width: 5, height: 5)
                    if let emotion = ai.currentEmotion, !ai.messages.isEmpty {
                        Text("Känsla detekterad: \(emotion.dominant.name)")
                            .transition(.opacity)
                    } else {
                        Text("Lokal AI · 100% privat")
                    }
                }
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .animation(.easeInOut(duration: 0.3), value: ai.currentEmotion?.dominant.name)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    ai.newSession()
                    showStarters = true
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.07), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Welcome section

    private var welcomeSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.warmLavender)
                    .padding(.bottom, 4)

                Text("Jag är här för dig")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text("Berätta vad du bär på, eller välj ett ämne nedan.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            // Conversation starters
            let starters = ConversationStarter.allCases.filter { $0 != .krisplan }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(starters, id: \.rawValue) { starter in
                    StarterChip(starter: starter) {
                        sendMessage(starter.rawValue)
                    }
                }
            }

            // Krisstöd-knapp
            Button {
                sendMessage(ConversationStarter.krisplan.rawValue)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cross.circle.fill")
                        .foregroundStyle(Color(hex: 0xFF5B5B))
                    Text("Jag mår akut dåligt")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: 0xFF5B5B).opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: 0xFF5B5B).opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Berätta hur du mår...", text: $inputText, axis: .vertical)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(.white)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(inputFocused ? 0.12 : 0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(
                                    inputFocused ? DesignSystem.Colors.accent.opacity(0.45) : Color.white.opacity(0.09),
                                    lineWidth: 1.5
                                )
                        )
                        .animation(.easeInOut(duration: 0.18), value: inputFocused)
                )

            let canSend = !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !ai.isThinking
            Button {
                sendMessage(inputText)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? DesignSystem.Colors.brandGradient : AnyShapeStyle(Color.white.opacity(0.08)))
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(canSend ? .white : .white.opacity(0.3))
                }
                .animation(.spring(response: 0.25), value: canSend)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
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

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

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
                Text(message.content)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                        ? AnyShapeStyle(LinearGradient(colors: [Color.warmLavender, Color(hex: 0x9B6FD6)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.white.opacity(0.08))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isUser ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                    )

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
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Color.warmLavender.opacity(0.2)).frame(width: 32, height: 32)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.warmLavender)
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(phase == i ? 0.9 : 0.3))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: 48)
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

// MARK: - Starter Chip

struct StarterChip: View {
    let starter: ConversationStarter
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(starter.color.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: starter.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(starter.color)
                }
                Text(starter.rawValue)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .background(starter.color.opacity(0.09),
                        in: RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.small, style: .continuous)
                    .stroke(starter.color.opacity(0.22), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 80)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
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
