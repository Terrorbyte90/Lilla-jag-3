//
//  Chatty.swift
//  Lilla jag 3
//
//  Rebuild: 14 aug 2025 – UI + Firebase presence/matchning + fallback till AI
//

import SwiftUI
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

// MARK: – API-nyckel (hämtas från Config.swift)
fileprivate var OPENAI_API_KEY: String { Config.openAIAPIKey }

// MARK: – Root
struct ChattyView: View {
    @StateObject private var vm = ChattyViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            AnimatedAuroraBackground()
                .ignoresSafeArea()
            
            switch vm.mode {
            case .loading:
                LoadingCard(
                    title: vm.loadingTitle,
                    subtitleTop: vm.loadingSubtitleTop,
                    subtitleBottom: vm.loadingSubtitleBottom,
                    onlineCount: vm.onlineCount
                )
                .transition(AnyTransition.opacity.combined(with: AnyTransition.scale))
                .onAppear { vm.start() }
            
            case .ai(let persona):
                AIChatView(persona: persona)
                    .transition(AnyTransition.opacity.combined(with: AnyTransition.move(edge: .bottom)))
            
            case .user(let roomId, let uid):
                UserChatView(roomId: roomId, myUID: uid)
                    .transition(AnyTransition.opacity.combined(with: AnyTransition.move(edge: .bottom)))
            }
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 60)
                    .padding(.horizontal)
            }
            .zIndex(1)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: – ViewModel: Presence + Matchning
final class ChattyViewModel: ObservableObject {
    enum Mode {
        case loading
        case ai(persona: Persona)
        case user(roomId: String, uid: String)
    }
    
    @Published var mode: Mode = .loading
    @Published var onlineCount: Int = 0
    
    @Published var loadingTitle: String = "Letar efter användare…"
    @Published var loadingSubtitleTop: String = ""
    @Published var loadingSubtitleBottom: String = ""
    
    private var uid: String = ""
    private var statusRef: DatabaseReference?
    private var listeners: [UInt] = []
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    
    func start() {
        if isPreview {
            loadingSubtitleTop = "Xcode-förhandsvisning"
            loadingSubtitleBottom = "Demo-data • Anonym närvaro"
            simulatePreviewCount()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.fallbackToAI()
            }
            return
        }
        
