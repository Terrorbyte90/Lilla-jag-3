// Forum.swift
// Lilla Jag – Community-forumet (lokalt/offline)

import SwiftUI

// MARK: - Models

struct ForumPost: Identifiable {
    let id = UUID()
    let author: String
    let title: String
    let content: String
    let timeAgo: String
    let tag: String
    let tagColor: Color
    var likes: Int
    var comments: Int
    var isLiked: Bool = false
}

private var samplePosts: [ForumPost] = [
    ForumPost(author: "Anonym björn", title: "Vad hjälper er mot ångest på natten?",
              content: "Jag vaknar ofta klockan 3-4 med stark ångest. Har testat andningsövningar men det hjälper inte alltid. Delar gärna tips med varandra!",
              timeAgo: "2 tim", tag: "Ångest", tagColor: Color.warmLavender, likes: 34, comments: 12),
    ForumPost(author: "Anonym sol", title: "Idag hade jag en bra dag – och det känns konstigt",
              content: "Har kämpat med depression i månader. Idag mådde jag faktiskt bra på riktigt. Men sen kom skulden och oron att det ska gå tillbaka. Någon mer som känner igen sig?",
              timeAgo: "5 tim", tag: "Depression", tagColor: Color(hex: 0x6B8DD6), likes: 67, comments: 23),
    ForumPost(author: "Anonym stjärna", title: "Tips för att inte jämföra sig med andra",
              content: "Social media förstärker min ångest enormt. Har börjat använda tider på telefonen men det räcker inte. Vad gör ni?",
              timeAgo: "1 dag", tag: "Tips", tagColor: Color.warmSage, likes: 45, comments: 18),
    ForumPost(author: "Anonym regn", title: "KBT hjälpte mig – min berättelse",
              content: "För sex månader sedan kunde jag knappt lämna lägenheten. Nu är jag tillbaka på deltid. KBT är svårt men det funkar. Vill bara dela hoppet med er.",
              timeAgo: "2 dag", tag: "Återhämtning", tagColor: Color.warmGold, likes: 112, comments: 41),
    ForumPost(author: "Anonym måne", title: "Hur pratar ni med familjen om er psykiska hälsa?",
              content: "Min familj förstår inte riktigt vad jag går igenom. De säger att jag ska 'ta mig samman'. Hur har ni hanterat det?",
              timeAgo: "3 dag", tag: "Relationer", tagColor: Color.warmRose, likes: 89, comments: 37),
]

private let allTags = ["Alla", "Ångest", "Depression", "Tips", "Återhämtning", "Relationer"]

// MARK: - ForumView

struct ForumView: View {
    @State private var posts = samplePosts
    @State private var showNewPost = false
    @State private var selectedTag = "Alla"
    @Environment(\.dismiss) private var dismiss

