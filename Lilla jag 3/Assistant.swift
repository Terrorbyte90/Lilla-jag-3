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
            ZStack {
                Circle()
                    .fill((ai.currentEmotion?.color ?? Color.warmLavender).opacity(0.2))
                    .frame(width: 44, height: 44)
                    .animation(.spring(response: 0.5), value: ai.currentEmotion?.dominant.name)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ai.currentEmotion?.color ?? Color.warmLavender)
                    .animation(.spring(response: 0.5), value: ai.currentEmotion?.dominant.name)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("KBT-Assistenten")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    if let emotion = ai.currentEmotion, !ai.messages.isEmpty {
                        Text("Känsla: \(emotion.dominant.name)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .transition(.opacity)
                    } else {
                        Text("Lokal AI · 100% privat")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: ai.currentEmotion?.dominant.name)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3)) {
                    ai.newSession()
                    showStarters = true
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ny konversation")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Welcome section

    private var welcomeSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.warmLavender.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.warmLavender)
                }
                .padding(.bottom, 4)

                Text("Jag är här för dig")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text("Berätta vad du bär på, eller välj ett ämne nedan.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
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
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty || ai.isThinking
                                     ? Color.white.opacity(0.3) : Color.warmLavender)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || ai.isThinking)
            .accessibilityLabel("Skicka meddelande")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
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

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: starter.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(starter.color)
                Text(starter.rawValue)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .background(starter.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(starter.color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 60)
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
