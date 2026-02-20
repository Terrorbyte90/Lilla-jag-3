//
//  SocialView.swift
//  MentalWellnessApp
//
//  Skapad av Ted 2025‑07‑30
//  EN (1) FIL som innehåller HELA den sociala modulen:
//  ‑ 5 flikar: Profil • Meddelanden • Flöde • Utforska • Humör
//  ‑ Lokal JSON‑lagring (Application Support)
//  ‑ Diagnosväljare med 15 vanligaste diagnoserna
//  ‑ Full funktionalitet utan ContentView eller @main‑entré
//

import SwiftUI
import Combine
import PhotosUI
import UIKit

// ------------------------------------------------------------
// MARK: 1. Datamodeller
// ------------------------------------------------------------

struct SocialMood: Identifiable, Codable, Equatable {
    let id: UUID
    let rating: Int          // 1–10
    let note: String
    let date: Date
}

struct SocialStatus: Identifiable, Codable, Equatable {
    let id: UUID
    let authorID: UUID
    var text: String
    var imageData: Data?
    let created: Date
}

struct SocialMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let senderID: UUID
    let content: String
    let created: Date
}

struct SocialConversation: Identifiable, Codable {
    let id: UUID
    let participantIDs: [UUID]          // alltid två
    var messages: [SocialMessage]
    var recipientHasAccepted: Bool
}

struct SocialUser: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var age: Int
    var location: String
    var diagnoses: [String]
    var experience: String
    var isMentor: Bool
    var avatarData: Data?
    var created: Date
    var statuses: [SocialStatus]
    var moods: [SocialMood]
    
    static var empty: SocialUser {
        .init(id: UUID(),
              name: "",
              age: 18,
              location: "",
              diagnoses: [],
              experience: "",
              isMentor: false,
              avatarData: nil,
              created: Date(),
              statuses: [],
              moods: [])
    }
}

// ------------------------------------------------------------
// MARK: 2. Persistens
// ------------------------------------------------------------

actor SocialStorage {
    static let shared = SocialStorage()
    private let usersURL: URL
    private let convURL: URL
    
    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir,
                                                 withIntermediateDirectories: true)
        usersURL = dir.appendingPathComponent("social_users.json")
        convURL  = dir.appendingPathComponent("social_conversations.json")
    }
    
    func loadUsers() -> [SocialUser] {
        guard let data = try? Data(contentsOf: usersURL) else { return [] }
        return (try? JSONDecoder().decode([SocialUser].self, from: data)) ?? []
    }
    func loadConvs() -> [SocialConversation] {
        guard let data = try? Data(contentsOf: convURL) else { return [] }
        return (try? JSONDecoder().decode([SocialConversation].self, from: data)) ?? []
    }
    func save(users: [SocialUser]) {
        if let d = try? JSONEncoder().encode(users) {
            try? d.write(to: usersURL, options: .atomic)
        }
    }
    func save(convs: [SocialConversation]) {
        if let d = try? JSONEncoder().encode(convs) {
            try? d.write(to: convURL, options: .atomic)
        }
    }
}

// ------------------------------------------------------------
// MARK: 3. Huvudmodell
// ------------------------------------------------------------

@MainActor
final class SocialModel: ObservableObject {
    @Published private(set) var users: [SocialUser] = []
    @Published private(set) var conversations: [SocialConversation] = []
    @Published var currentUserID: UUID?
    
    init() { Task { await load() } }
    
    // Ladda / Spara
    func load() async {
        users         = await SocialStorage.shared.loadUsers()
        conversations = await SocialStorage.shared.loadConvs()
    }
    private func saveUsers() { Task { await SocialStorage.shared.save(users: users) } }
    private func saveConvs() { Task { await SocialStorage.shared.save(convs: conversations) } }
    
    // MARK: Profil
    func save(profile: SocialUser) {
        if let idx = users.firstIndex(where: { $0.id == profile.id }) {
            users[idx] = profile
        } else {
            users.append(profile)
            currentUserID = profile.id
        }
        saveUsers()
    }
    func me() -> SocialUser? { users.first { $0.id == currentUserID } }
    
