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

// MARK: - ForumView

struct ForumView: View {
    @State private var posts = samplePosts
    @State private var showNewPost = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        anonymityBanner

                        VStack(spacing: 12) {
                            ForEach($posts) { $post in
                                ForumCard(post: $post)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
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
                    posts.insert(newPost, at: 0)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.warmSage.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.warmSage.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Forum Card

struct ForumCard: View {
    @Binding var post: ForumPost

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
                .lineLimit(3)

            HStack(spacing: 16) {
                Button {
                    post.likes += post.isLiked ? -1 : 1
                    post.isLiked.toggle()
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
    @State private var nickname = "Anonym "

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()
                VStack(spacing: 16) {
                    TextField("Smeknamn (t.ex. 'Anonym sol')", text: $nickname)
                        .foregroundStyle(.white).padding(12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    TextField("Rubrik", text: $title)
                        .foregroundStyle(.white).padding(12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .placeholder("Dela din upplevelse, fråga om råd eller dela hopp...", text: $content)
                    Spacer()
                }
                .padding(16)
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
                            author: nickname.isEmpty ? "Anonym" : nickname,
                            title: title,
                            content: content,
                            timeAgo: "Nu",
                            tag: "Nytt",
                            tagColor: Color.warmGold,
                            likes: 0,
                            comments: 0
                        )
                        onPost(post)
                        dismiss()
                    }
                    .foregroundStyle(title.isEmpty ? .white.opacity(0.3) : Color.warmGold)
                    .fontWeight(.bold)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ForumView()
}
