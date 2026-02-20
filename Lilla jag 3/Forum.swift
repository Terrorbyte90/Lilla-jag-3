//
//  Forum.swift
//  Supersnyggt Forum – hel fil (inte main)
//  – Ingen "Hem" i toppraden
//  – Egengjord "Till Forum"-knapp i tråd (eftersom back är dold)
//  – Avatar-popup (emoji eller egen bild via PhotosPicker)
//  – "Ny tråd" är fullscreen
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Modeller

struct ForumUser: Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var avatarEmoji: String
    var avatarImageData: Data?
    
    init(id: UUID = UUID(), displayName: String, avatarEmoji: String = "🧑‍💻", avatarImageData: Data? = nil) {
        self.id = id
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.avatarImageData = avatarImageData
    }
}

struct ForumReply: Identifiable, Hashable {
    let id: UUID
    var author: ForumUser
    var text: String
    var createdAt: Date
    var isAccepted: Bool
    
    init(id: UUID = UUID(),
         author: ForumUser,
         text: String,
         createdAt: Date = .now,
         isAccepted: Bool = false) {
        self.id = id
        self.author = author
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.isAccepted = isAccepted
    }
}

struct ForumPost: Identifiable, Hashable {
    let id: UUID
    var author: ForumUser
    var title: String
    var body: String
    var tags: [String]
    var createdAt: Date
    var isLocked: Bool
    var acceptedReplyID: UUID?
    var replies: [ForumReply]
    
    init(id: UUID = UUID(),
         author: ForumUser,
         title: String,
         body: String,
         tags: [String] = [],
         createdAt: Date = .now,
         isLocked: Bool = false,
         acceptedReplyID: UUID? = nil,
         replies: [ForumReply] = []) {
        self.id = id
        self.author = author
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tags = tags
        self.createdAt = createdAt
        self.isLocked = isLocked
        self.acceptedReplyID = acceptedReplyID
        self.replies = replies
    }
}

// MARK: - Store

@MainActor
final class ForumStore: ObservableObject {
    @Published var posts: [ForumPost] = []
    @Published var currentUser: ForumUser
    
    init(seedDemoData: Bool = true, currentUser: ForumUser = ForumUser(displayName: "Du", avatarEmoji: "🦊")) {
        self.currentUser = currentUser
        if seedDemoData { seed() }
    }
    
    func createPost(title: String, body: String, tags: [String]) {
        var post = ForumPost(author: currentUser, title: title, body: body, tags: tags)
        if post.tags.isEmpty { post.tags = ["Fråga"] }
        posts.insert(post, at: 0)
    }
    
    func addReply(text: String, to postID: UUID) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        guard !posts[idx].isLocked else { return }
        let reply = ForumReply(author: currentUser, text: text)
        posts[idx].replies.append(reply)
    }
    
    func accept(replyID: UUID, for postID: UUID) {
        guard let pIndex = posts.firstIndex(where: { $0.id == postID }) else { return }
        guard posts[pIndex].author.id == currentUser.id else { return } // endast OP
        guard let rIndex = posts[pIndex].replies.firstIndex(where: { $0.id == replyID }) else { return }
        
        if let prev = posts[pIndex].acceptedReplyID,
           let oldIdx = posts[pIndex].replies.firstIndex(where: { $0.id == prev }) {
            posts[pIndex].replies[oldIdx].isAccepted = false
        }
        posts[pIndex].replies[rIndex].isAccepted = true
        posts[pIndex].acceptedReplyID = replyID
        posts[pIndex].isLocked = true
        
        // Pin accepterad överst
        let accepted = posts[pIndex].replies.remove(at: rIndex)
        posts[pIndex].replies.insert(accepted, at: 0)
    }
    
    private func seed() {
        let anna = ForumUser(displayName: "Anna", avatarEmoji: "🦄")
        let erik = ForumUser(displayName: "Erik", avatarEmoji: "🐯")
        let du = currentUser
        
        var p1 = ForumPost(
            author: anna,
            title: "Hur designar man en riktigt snygg forumlista i SwiftUI?",
            body: "Vill ha glas/blur, gradient, chips för taggar och en tydlig 'Ny tråd'-knapp. Tips?",
            tags: ["SwiftUI", "Design", "iOS"],
            createdAt: Date().addingTimeInterval(-3600),
            replies: [
                ForumReply(author: erik, text: "Kör .ultraThinMaterial på kort och en mjuk gradient som stroke.", createdAt: Date().addingTimeInterval(-1800)),
                ForumReply(author: du, text: "Glas + kapslar för taggar. Lägg accepted svar först i listan när markerad.", createdAt: Date().addingTimeInterval(-1200))
            ]
        )
        var p2 = ForumPost(
            author: du,
            title: "Markera svar som perfekt och lås tråd",
            body: "Jag vill kunna markera ett svar och därefter låsa tråden automatiskt.",
            tags: ["Moderering", "Löst"],
            createdAt: Date().addingTimeInterval(-7200),
            replies: [
                ForumReply(author: anna, text: "Använd en flagga på svaret + post.isLocked = true när satt.", createdAt: Date().addingTimeInterval(-7000))
            ]
        )
        if let rid = p2.replies.first?.id {
            p2.acceptedReplyID = rid
            p2.replies[0].isAccepted = true
            p2.isLocked = true
        }
        posts = [p1, p2]
    }
}

