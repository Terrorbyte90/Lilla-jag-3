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
    @Environment(\.dismiss) private var dismiss
    private let gradient = LinearGradient(colors: [Color(hex: 0x0F1123), Color(hex: 0x171C38)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
    var body: some View {
        ZStack(alignment: .topLeading) {
            TabView {
                SocialFeedView().environmentObject(model)
                    .tabItem { Label("Flöde", systemImage: "sparkles") }
                SocialExploreView().environmentObject(model)
                    .tabItem { Label("Utforska", systemImage: "magnifyingglass.circle") }
                SocialMessageHub().environmentObject(model)
                    .tabItem { Label("Medd.", systemImage: "bubble.left.and.bubble.right") }
                SocialMoodView().environmentObject(model)
                    .tabItem { Label("Humör", systemImage: "face.smiling") }
                SocialProfileView().environmentObject(model)
                    .tabItem { Label("Profil", systemImage: "person.crop.circle") }
            }
            .background(gradient.ignoresSafeArea())
            .tint(.white)
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 60) // Extra padding för att inte krocka med Dynamic Island/Notch
                    .padding(.horizontal)
            }
            .zIndex(1)
        }
    }
}

// ------------------------------------------------------------
// MARK: Flöde
// ------------------------------------------------------------

struct SocialFeedView: View {
    @EnvironmentObject var model: SocialModel
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x0F1123), Color(hex: 0x171C38)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(model.globalFeed) { SocialStatusCard(status: $0) }
                        
                        if model.globalFeed.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("Flödet är tomt")
                                    .font(.headline)
                                Text("Bli den första att dela något!")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 100)
                        }
                    }
                    .padding()
                    .padding(.top, 40) // Plats för stäng-knapp
                }
            }
            .navigationTitle("Gemenskap")
            .toolbarBackground(.hidden, for: .navigationBar)
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
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(author?.name ?? "Anonym").font(.headline).foregroundStyle(.white)
                    Text(status.created.relativeSV())
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            }
            
            Text(status.text)
                .foregroundStyle(.white.opacity(0.9))
            
            if let d = status.imageData, let img = UIImage(data: d) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.white.opacity(0.05))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

fileprivate extension Date {
    func relativeSV() -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.unitsStyle = .short
        return f.localizedString(for: self, relativeTo: .now)
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
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x0F1123), Color(hex: 0x171C38)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar-sektion
                        VStack(spacing: 16) {
                            SocialAvatar(data: draft.avatarData, placeholder: "person.crop.circle.badge.plus")
                                .frame(width: 100, height: 100)
                                .background(.white.opacity(0.1), in: Circle())
                                .onTapGesture { showPicker = true }
                            
                            Text(draft.name.isEmpty ? "Din Profil" : draft.name)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 40)
                        
                        // Formulär
                        VStack(spacing: 20) {
                            ProfileField(label: "Namn", text: $draft.name, placeholder: "Ditt namn")
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ålder: \(draft.age)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white.opacity(0.7))
                                Stepper("", value: $draft.age, in: 10...100)
                                    .labelsHidden()
                                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ProfileField(label: "Ort", text: $draft.location, placeholder: "Var bor du?")
                            ProfileField(label: "Erfarenhet", text: $draft.experience, placeholder: "Kort om dig...")
                            
                            Toggle("Kan vara mentor", isOn: $draft.isMentor)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.7))
                                .padding()
                                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                            
                            // Diagnoser
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Mina utmaningar")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(diagnoses, id: \.self) { d in
                                            let isSelected = draft.diagnoses.contains(d)
                                            Text(d)
                                                .font(.caption.bold())
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(isSelected ? Color.blue : Color.white.opacity(0.1), in: Capsule())
                                                .foregroundStyle(.white)
                                                .onTapGesture {
                                                    if isSelected {
                                                        draft.diagnoses.removeAll { $0 == d }
                                                    } else {
                                                        draft.diagnoses.append(d)
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal)
                        
                        Button {
                            if draft.avatarData == nil, let img = pickedImage {
                                draft.avatarData = img.jpegData(compressionQuality: 0.8)
                            }
                            model.save(profile: draft)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Text("Spara profil")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal)
                        
                        Divider().background(.white.opacity(0.1)).padding()
                        
                        // Status Composer
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Dela en tanke")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            SocialStatusComposer { txt, img in
                                model.postStatus(text: txt, image: img)
                            }
                        }
                        .padding()
                        .background(.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal)
                        
                        // Egna inlägg
                        VStack(alignment: .leading, spacing: 16) {
                            if let myStatuses = model.me()?.statuses, !myStatuses.isEmpty {
                                Text("Mina inlägg")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal)
                                
                                ForEach(myStatuses) { SocialStatusCard(status: $0) }
                                    .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Profil")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear { if let me = model.me() { draft = me } }
        .sheet(isPresented: $showPicker) { SocialPhotoPicker(image: $pickedImage) }
    }
}