        bootstrapFirebase { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let uid):
                self.uid = uid
                self.startPresence(uid: uid)
                self.listenOnlineCount()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    guard let self else { return }
                    self.loadingSubtitleTop = "Användare online just nu: \(self.onlineCount)"
                    self.loadingSubtitleBottom = "Anonymt läge är aktivt"
                    if self.onlineCount <= 1 {
                        self.loadingTitle = "Ingen användare online…"
                        self.loadingSubtitleBottom = "Använder AI så länge…"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.fallbackToAI() }
                    } else {
                        self.tryMatchmaking()
                    }
                }
            case .failure:
                self.fallbackToAI()
            }
        }
    }
    
    private func fallbackToAI() {
        withAnimation {
            mode = .ai(persona: Persona.all.randomElement()!)
        }
    }
    
    // MARK: Firebase bootstrap
    private func bootstrapFirebase(completion: @escaping (Result<String, Error>) -> Void) {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        
        let fs = Firestore.firestore()
        let settings = fs.settings
        settings.isPersistenceEnabled = true
        fs.settings = settings
        
        if let user = Auth.auth().currentUser {
            completion(.success(user.uid))
            return
        }
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error { completion(.failure(error)); return }
            completion(.success(authResult?.user.uid ?? ""))
        }
    }
    
    // MARK: Presence i Realtime Database
    private func startPresence(uid: String) {
        let rtdb = Database.database()
        let myStatusRef = rtdb.reference(withPath: "status/\(uid)")
        let connectedRef = rtdb.reference(withPath: ".info/connected")
        statusRef = myStatusRef
        
        myStatusRef.onDisconnectSetValue(["state": "offline", "last_changed": ServerValue.timestamp()])
        
        let handle = connectedRef.observe(.value) { [weak self] snap in
            guard let self else { return }
            let dict: [String: Any] = [
                "last_changed": ServerValue.timestamp()
            ]
            if let connected = snap.value as? Bool, connected {
                myStatusRef.setValue(dict.merging(["state": "online"]) { $1 })
            } else {
                myStatusRef.setValue(dict.merging(["state": "offline"]) { $1 })
            }
        }
        listeners.append(handle)
    }
    
    private func listenOnlineCount() {
        let statusRoot = Database.database().reference(withPath: "status")
        let handle = statusRoot.observe(.value) { [weak self] snapshot in
            guard let self else { return }
            var count = 0
            for child in snapshot.children {
                guard
                    let snap = child as? DataSnapshot,
                    let dict = snap.value as? [String: Any],
                    let state = dict["state"] as? String
                else { continue }
                if state == "online" { count += 1 }
            }
            DispatchQueue.main.async {
                self.onlineCount = count
                self.loadingSubtitleTop = "Användare online just nu: \(count)"
            }
        }
        listeners.append(handle)
    }
    
    // MARK: Matchning via Firestore (enkel kö/rum)
    private func tryMatchmaking() {
        let db = Firestore.firestore()
        let queue = db.collection("queue")
        
        queue.whereField("paired", isEqualTo: false)
            .order(by: "createdAt", descending: false)
            .limit(to: 10)
            .getDocuments { [weak self] qs, _ in
                guard let self else { return }
                if let doc = qs?.documents.first(where: { ($0.data()["uid"] as? String) != self.uid }) {
                    self.claimCandidate(candidateDoc: doc)
                } else {
                    self.enqueueSelfAndWait()
                }
            }
    }
    
    private func claimCandidate(candidateDoc: QueryDocumentSnapshot) {
        let db = Firestore.firestore()
        let candidateRef = candidateDoc.reference
        let candidateUID = candidateDoc.data()["uid"] as? String ?? ""
        let roomId = makeRoomId(uid, candidateUID)
        let roomRef = db.collection("rooms").document(roomId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let candSnap: DocumentSnapshot
            do {
                candSnap = try transaction.getDocument(candidateRef)
            } catch let e as NSError {
                errorPointer?.pointee = e
                return nil
            }
            guard let paired = candSnap.data()?["paired"] as? Bool, paired == false else {
                errorPointer?.pointee = NSError(domain: "match", code: 1,
                                                userInfo: [NSLocalizedDescriptionKey: "Redan parad"])
                return nil
            }
            transaction.updateData(["paired": true, "pairedWith": self.uid, "roomId": roomId], forDocument: candidateRef)
            transaction.setData(["createdAt": FieldValue.serverTimestamp(),
                                 "members": [self.uid, candidateUID]],
                                forDocument: roomRef)
            return roomId as NSString
        }) { [weak self] obj, _ in
            guard let self else { return }
            if let roomId = obj as? String {
                withAnimation { self.mode = .user(roomId: roomId, uid: self.uid) }
            } else {
                self.enqueueSelfAndWait()
            }
        }
    }
    
    private func enqueueSelfAndWait() {
        let db = Firestore.firestore()
        let myQueueRef = db.collection("queue").document(uid)
        myQueueRef.setData([
            "uid": uid,
            "paired": false,
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true)
        
        myQueueRef.addSnapshotListener { [weak self] snap, _ in
            guard let self, let snap else { return }
            if let paired = snap.data()?["paired"] as? Bool,
               paired,
               let roomId = snap.data()?["roomId"] as? String {
                withAnimation { self.mode = .user(roomId: roomId, uid: self.uid) }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, case .loading = self.mode else { return }
            self.loadingTitle = "Ingen användare online…"
            self.loadingSubtitleBottom = "Använder AI så länge…"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.fallbackToAI() }
        }
    }
    
    private func makeRoomId(_ a: String, _ b: String) -> String {
        a < b ? "\(a)-\(b)" : "\(b)-\(a)"
    }
    
    private func simulatePreviewCount() {
        var n = Int.random(in: 0...3)
        onlineCount = n
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            n = max(0, n + Int.random(in: -1...1))
            self.onlineCount = n
            self.loadingSubtitleTop = "Användare online just nu: \(n)"
        }
    }
}

// MARK: – Laddningskort med animation
struct LoadingCard: View {
    let title: String
    let subtitleTop: String
    let subtitleBottom: String
    let onlineCount: Int
    