    // MARK: Status
    func postStatus(text: String, image: UIImage?) {
        guard var me = me() else { return }
        let st = SocialStatus(id: UUID(),
                              authorID: me.id,
                              text: text,
                              imageData: image?.jpegData(compressionQuality: 0.8),
                              created: Date())
        me.statuses.insert(st, at: 0)
        save(profile: me)
    }
    var globalFeed: [SocialStatus] {
        users.flatMap { Array($0.statuses.prefix(5)) }
            .sorted { $0.created > $1.created }
            .prefix(100).map { $0 }
    }
    
    // MARK: Humör
    func addMood(rating: Int, note: String) {
        guard var me = me() else { return }
        me.moods.insert(.init(id: UUID(), rating: rating, note: note, date: Date()), at: 0)
        save(profile: me)
    }
    
    // MARK: Konversationer
    private func convWith(_ other: UUID) -> SocialConversation {
        if let c = conversations.first(where: { Set($0.participantIDs) == Set([other, currentUserID!]) }) {
            return c
        }
        let c = SocialConversation(id: UUID(),
                                   participantIDs: [other, currentUserID!],
                                   messages: [],
                                   recipientHasAccepted: false)
        conversations.append(c); saveConvs(); return c
    }
    func send(to other: UUID, text: String) {
        guard let meID = currentUserID else { return }
        var c = convWith(other)
        c.messages.append(.init(id: UUID(), senderID: meID, content: text, created: Date()))
        update(c)
    }
    func accept(_ c: SocialConversation) { var c = c; c.recipientHasAccepted = true; update(c) }
    private func update(_ c: SocialConversation) {
        if let idx = conversations.firstIndex(where: { $0.id == c.id }) {
            conversations[idx] = c; saveConvs()
        }
    }
}

// ------------------------------------------------------------
// MARK: 4. Gränssnitt
// ------------------------------------------------------------

struct SocialView: View {
    @StateObject private var model = SocialModel()
    private let gradient = LinearGradient(colors: [.purple, .blue],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
    var body: some View {
        TabView {
            SocialProfileView().environmentObject(model)
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
            SocialMessageHub().environmentObject(model)
                .tabItem { Label("Medd.", systemImage: "bubble.left.and.bubble.right") }
            SocialFeedView().environmentObject(model)
                .tabItem { Label("Flöde", systemImage: "sparkles") }
            SocialExploreView().environmentObject(model)
                .tabItem { Label("Utforska", systemImage: "magnifyingglass.circle") }
            SocialMoodView().environmentObject(model)
                .tabItem { Label("Humör", systemImage: "face.smiling") }
        }
        .background(gradient.ignoresSafeArea())
        .tint(.white)
    }
}

// ------------------------------------------------------------
// MARK: Flöde
// ------------------------------------------------------------

struct SocialFeedView: View {
    @EnvironmentObject var model: SocialModel
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(model.globalFeed) { SocialStatusCard(status: $0) }
                }
                .padding()
            }
            .navigationTitle("Senaste inlägg")
        }
    }
}