// MARK: - UI Helpers

fileprivate extension Date {
    func relativeSV() -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.unitsStyle = .short
        return f.localizedString(for: self, relativeTo: .now)
    }
}

fileprivate struct GlassCard: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(LinearGradient(stops: [
                        .init(color: Color.white.opacity(0.6), location: 0.0),
                        .init(color: Color.white.opacity(0.05), location: 1.0)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
    }
}

fileprivate extension View {
    func glassCard(_ radius: CGFloat = 20) -> some View { modifier(GlassCard(radius: radius)) }
}

fileprivate let brandGradient: LinearGradient = LinearGradient(
    colors: [Color.purple, Color.blue, Color.cyan],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

fileprivate struct TagChip: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(LinearGradient(colors: [
                Color.white.opacity(0.15),
                Color.white.opacity(0.05)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

fileprivate struct AvatarView: View {
    var emoji: String
    var imageData: Data?
    var size: CGFloat = 34
    
    var body: some View {
        ZStack {
            if let data = imageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
            } else {
                Text(emoji)
                    .font(.system(size: size * 0.53))
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            }
        }
    }
}

// MARK: - Huvudvy

public struct ForumView: View {
    @StateObject private var store = ForumStore()
    
    @State private var searchText: String = ""
    @State private var showComposer: Bool = false
    @State private var selectedTags: Set<String> = []
    @State private var animateHeader: Bool = false
    @State private var showAvatarPopup: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                background
                VStack(spacing: 16) {
                    header
                        .offset(y: animateHeader ? 0 : -10)
                        .opacity(animateHeader ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: animateHeader)
                    filterBar
                    listView
                }
                .padding(.horizontal, 16)
                composeBar
                if showAvatarPopup {
                    AvatarPickerOverlay(isPresented: $showAvatarPopup, user: $store.currentUser)
                        .zIndex(10)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .onAppear { animateHeader = true }
            .navigationTitle("")
            // OBS: vi tar bort toppradens "Hem" helt (ingen toolbar här)
            .fullScreenCover(isPresented: $showComposer) {
                NewPostSheet { title, body, tags in
                    store.createPost(title: title, body: body, tags: tags)
                }
            }
        }
    }
    
    private var background: some View {
        LinearGradient(colors: [Color(#colorLiteral(red: 0.07, green: 0.08, blue: 0.18, alpha: 1)),
                                Color(#colorLiteral(red: 0.05, green: 0.07, blue: 0.12, alpha: 1))],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .overlay(
                ZStack {
                    Circle().fill(brandGradient).blur(radius: 120).opacity(0.25)
                        .frame(width: 260, height: 260).offset(x: -140, y: -260)
                    Circle().fill(LinearGradient(colors: [.pink, .orange], startPoint: .top, endPoint: .bottom))
                        .blur(radius: 140).opacity(0.18)
                        .frame(width: 260, height: 260).offset(x: 150, y: 300)
                }
            )
    }
    
    // MARK: UI-sektioner
    
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Forum")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 8)
                Text("Ställ frågor, få svar – markera lösningen och lås tråden när du är nöjd.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 8)
            
            AvatarView(emoji: store.currentUser.avatarEmoji,
                       imageData: store.currentUser.avatarImageData,
                       size: 38)
                .overlay(alignment: .bottomTrailing) {
                    Circle().fill(.green).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showAvatarPopup = true
                    }
                }
                .accessibilityLabel(Text("Byt avatar"))
        }
        .padding(16)
        .glassCard(24)
    }
    
    private var filterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.7))
                TextField("Sök i forumet…", text: $searchText)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard(18)
            
            let allTags = Array(Set(store.posts.flatMap { $0.tags })).sorted()
            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            let selected = selectedTags.contains(tag)
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(selected ? brandGradient : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                                .foregroundStyle(selected ? .white : .white.opacity(0.9))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                .onTapGesture {
                                    if selected { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                                }
                                .animation(.easeInOut(duration: 0.2), value: selectedTags)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    private var listView: some View {
        let filtered = store.posts
            .filter { post in
                (searchText.isEmpty ||
                 post.title.localizedCaseInsensitiveContains(searchText) ||
                 post.body.localizedCaseInsensitiveContains(searchText) ||
                 post.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText))
                &&
                (selectedTags.isEmpty || !Set(post.tags).isDisjoint(with: selectedTags))
            }
        
        return ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(filtered) { post in
                    NavigationLink {
                        PostDetailView(post: binding(for: post),
                                       currentUser: $store.currentUser,
                                       acceptAction: { replyID in
                                           store.accept(replyID: replyID, for: post.id)
                                       },
                                       replyAction: { text in
                                           store.addReply(text: text, to: post.id)
                                       })
                    } label: {
                        PostCard(post: post)
                    }
                    .buttonStyle(.plain)
                }
                if filtered.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "binoculars.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.9))
                        Text("Inget hittades").foregroundStyle(.white.opacity(0.75))
                        Text("Justera sökningen eller taggarna.").font(.footnote).foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(24)
                    .glassCard(20)
                    .padding(.top, 40)
                }
            }
            .padding(.vertical, 6)
        }
    }
    
    private var composeBar: some View {
        VStack {
            Spacer()
            HStack {
                // "Hem" finns endast här nere
                NavigationLink {
                    ContentHost()
                } label: {
                    Image(systemName: "house.fill")
                        .font(.title3.weight(.bold))
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                        .accessibilityLabel(Text("Till startsidan"))
                }
                .buttonStyle(.plain)
                
                Spacer()
                Button {
                    showComposer = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.bubble.fill").imageScale(.large)
                        Text("Ny tråd").font(.headline.weight(.semibold))
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 14)
                    .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                }
                .accessibilityLabel(Text("Skapa ny tråd"))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
    }
    
    private func binding(for post: ForumPost) -> Binding<ForumPost> {
        guard let idx = store.posts.firstIndex(where: {$0.id == post.id}) else {
            return .constant(post)
        }
        return $store.posts[idx]
    }
}

// Wrapper för ContentView som döljer back-knapp
fileprivate struct ContentHost: View {
    var body: some View {
        ContentView()
            .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Postkort

fileprivate struct PostCard: View {
    var post: ForumPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                AvatarView(emoji: post.author.avatarEmoji, imageData: post.author.avatarImageData)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.title).font(.headline.weight(.semibold)).foregroundStyle(.white)
                    Text("\(post.author.displayName) • \(post.createdAt.relativeSV())")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if post.isLocked {
                    lockBadge
                } else if post.acceptedReplyID != nil {
                    solvedBadge
                }
            }
            Text(post.body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(3)
            if !post.tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(post.tags.prefix(4), id: \.self) { TagChip(text: $0) }
                    if post.tags.count > 4 { Text("+\(post.tags.count - 4)").font(.caption2).foregroundStyle(.white.opacity(0.7)) }
                }
                .padding(.top, 2)
            }
            HStack(spacing: 12) {
                Label("\(post.replies.count)", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
                if let rid = post.acceptedReplyID,
                   post.replies.contains(where: {$0.id == rid}) {
                    Label("Löst", systemImage: "checkmark.seal.fill")
                        .font(.caption).foregroundStyle(.green.opacity(0.9))
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .glassCard(22)
    }
    
    private var lockBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
            Text("Låst")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.yellow)
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(Color.yellow.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.yellow.opacity(0.35), lineWidth: 1))
    }
    
    private var solvedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
            Text("Löst")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.green)
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(Color.green.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.green.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Tråddetalj

fileprivate struct PostDetailView: View {
    @Binding var post: ForumPost
    @Binding var currentUser: ForumUser
    
    var acceptAction: (UUID) -> Void
    var replyAction: (String) -> Void
    
    @State private var replyText: String = ""
    @FocusState private var replyFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                bodyCard
                if let first = post.replies.first, first.isAccepted {
                    acceptedCard(reply: first)
                }
                replies
                composer
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true) // dölj system-back
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Forum")
                    }
                    .font(.headline.weight(.semibold))
                }
            }
        }
        .background(
            LinearGradient(colors: [Color.black.opacity(0.02), Color.black.opacity(0.08)], startPoint: .top, endPoint: .bottom)
        )
    }
    
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            AvatarView(emoji: post.author.avatarEmoji, imageData: post.author.avatarImageData)
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(post.author.displayName) • \(post.createdAt.relativeSV())")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            if post.isLocked {
                Label("Låst", systemImage: "lock.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.yellow)
            } else if post.acceptedReplyID != nil {
                Label("Löst", systemImage: "checkmark.seal.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .glassCard(24)
    }
    
    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(post.body)
                .font(.body)
                .foregroundStyle(.white.opacity(0.92))
            if !post.tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(post.tags, id: \.self) { TagChip(text: $0) }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .glassCard(22)
    }
    
    private func acceptedCard(reply: ForumReply) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.title3)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Accepterat svar").font(.headline.weight(.semibold)).foregroundStyle(.green)
                    Spacer()
                    Text(reply.createdAt.relativeSV()).font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                HStack(spacing: 8) {
                    AvatarView(emoji: reply.author.avatarEmoji, imageData: reply.author.avatarImageData)
                    Text(reply.author.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                }
                Text(reply.text)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .glassCard(22)
    }
    
    private var replies: some View {
        let list = (post.replies.first?.isAccepted == true)
        ? Array(post.replies.dropFirst())
        : post.replies
        
        return VStack(alignment: .leading, spacing: 12) {
            if list.isEmpty {
                Text("Inga svar ännu – var först!").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    .padding(16)
                    .glassCard(18)
            } else {
                ForEach(list) { reply in
                    ReplyRow(reply: reply,
                             canAccept: post.author.id == currentUser.id && !post.isLocked && !reply.isAccepted,
                             onAccept: { acceptAction(reply.id) })
                }
            }
        }
    }
    
    private var composer: some View {
        VStack(spacing: 10) {
            if post.isLocked {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                    Text("Tråden är låst. Nya svar är avstängda.")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)
                .padding(14)
                .glassCard(18)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Skriv ett svar").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $replyText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 110)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .focused($replyFocused)
                        if replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Ditt svar…")
                                .foregroundStyle(.white.opacity(0.35))
                                .padding(.top, 16).padding(.leading, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    HStack {
                        Spacer()
                        Button {
                            let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            replyAction(text)
                            replyText = ""
                            replyFocused = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                Text("Skicka")
                            }
                            .font(.headline.weight(.semibold))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(brandGradient)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(14)
                .glassCard(18)
            }
        }
        .padding(.top, 8)
    }
}