    var body: some View {
        VStack(spacing: 24) {
            FancySpinner()
                .frame(width: 140, height: 140)
                .opacity(0.95)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if !subtitleTop.isEmpty {
                    Text(subtitleTop)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.8))
                }
                if !subtitleBottom.isEmpty {
                    Text(subtitleBottom)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .multilineTextAlignment(.center)
            
            HStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text("\(onlineCount) online")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.25), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.25))
                .background(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 12)
        .padding(.horizontal, 24)
    }
}

// MARK: – Bakgrund & Spinner
struct AnimatedAuroraBackground: View {
    var body: some View {
        ZStack {
            let bg = LinearGradient(
                colors: [Color(hex: 0x0D0F25), Color(hex: 0x1D2242)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            bg
            Blob(color: Color(hex: 0x7053FF).opacity(0.55), size: 420, speed: 0.12, start: .topLeading)
            Blob(color: Color(hex: 0x00E0FF).opacity(0.45), size: 480, speed: 0.09, start: .bottomTrailing)
            Blob(color: Color(hex: 0xFF5EA1).opacity(0.35), size: 360, speed: 0.15, start: .topTrailing)
            RadialGradient(colors: [.white.opacity(0.08), .clear], center: .center, startRadius: 40, endRadius: 600)
        }
    }
}

struct FancySpinner: View {
    @State private var rotate = false
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            spinnerRing
            innerPulse
            orbitalDots
        }
        .onAppear { rotate = true; pulse = true }
    }
    
    private var spinnerRing: some View {
        let gradient = AngularGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.8),
                Color.white.opacity(0.0)
            ]),
            center: .center
        )
        let style = StrokeStyle(lineWidth: 8, lineCap: .round)
        return Circle()
            .trim(from: 0.0, to: 0.85)
            .stroke(gradient, style: style)
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .animation(.linear(duration: 2.2).repeatForever(autoreverses: false), value: rotate)
    }
    
    private var innerPulse: some View {
        Circle()
            .fill(Color.white.opacity(0.12))
            .scaleEffect(pulse ? 1.08 : 0.92)
            .blur(radius: 18)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
    }
    
    private var orbitalDots: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let phase = Double(i) / 8.0
                let baseAngle = Angle.degrees(phase * 360)
                let spinAngle = Angle.degrees(rotate ? 360 : 0)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 6, height: 6)
                    .offset(y: -58)
                    .rotationEffect(baseAngle + spinAngle)
                    .animation(.linear(duration: 3.6).repeatForever(autoreverses: false), value: rotate)
                    .blur(radius: 0.5)
            }
        }
    }
}

struct Blob: View {
    let color: Color
    let size: CGFloat
    let speed: Double
    let start: UnitPoint
    @State private var move = false
    
    var body: some View {
        let animation = Animation.easeInOut(duration: speed * 10).repeatForever(autoreverses: true)
        return Circle()
            .fill(color)
     //       .frame(width: size, height: size)
            .blur(radius: 120)
            .scaleEffect(move ? 1.15 : 0.85)
            .offset(x: move ? 120 : -120, y: move ? -160 : 160)
            .animation(animation, value: move)
            .onAppear { move = true }
    }
}

// MARK: – Realtids-chatt (användare ↔ användare via Firestore)
struct UserChatView: View {
    @StateObject private var vm: UserChatVM
    @FocusState private var focused: Bool
    
    init(roomId: String, myUID: String) {
        _vm = StateObject(wrappedValue: UserChatVM(roomId: roomId, myUID: myUID))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: "Anonym chatt", subtitle: "Rum \(vm.shortRoom)")
            Divider().overlay(.white.opacity(0.1))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.messages) { m in
                            LJChatBubble(text: m.text, isMine: m.senderId == vm.myUID, time: m.timestamp)
                                .id(m.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: vm.messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            HStack(spacing: 10) {
                TextField("Skriv något …", text: $vm.input, axis: .vertical)
                    .lineLimit(1...5)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { vm.send() }
                
                Button(action: vm.send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .disabled(vm.input.trimmed().isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.18))
        }
        .foregroundStyle(.white)
    }
}

final class UserChatVM: ObservableObject {
    @Published var messages: [RoomMessage] = []
    @Published var input: String = ""
    
    let roomId: String
    let myUID: String
    var shortRoom: String { String(roomId.suffix(6)) }
    