struct SocialStatusCard: View {
    let status: SocialStatus
    @EnvironmentObject var model: SocialModel
    var author: SocialUser? { model.users.first { $0.id == status.authorID } }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SocialAvatar(data: author?.avatarData)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading) {
                    Text(author?.name ?? "Okänd").bold()
                    Text(status.created.formatted(date: .numeric, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(status.text)
            if let d = status.imageData, let img = UIImage(data: d) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(maxHeight: 300).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// ------------------------------------------------------------
// MARK: Profil
// ------------------------------------------------------------

struct SocialProfileView: View {
    @EnvironmentObject var model: SocialModel
    @State private var draft = SocialUser.empty
    @State private var pickedImage: UIImage?
    @State private var showPicker = false
    
    private let diagnoses = [
        "Depression","Bipolär sjukdom","GAD","Social ångest","Paniksyndrom",
        "OCD","PTSD","ADHD","Autism","Borderline/EIPS",
        "Ätstörning","Schizofreni","Hälsoångest","Specifik fobi","Dysmorfofobi"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SocialAvatar(data: draft.avatarData, placeholder: "person.crop.circle.badge.plus")
                    .frame(width: 120, height: 120)
                    .onTapGesture { showPicker = true }
                
                Group {
                    TextField("Namn", text: $draft.name)
                    Stepper("Ålder: \(draft.age)", value: $draft.age, in: 10...100)
                    TextField("Ort", text: $draft.location)
                    TextField("Beskriv din erfarenhet", text: $draft.experience)
                    Toggle("Kan vara mentor", isOn: $draft.isMentor)
                    // Diagnoser
                    VStack(alignment: .leading) {
                        Text("Diagnoser").bold()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(diagnoses, id: \.self) { d in
                                    Capsule()
                                        .fill(
                                            draft.diagnoses.contains(d)
                                            ? Color.accentColor
                                            : Color(.secondarySystemBackground)
                                        )
                                        .overlay(
                                            Text(d).font(.caption)
                                                .foregroundStyle(
                                                    draft.diagnoses.contains(d) ? .white : .primary
                                                )
                                        )
                                        .onTapGesture {
                                            if draft.diagnoses.contains(d) {
                                                draft.diagnoses.removeAll { $0 == d }
                                            } else { draft.diagnoses.append(d) }
                                        }
                                }
                            }
                        }
                    }
                }
                .textFieldStyle(.roundedBorder)
                
                Button("Spara profil") {
                    if draft.avatarData == nil, let img = pickedImage {
                        draft.avatarData = img.jpegData(compressionQuality: 0.8)
                    }
                    model.save(profile: draft)
                }
                .buttonStyle(.borderedProminent)
                
                Divider()
                
                // Skriva inlägg
                SocialStatusComposer { txt, img in
                    model.postStatus(text: txt, image: img)
                }
                
                ForEach(model.me()?.statuses ?? []) { SocialStatusCard(status: $0) }
            }
            .padding()
        }
        .onAppear { if let me = model.me() { draft = me } }
        .sheet(isPresented: $showPicker) { SocialPhotoPicker(image: $pickedImage) }
    }
}

// ------------------------------------------------------------
// MARK: Utforska (sök + mentorfilter)
// ------------------------------------------------------------

struct SocialExploreView: View {
    @EnvironmentObject var model: SocialModel
    @State private var query = ""
    @State private var showMentorsOnly = false
    