fileprivate struct ReplyRow: View {
    var reply: ForumReply
    var canAccept: Bool
    var onAccept: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            AvatarView(emoji: reply.author.avatarEmoji, imageData: reply.author.avatarImageData)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(reply.author.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(reply.createdAt.relativeSV()).font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Text(reply.text)
                    .foregroundStyle(.white.opacity(0.92))
                HStack {
                    if reply.isAccepted {
                        Label("Accepterat svar", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(Color.green.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.green.opacity(0.35), lineWidth: 1))
                    } else if canAccept {
                        Button(action: onAccept) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal")
                                Text("Markera som perfekt")
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .glassCard(18)
    }
}

// MARK: - Fullscreen "Ny tråd"

fileprivate struct NewPostSheet: View {
    var onCreate: (_ title: String, _ body: String, _ tags: [String]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var contentText: String = ""
    @State private var tagsCSV: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(#colorLiteral(red: 0.08, green: 0.1, blue: 0.2, alpha: 1)),
                                        Color(#colorLiteral(red: 0.05, green: 0.07, blue: 0.12, alpha: 1))],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Group {
                            LabeledContent("Titel") {
                                TextField("Kort och tydlig titel…", text: $title)
                                    .textInputAutocapitalization(.sentences)
                                    .foregroundStyle(.white)
                            }
                            .tint(.white)
                            .padding(14)
                            .glassCard(18)
                            
                            Text("Innehåll")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            TextEditor(text: $contentText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 220)
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.25), lineWidth: 1))
                            
                            LabeledContent("Taggar") {
                                TextField("t.ex. SwiftUI, Design", text: $tagsCSV)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(.white)
                            }
                            .tint(.white)
                            .padding(14)
                            .glassCard(18)
                            
                            Text("Tips: separera taggar med kommatecken.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Ny tråd")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Stäng", systemImage: "xmark")
                            .labelStyle(.titleAndIcon)
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let tags = tagsCSV
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        onCreate(title, contentText, tags)
                        dismiss()
                    } label: {
                        Text("Skapa")
                            .font(.headline.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(brandGradient)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Avatar Picker Overlay (Popup)

fileprivate struct AvatarPickerOverlay: View {
    @Binding var isPresented: Bool
    @Binding var user: ForumUser
    
    @State private var mode: Mode = .emoji
    @State private var selectedEmoji: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var workingImageData: Data?
    
    enum Mode: String, CaseIterable, Identifiable {
        case emoji = "Emoji"
        case photo = "Bild"
        var id: String { rawValue }
    }
    
    private let emojiChoices: [String] = "😀😃😄😁😆🥹😊🙂😉😍😘😜🤓😎🥳🤩🤖👽👻💡🔥✨⚡️🌈🌙⭐️☀️🍀🌸🌊🐯🦊🐼🐵🦄🐶🐱🐨🐸🎧🎮💎🛠️🧭🧪🧠💬📱💻🎨🧵🧩🚀"
        .map { String($0) }
    
    var body: some View {
        ZStack {
            // Dim + klick för att stänga
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 46, height: 5)
                    .padding(.top, 10)
                    .opacity(0.8)
                
                Text("Välj avatar")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 4)
                
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                
                // Förhandsvisning
                HStack(spacing: 12) {
                    AvatarView(emoji: user.avatarEmoji, imageData: user.avatarImageData, size: 56)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(6)
                        }
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.white.opacity(0.6))
                    AvatarView(emoji: previewEmoji, imageData: previewImageData, size: 56)
                }
                .padding(.vertical, 4)
                
                Group {
                    if mode == .emoji {
                        ScrollView(.vertical, showsIndicators: false) {
                            let columns = [GridItem(.adaptive(minimum: 44), spacing: 10)]
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(emojiChoices, id: \.self) { e in
                                    Text(e)
                                        .font(.system(size: 24))
                                        .frame(width: 48, height: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(e == previewEmoji ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity( e == previewEmoji ? 0.45 : 0.2), lineWidth: 1)
                                        )
                                        .onTapGesture {
                                            selectedEmoji = e
                                            workingImageData = nil
                                        }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 6)
                        }
                        .frame(maxHeight: 240)
                    } else {
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $photoItem, matching: .images, preferredItemEncoding: .automatic) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text("Välj bild från Bilder")
                                        .font(.headline.weight(.semibold))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(brandGradient)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                            }
                            .onChange(of: photoItem) { _, newItem in
                                Task {
                                    if let item = newItem,
                                       let data = try? await item.loadTransferable(type: Data.self) {
                                        await MainActor.run {
                                            self.workingImageData = data
                                            self.selectedEmoji = ""
                                        }
                                    }
                                }
                            }
                            
                            if let data = workingImageData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.25), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                                    .padding(.top, 4)
                            } else {
                                Text("Ingen bild vald ännu.")
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            
                            if user.avatarImageData != nil {
                                Button(role: .destructive) {
                                    workingImageData = nil
                                    selectedEmoji = user.avatarEmoji
                                } label: {
                                    Label("Ta bort nuvarande bild", systemImage: "trash")
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color.red.opacity(0.12))
                                        .foregroundStyle(.red)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.red.opacity(0.35), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                    }
                }
                
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                            isPresented = false
                        }
                    } label: {
                        Text("Avbryt")
                            .font(.headline)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button {
                        if mode == .emoji, !previewEmoji.isEmpty {
                            user.avatarEmoji = previewEmoji
                            user.avatarImageData = nil
                        } else if mode == .photo, let data = previewImageData {
                            user.avatarImageData = data
                        }
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                            isPresented = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Spara")
                        }
                        .font(.headline.weight(.semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 18, x: 0, y: 12)
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: 520)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: 18)
            .padding(.horizontal, 16)
        }
    }
    
    private var previewEmoji: String {
        if mode == .emoji {
            return selectedEmoji.isEmpty ? user.avatarEmoji : selectedEmoji
        } else {
            return user.avatarEmoji
        }
    }
    private var previewImageData: Data? {
        if mode == .photo {
            return workingImageData ?? user.avatarImageData
        } else {
            return user.avatarImageData
        }
    }
}

// MARK: - Preview

#Preview("Forum – Supersnyggt") {
    NavigationStack {
        ForumView()
            .preferredColorScheme(.dark)
    }
}