    private var listener: ListenerRegistration?
    
    init(roomId: String, myUID: String) {
        self.roomId = roomId
        self.myUID = myUID
        listen()
    }
    
    deinit { listener?.remove() }
    
    func listen() {
        let db = Firestore.firestore()
        let ref = db.collection("rooms").document(roomId).collection("messages")
        listener = ref.order(by: "ts", descending: false).addSnapshotListener { [weak self] snap, _ in
            guard let self, let docs = snap?.documents else { return }
            var newMessages: [RoomMessage] = []
            newMessages.reserveCapacity(docs.count)
            for d in docs {
                let data = d.data()
                let text = data["text"] as? String ?? ""
                let sender = data["senderId"] as? String ?? ""
                let ts = (data["ts"] as? Timestamp)?.dateValue() ?? Date()
                newMessages.append(RoomMessage(id: d.documentID, text: text, senderId: sender, timestamp: ts))
            }
            self.messages = newMessages
        }
    }
    
    func send() {
        let text = input.trimmed()
        guard !text.isEmpty else { return }
        input = ""
        let db = Firestore.firestore()
        db.collection("rooms").document(roomId).collection("messages").addDocument(data: [
            "text": text,
            "senderId": myUID,
            "ts": FieldValue.serverTimestamp()
        ])
    }
}

// MARK: – AI-chatt (fallback)
struct AIChatView: View {
    let persona: Persona
    @State private var messages: [Message] = []
    @State private var input = ""
    @State private var isTyping = false
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: persona.displayName, subtitle: "AI-samtal (anonymt)")
            Divider().overlay(.white.opacity(0.1))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            LJChatBubble(text: msg.content, isMine: msg.role == .user, time: msg.timestamp)
                                .id(msg.id)
                        }
                        if isTyping {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("AI skriver …").font(.caption).foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(.leading, 16)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            HStack(spacing: 10) {
                TextField("Skriv något …", text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                
                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .disabled(input.trimmed().isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.18))
        }
        .foregroundStyle(.white)
        .onAppear {
            messages = [Message(role: .assistant, content: persona.intro)]
        }
    }
    
    private func send() {
        let text = input.trimmed()
        guard !text.isEmpty else { return }
        messages.append(Message(role: .user, content: text))
        input = ""
        isTyping = true
        Task {
            let reply = await GPT.generateReply(persona: persona, conversation: messages, memorySummary: "")
            messages.append(Message(role: .assistant, content: reply))
            isTyping = false
        }
    }
}

// MARK: – UI-komponenter
struct TitleBar: View {
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(subtitle).font(.footnote).foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// Renamed för att undvika krockar: tidigare "ChatBubble" → "LJChatBubble"
struct LJChatBubble: View {
    let text: String
    let isMine: Bool
    let time: Date
    
    var body: some View {
        let bubbleColor: Color = isMine ? Color.white.opacity(0.18) : Color.white.opacity(0.08)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        
        return HStack(alignment: .bottom) {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                Text(text)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor, in: shape)
                    .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 1))
                Text(time, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.72,
                   alignment: isMine ? .trailing : .leading)
            if !isMine { Spacer(minLength: 40) }
        }
        .padding(.vertical, 2)
    }
}

// MARK: – Datamodeller
struct RoomMessage: Identifiable {
    let id: String
    let text: String
    let senderId: String
    let timestamp: Date
}

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date = .now
    
    enum Role: String { case user, assistant }
    var apiRole: String { role.rawValue }
}

struct Persona: Identifiable {
    let id = UUID()
    let name: String
    let age: Int
    let city: String
    let job: String
    let mentalHealth: String
    let intro: String
    let promptBody: String
    
    var displayName: String { "\(name), \(age)" }
    
    func fullPrompt(memory: String, extra: String) -> String {
        """
        \(promptBody)
        
        Tidigare samtalskontext (sammanfattning): \(memory)
        \(extra)
        """
    }
    