    var filtered: [SocialUser] {
        model.users.filter { user in
            (!showMentorsOnly || user.isMentor) &&
            (query.isEmpty || user.name.localizedCaseInsensitiveContains(query))
        }
        .sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Toggle("Visa bara mentorer", isOn: $showMentorsOnly)
                ForEach(filtered) { u in
                    NavigationLink {
                        SocialPublicProfile(user: u)
                    } label: {
                        HStack {
                            SocialAvatar(data: u.avatarData).frame(width: 40, height: 40)
                            VStack(alignment: .leading) {
                                Text(u.name.isEmpty ? "Namnlös" : u.name)
                                if u.isMentor { Text("Mentor").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Utforska")
            .searchable(text: $query, prompt: "Sök användare")
        }
    }
}

struct SocialPublicProfile: View {
    let user: SocialUser
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SocialAvatar(data: user.avatarData).frame(width: 120, height: 120)
                Text(user.name.isEmpty ? "Namnlös" : user.name).font(.title2).bold()
                if !user.diagnoses.isEmpty {
                    Text("Diagnoser: " + user.diagnoses.joined(separator: ", "))
                }
                if user.isMentor { Text("🌟 Mentor").bold() }
                
                Divider()
                ForEach(user.statuses) { SocialStatusCard(status: $0) }
            }
            .padding()
        }
        .navigationTitle("Profil")
    }
}

// ------------------------------------------------------------
// MARK: Meddelanden
// ------------------------------------------------------------

struct SocialMessageHub: View {
    @EnvironmentObject var model: SocialModel
    var body: some View {
        NavigationStack {
            List {
                ForEach(model.conversations) { c in
                    if let other = c.participantIDs.first(where: { $0 != model.currentUserID }),
                       let user = model.users.first(where: { $0.id == other }) {
                        NavigationLink {
                            SocialConversationView(convID: c.id, otherID: other)
                        } label: {
                            HStack {
                                SocialAvatar(data: user.avatarData).frame(width: 40, height: 40)
                                VStack(alignment: .leading) {
                                    Text(user.name.isEmpty ? "Namnlös" : user.name)
                                    if let last = c.messages.last {
                                        Text(last.content).font(.caption)
                                            .lineLimit(1).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if !c.recipientHasAccepted {
                                    Text("Väntar").font(.caption2).foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Meddelanden")
        }
    }
}

struct SocialConversationView: View {
    @EnvironmentObject var model: SocialModel
    let convID: UUID
    let otherID: UUID
    @State private var draft = ""
    
    var conv: SocialConversation? {
        model.conversations.first { $0.id == convID }
    }
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(conv?.messages ?? []) { SocialBubble(msg: $0) }
                    }
                    .onChange(of: conv?.messages.count) { _ in
                        if let last = conv?.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            if conv?.recipientHasAccepted == true {
                HStack {
                    TextField("Skriv...", text: $draft)
                    Button("Skicka") {
                        model.send(to: otherID, text: draft)
                        draft = ""
                    }
                }
                .padding().background(.ultraThinMaterial)
            } else {
                Button("Godkänn & svara") { if let c = conv { model.accept(c) } }
                    .padding()
            }
        }
        .navigationTitle("Samtal")
        .padding(.horizontal)
    }
}

struct SocialBubble: View {
    @EnvironmentObject var model: SocialModel
    let msg: SocialMessage
    var isMe: Bool { msg.senderID == model.currentUserID }
    
    var body: some View {
        HStack {
            if isMe { Spacer() }
            Text(msg.content)
                .padding(8)
                .background(isMe ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3))
                .foregroundStyle(isMe ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if !isMe { Spacer() }
        }
    }
}

// ------------------------------------------------------------
// MARK: Humör‑logg
// ------------------------------------------------------------

struct SocialMoodView: View {
    @EnvironmentObject var model: SocialModel
    @State private var rating = 5
    @State private var note = ""
    
    var moods: [SocialMood] { model.me()?.moods ?? [] }
    var average: Double {
        guard !moods.isEmpty else { return 0 }
        return Double(moods.map { $0.rating }.reduce(0, +)) / Double(moods.count)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Lägg till nytt humör
                VStack(spacing: 8) {
                    Stepper("Humör: \(rating)", value: $rating, in: 1...10)
                    TextField("Kommentar (frivilligt)", text: $note)
                        .textFieldStyle(.roundedBorder)
                    Button("Spara") {
                        model.addMood(rating: rating, note: note)
                        note = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                Divider()
                
                if !moods.isEmpty {
                    Text("Genomsnitt: \(average, specifier: "%.1f")").bold()
                    List {
                        ForEach(moods) { m in
                            VStack(alignment: .leading) {
                                Text("Humör: \(m.rating)")
                                if !m.note.isEmpty { Text(m.note).font(.caption) }
                                Text(m.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    Text("Ingen humördata ännu.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Humör")
        }
    }
}

// ------------------------------------------------------------
// MARK: Hjälpkomponenter
// ------------------------------------------------------------

struct SocialAvatar: View {
    var data: Data?
    var placeholder: String = "person.circle"
    var body: some View {
        Group {
            if let d = data, let img = UIImage(data: d) {
                Image(uiImage: img).resizable().scaledToFill()
            } else { Image(systemName: placeholder).resizable().scaledToFit() }
        }
        .clipShape(Circle())
    }
}

struct SocialStatusComposer: View {
    @State private var text = ""
    @State private var img: UIImage?
    @State private var show = false
    var submit: (String, UIImage?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $text).frame(height: 100)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary))
            if let ui = img {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            HStack {
                Button("Bild") { show = true }
                Spacer()
                Button("Publicera") {
                    submit(text, img); text = ""; img = nil
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && img == nil)
            }
        }
        .sheet(isPresented: $show) { SocialPhotoPicker(image: $img) }
    }
}

struct SocialPhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(); cfg.filter = .images; cfg.selectionLimit = 1
        let p = PHPickerViewController(configuration: cfg); p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: SocialPhotoPicker; init(_ p: SocialPhotoPicker) { parent = p }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let it = results.first?.itemProvider, it.canLoadObject(ofClass: UIImage.self) else { return }
            it.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                Task { @MainActor in self?.parent.image = obj as? UIImage }
            }
        }
    }
}

// ------------------------------------------------------------
// MARK: Preview
// ------------------------------------------------------------

struct SocialView_Previews: PreviewProvider {
    static var previews: some View {
        SocialView().preferredColorScheme(.dark)
    }
}