struct ProfileField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.7))
            TextField(placeholder, text: $text)
                .padding()
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
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
            ZStack {
                LinearGradient(colors: [Color(hex: 0x0F1123), Color(hex: 0x171C38)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter-sektion
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.5))
                            TextField("Sök efter medlemmar...", text: $query)
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        
                        Toggle("Visa endast mentorer", isOn: $showMentorsOnly)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 4)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { u in
                                NavigationLink {
                                    SocialPublicProfile(user: u)
                                } label: {
                                    HStack(spacing: 16) {
                                        SocialAvatar(data: u.avatarData)
                                            .frame(width: 50, height: 50)
                                            .background(.white.opacity(0.1), in: Circle())
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(u.name.isEmpty ? "Anonym" : u.name)
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                                
                                                if u.isMentor {
                                                    Image(systemName: "star.fill")
                                                        .font(.caption2)
                                                        .foregroundStyle(.yellow)
                                                }
                                            }
                                            
                                            if !u.diagnoses.isEmpty {
                                                Text(u.diagnoses.joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.5))
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                    .padding()
                                    .background(.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if filtered.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.3.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.white.opacity(0.2))
                                    Text("Inga medlemmar hittades")
                                        .font(.headline)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.top, 100)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Utforska")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct SocialPublicProfile: View {
    let user: SocialUser
    @EnvironmentObject var model: SocialModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0F1123), Color(hex: 0x171C38)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        SocialAvatar(data: user.avatarData)
                            .frame(width: 100, height: 100)
                            .background(.white.opacity(0.1), in: Circle())
                        
                        VStack(spacing: 4) {
                            Text(user.name.isEmpty ? "Anonym" : user.name)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            if user.isMentor {
                                Label("Mentor", systemImage: "star.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        if !user.diagnoses.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Utmaningar")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(user.diagnoses.joined(separator: ", "))
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        if !user.experience.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Erfarenhet")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(user.experience)
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        Button {
                            model.send(to: user.id, text: "Hej! Jag såg din profil och ville säga hej.")
                            // Här skulle vi kunna navigera till meddelanden
                        } label: {
                            Label("Skicka meddelande", systemImage: "bubble.left.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding()
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal)
                    
                    if !user.statuses.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Inlägg")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)
                            
                            ForEach(user.statuses) { SocialStatusCard(status: $0) }
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ------------------------------------------------------------
// MARK: Meddelanden
// ------------------------------------------------------------

struct SocialMessageHub: View {
    @EnvironmentObject var model: SocialModel
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x0F1123), Color(hex: 0x171C38)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.conversations) { c in
                            if let otherID = c.participantIDs.first(where: { $0 != model.currentUserID }),
                               let otherUser = model.users.first(where: { $0.id == otherID }) {
                                NavigationLink {
                                    SocialConversationView(convID: c.id, otherID: otherID)
                                } label: {
                                    HStack(spacing: 16) {
                                        SocialAvatar(data: otherUser.avatarData)
                                            .frame(width: 50, height: 50)
                                            .background(.white.opacity(0.1), in: Circle())
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(otherUser.name.isEmpty ? "Anonym" : otherUser.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            
                                            if let lastMsg = c.messages.last {
                                                Text(lastMsg.content)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.white.opacity(0.6))
                                                    .lineLimit(1)
                                            } else {
                                                Text("Inga meddelanden ännu")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.white.opacity(0.4))
                                                    .italic()
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if !c.recipientHasAccepted && c.messages.last?.senderID != model.currentUserID {
                                            Text("Ny förfrågan")
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.orange, in: Capsule())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding()
                                    .background(.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if model.conversations.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.2))
                                Text("Inga konversationer")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("Hitta vänner under Utforska!")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(.top, 100)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Meddelanden")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct SocialConversationView: View {
    @EnvironmentObject var model: SocialModel
    let convID: UUID
    let otherID: UUID
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss
    
    var conv: SocialConversation? {
        model.conversations.first { $0.id == convID }
    }
    
    var otherUser: SocialUser? {
        model.users.first { $0.id == otherID }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0F1123), Color(hex: 0x171C38)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(conv?.messages ?? []) { msg in
                                SocialBubble(msg: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding()
                        .onAppear {
                            if let last = conv?.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: conv?.messages.count) { _ in
                            if let last = conv?.messages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                if conv?.recipientHasAccepted == true || conv?.messages.last?.senderID == model.currentUserID {
                    HStack(spacing: 12) {
                        TextField("Skriv ett meddelande...", text: $draft)
                            .padding(12)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                            .foregroundStyle(.white)
                        
                        Button {
                            guard !draft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            model.send(to: otherID, text: draft)
                            draft = ""
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(draft.isEmpty ? Color.gray : Color.blue, in: Circle())
                        }
                        .disabled(draft.isEmpty)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                } else {
                    VStack(spacing: 16) {
                        Text("Vill du prata med \(otherUser?.name ?? "denna person")?")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        HStack(spacing: 20) {
                            Button("Avböj") {
                                dismiss()
                            }
                            .font(.headline)
                            .foregroundStyle(.red)
                            
                            Button("Godkänn & Svara") {
                                if let c = conv { model.accept(c) }
                            }
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue, in: Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .navigationTitle(otherUser?.name ?? "Samtal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SocialBubble: View {
    @EnvironmentObject var model: SocialModel
    let msg: SocialMessage
    var isMe: Bool { msg.senderID == model.currentUserID }
    
    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 60) }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(msg.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isMe ? Color.blue : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(.white)
                
                Text(msg.created.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 4)
            }
            
            if !isMe { Spacer(minLength: 60) }
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
            ZStack {
                LinearGradient(colors: [Color(hex: 0x0F1123), Color(hex: 0x171C38)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Logga nytt humör
                        VStack(spacing: 20) {
                            Text("Hur mår du just nu?")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 15) {
                                ForEach(1...5, id: \.self) { i in
                                    let val = i * 2
                                    Button {
                                        rating = val
                                    } label: {
                                        VStack(spacing: 8) {
                                            Text(emojiFor(val))
                                                .font(.system(size: 30))
                                            Text("\(val)")
                                                .font(.caption.bold())
                                                .foregroundStyle(rating == val ? .white : .white.opacity(0.5))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(rating == val ? Color.blue.opacity(0.3) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(rating == val ? Color.blue : Color.clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            TextField("Skriv en kort notering...", text: $note)
                                .padding()
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                            
                            Button {
                                model.addMood(rating: rating, note: note)
                                note = ""
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } label: {
                                Text("Spara mående")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding()
                        .background(.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        if !moods.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Historik")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("Snitt: \(average, specifier: "%.1f")")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal)
                                
                                ForEach(moods) { m in
                                    HStack(spacing: 16) {
                                        Text(emojiFor(m.rating))
                                            .font(.title2)
                                            .frame(width: 44, height: 44)
                                            .background(.white.opacity(0.1), in: Circle())
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            if !m.note.isEmpty {
                                                Text(m.note)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.white)
                                            }
                                            Text(m.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(m.rating)")
                                            .font(.headline)
                                            .foregroundStyle(.blue)
                                    }
                                    .padding()
                                    .background(.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .padding(.horizontal)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.2))
                                Text("Ingen historik ännu")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(.top, 40)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Mitt Mående")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
    
    private func emojiFor(_ val: Int) -> String {
        if val <= 2 { return "😔" }
        if val <= 4 { return "😐" }
        if val <= 6 { return "🙂" }
        if val <= 8 { return "😊" }
        return "😁"
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
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                
                if text.isEmpty {
                    Text("Vad tänker du på?")
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 16)
                        .padding(.leading, 12)
                        .allowsHitTesting(false)
                }
            }
            
            if let ui = img {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        img = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                    .padding(8)
                }
            }
            
            HStack {
                Button {
                    show = true
                } label: {
                    HStack {
                        Image(systemName: "photo")
                        Text("Bild")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1), in: Capsule())
                    .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button {
                    submit(text, img)
                    text = ""
                    img = nil
                } label: {
                    Text("Publicera")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(text.isEmpty && img == nil ? Color.gray : Color.blue, in: Capsule())
                        .foregroundStyle(.white)
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