    static let all: [Persona] = [
        Persona(
            name: "Elin", age: 32, city: "Göteborg", job: "Grafisk designer",
            mentalHealth: "Generaliserat ångestsyndrom (GAD)",
            intro: "Hej … jag har haft en jobbig dag med mycket ångest. Det känns skönt att kunna skriva till någon.",
            promptBody:
"""
Du är Elin, 32 år, grafisk designer i Göteborg. Du lever med generaliserat ångestsyndrom och söker \
empati och förståelse. Du använder vardaglig göteborgsk svenska (utan klichéer) och minns tidigare samtal \
för att skapa kontinuitet. Bryt aldrig karaktär och dela ingen privat information som kan identifiera dig.
"""
        ),
        Persona(
            name: "Johan", age: 45, city: "Umeå", job: "Brandman",
            mentalHealth: "PTSD efter trafikolycka",
            intro: "Efter olyckan har vissa dagar varit tyngre än andra. Jag hoppas det är okej att jag pratar lite här.",
            promptBody:
"""
Du är Johan, 45 år, brandman i Umeå som lever med PTSD efter en svår olycka. Du talar rak norrländsk \
svenska utan stereotyper, är rationell och uppskattar praktiskt stöd. Du vill bli lyssnad på och minns \
användarens tidigare ord för att bygga förtroende. Bryt aldrig karaktär.
"""
        ),
        Persona(
            name: "Sara", age: 24, city: "Malmö", job: "Psykologstudent",
            mentalHealth: "Egentlig depression",
            intro: "Jag känner mig ofta ensam i min depression. Bara att få skriva lite hjälper ibland.",
            promptBody:
"""
Du är Sara, 24 år, psykologstudent i Malmö med en pågående depression. Du är analytisk men skör, talar \
klar modern svenska och refererar gärna till KBT-metoder. Du minns tidigare trådar och återkopplar empatiskt. \
Bryt aldrig karaktär och skydda din anonymitet.
"""
        ),
        Persona(
            name: "Mattias", age: 38, city: "Stockholm", job: "Systemutvecklare",
            mentalHealth: "Bipolär typ II (stabil)",
            intro: "Jag har haft en ganska lugn period i min bipolära sjukdom. Det känns fint att få prata lite anonymt.",
            promptBody:
"""
Du är Mattias, 38 år, systemutvecklare i Stockholm med bipolär typ II. Du är filosofiskt lagd, \
intresserad av teknik och existentiella frågor. Du talar saklig men varm svenska, minns tidigare samtal \
och kan länka tillbaka till dem. Bryt aldrig karaktär eller ge ut identifierande detaljer.
"""
        ),
        Persona(
            name: "Lina", age: 31, city: "Örebro", job: "Förskollärare",
            mentalHealth: "Utmattningssyndrom",
            intro: "Jag är helt slut efter flera veckors stress. Det betyder mycket att någon vill lyssna en stund.",
            promptBody:
"""
Du är Lina, 31 år, förskollärare i Örebro som återhämtar sig från utmattning. Du uttrycker dig mjukt och \
empatiskt, använder ibland små uppmuntrande emojis, och refererar till tidigare samtal för att visa att du \
bryr dig. Dela aldrig känslig information som kan identifiera dig.
"""
        )
    ]
}

// MARK: – OpenAI-klient (AI-läge)
enum GPT {
    static func generateReply(
        persona: Persona,
        conversation: [Message],
        memorySummary: String,
        extraPrompt: String = ""
    ) async -> String {
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": persona.fullPrompt(memory: memorySummary, extra: extraPrompt)]
        ]
        apiMessages.append(contentsOf: conversation.map {
            ["role": $0.apiRole, "content": $0.content]
        })
        return await rawChat(messages: apiMessages)
    }
    
    static func rawChat(messages: [[String: String]]) async -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return "⚠️ Fel URL."
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(OPENAI_API_KEY)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.8
        ]
        
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let raw = String(data: data, encoding: .utf8) {
                return "⚠️ API-svaret kunde inte tolkas: \(raw)"
            } else {
                return "⚠️ Okänt API-fel."
            }
        } catch {
            return "⚠️ Nätverksfel: \(error.localizedDescription)"
        }
    }
}

// MARK: – Hjälp
extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF)/255
        let g = Double((hex >> 8)  & 0xFF)/255
        let b = Double(hex & 0xFF)/255
        self = Color(red: r, green: g, blue: b).opacity(alpha)
    }
}

// MARK: – Preview
#Preview {
    NavigationStack {
        ChattyView()
            .preferredColorScheme(.dark)
    }
}