    private var filtered: [ForumPost] {
        selectedTag == "Alla" ? posts : posts.filter { $0.tag == selectedTag }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        anonymityBanner

                        // Tag filter
                        tagFilterRow
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        if filtered.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 12) {
                                ForEach($posts.filter { p in
                                    selectedTag == "Alla" || p.wrappedValue.tag == selectedTag
                                }) { $post in
                                    ForumCard(post: $post)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showNewPost = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Color.warmGold)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .sheet(isPresented: $showNewPost) {
                NewPostView { newPost in
                    withAnimation(.spring(response: 0.4)) {
                        posts.insert(newPost, at: 0)
                    }
                }
            }
        }
    }

    private var tagFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allTags, id: \.self) { tag in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTag = tag
                        }
                    } label: {
                        Text(tag)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(selectedTag == tag ? .black : .white.opacity(0.75))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedTag == tag
                                ? AnyShapeStyle(Color.warmLavender)
                                : AnyShapeStyle(Color.white.opacity(0.1)),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var anonymityBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Color.warmSage)
            Text("Alla inlägg är anonyma. Du väljer ett smeknamn.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text("\(posts.count) inlägg")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(12)
        .background(Color.warmSage.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.warmSage.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            LJIconCircle(icon: "bubble.left.and.bubble.right", color: .white.opacity(0.5), size: 56)
            Text("Inga inlägg med taggen \"\(selectedTag)\"")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Button("Skapa ett") { showNewPost = true }
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.warmGold)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Forum Card

struct ForumCard: View {
    @Binding var post: ForumPost
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(post.author)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(post.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                TagBadge(text: post.tag, color: post.tagColor)
            }

            Text(post.title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(post.content)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(isExpanded ? nil : 3)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)

            if post.content.count > 120 {
                Button(isExpanded ? "Visa mindre" : "Läs mer") {
                    withAnimation { isExpanded.toggle() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(post.tagColor.opacity(0.9))
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        post.likes += post.isLiked ? -1 : 1
                        post.isLiked.toggle()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("\(post.likes)", systemImage: post.isLiked ? "heart.fill" : "heart")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(post.isLiked ? Color.warmRose : .white.opacity(0.5))
                }
                .buttonStyle(.plain)

                Label("\(post.comments)", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct TagBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - New Post

struct NewPostView: View {
    var onPost: (ForumPost) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var nickname = ""
    @State private var selectedTag = "Ångest"
    @State private var aiSuggestion = ""
    @State private var loadingAI = false

    private let tagOptions = ["Ångest", "Depression", "Tips", "Återhämtning", "Relationer", "Övrigt"]
    private let tagColors: [String: Color] = [
        "Ångest": Color.warmLavender, "Depression": Color(hex: 0x6B8DD6),
        "Tips": Color.warmSage, "Återhämtning": Color.warmGold,
        "Relationer": Color.warmRose, "Övrigt": Color.white.opacity(0.5)
    ]

    private var canPost: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && !content.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        // Nickname
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Smeknamn")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            TextField("t.ex. Anonym sol", text: $nickname)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Tag picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kategori")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(tagOptions, id: \.self) { tag in
                                        Button {
                                            selectedTag = tag
                                        } label: {
                                            Text(tag)
                                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                                .foregroundStyle(selectedTag == tag ? .black : .white.opacity(0.7))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    selectedTag == tag
                                                    ? AnyShapeStyle(tagColors[tag] ?? Color.warmLavender)
                                                    : AnyShapeStyle(Color.white.opacity(0.1)),
                                                    in: Capsule()
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Rubrik")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            TextField("Vad handlar ditt inlägg om?", text: $title)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Content
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ditt inlägg")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            TextEditor(text: $content)
                                .frame(minHeight: 140)
                                .padding(8)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .font(.system(.body, design: .rounded))
                        }

                        // AI post helper
                        Button {
                            Task { await getAISuggestion() }
                        } label: {
                            HStack(spacing: 8) {
                                if loadingAI {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(loadingAI ? "Lilla Jag formulerar..." : "Hjälp mig formulera inlägget")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.warmLavender.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.warmLavender.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty || loadingAI)

                        if !aiSuggestion.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Förslag från Lilla Jag:")
                                        .font(.system(.caption, design: .rounded, weight: .semibold))
                                        .foregroundStyle(Color.warmGold)
                                    Spacer()
                                    Button("Använd") {
                                        content = aiSuggestion
                                        aiSuggestion = ""
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.warmGold)
                                }
                                Text(aiSuggestion)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineSpacing(3)
                            }
                            .padding(12)
                            .background(Color.warmGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.warmGold.opacity(0.2), lineWidth: 1))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer()
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Nytt inlägg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publicera") {
                        let post = ForumPost(
                            author: nickname.trimmingCharacters(in: .whitespaces).isEmpty ? "Anonym" : nickname,
                            title: title.trimmingCharacters(in: .whitespaces),
                            content: content.trimmingCharacters(in: .whitespaces),
                            timeAgo: "Nu",
                            tag: selectedTag,
                            tagColor: tagColors[selectedTag] ?? Color.warmLavender,
                            likes: 0,
                            comments: 0
                        )
                        onPost(post)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .foregroundStyle(canPost ? Color.warmGold : .white.opacity(0.3))
                    .fontWeight(.bold)
                    .disabled(!canPost)
                }
            }
        }
    }

    private func getAISuggestion() async {
        guard !title.isEmpty else { return }
        loadingAI = true
        let prompt = "Skriv ett kort, empatiskt och ärligt foruminlägg på svenska (3-5 meningar) om ämnet: \"\(title)\" under kategorin \(selectedTag). Skriv i första person, som om du är en person som söker stöd och delar sin upplevelse. Inga punktlistor."
        aiSuggestion = await LillaJagAIService.shared.generateResponse(to: prompt)
        loadingAI = false
    }
}

#Preview {
    ForumView()
}
