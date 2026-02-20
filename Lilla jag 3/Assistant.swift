//
//  Assistant.swift
//  Lilla jag 3
//
//  Skapad av Ted Svärd 2025-07-13
//  Reviderad 2025-08-14 – Swift 6 actor-fixar, iOS 17 mic-permission, kompakt UI som alltid får plats, default högtalare, BT/HFP-routning, stabilare WS/VAD
//

import SwiftUI
import AVKit
import AVFoundation
import AVFAudio
import Foundation
import OSLog

// MARK: – Global logg
final class AppLog: ObservableObject {
    static let shared = AppLog()
    @Published private(set) var entries: [String] = []

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func add(_ msg: String) {
        DispatchQueue.main.async {
            self.entries.append("[\(self.df.string(from: .init()))]  \(msg)")
            if self.entries.count > 1_000 { self.entries.removeFirst(self.entries.count - 1_000) }
        }
    }
}
@inline(__always) func log(_ m: String) { AppLog.shared.add(m) }

// MARK: – Logger
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "LillaJag3"
    static let audio = Logger(subsystem: subsystem, category: "audio")
}

// MARK: – API-nycklar (hämtas från Config.swift)
fileprivate let ELEVEN_AGENT_ID = Config.elevenLabsAgentID
fileprivate let ELEVEN_API_KEY  = Config.elevenLabsAPIKey

// MARK: – Färger
private extension Color {
    static let bgDeep = Color(red: 10/255, green: 12/255, blue: 22/255)
    static let bgDark = Color(red: 6/255, green: 7/255, blue: 16/255)
    static let neonBlue = Color(red: 72/255, green: 132/255, blue: 255/255)
    static let neonCyan = Color(red: 18/255, green: 214/255, blue: 255/255)
    static let glassStroke = Color.white.opacity(0.18)
    static let glassFill   = Color.white.opacity(0.08)
    static let titleWhite  = Color.white.opacity(0.98)
    static let subWhite    = Color.white.opacity(0.72)
}

// MARK: – UI-komponenter
private struct NioPrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(colors: [.neonBlue, .neonCyan],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .foregroundStyle(.white)
                .shadow(color: .neonBlue.opacity(0.35), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
    }
}

// Puls-cirkel
private struct NioListeningHalo: View {
    let active: Bool
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 170, height: 170)
                .blur(radius: 28)

            if active {
                Circle()
                    .strokeBorder(Color.neonCyan.opacity(0.55), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulse ? 1.14 : 0.86)
                    .opacity(pulse ? 0.0 : 1.0)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
                    .onAppear { pulse = true }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AssistantGlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.glassStroke, lineWidth: 1)
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.glassFill)
                    .blur(radius: 7)
            )
            .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 9)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: – Ram med pulserande cirkel (ersätter videon)
private struct FramedHalo: View {
    let active: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.glassStroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 9)
            NioListeningHalo(active: active)
        }
        .frame(height: 210)
    }
}

private struct AssistantBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgDeep, .bgDark], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            Circle()
                .fill(Color.purple.opacity(0.30))
                .frame(width: 420, height: 420)
                .blur(radius: 110)
                .offset(x: -140, y: -260)

            Circle()
                .fill(Color.blue.opacity(0.30))
                .frame(width: 460, height: 460)
                .blur(radius: 120)
                .offset(x: 120, y: -200)

            Circle()
                .fill(Color.cyan.opacity(0.26))
                .frame(width: 460, height: 460)
                .blur(radius: 120)
                .offset(x: 150, y: 220)
        }
    }
}

// MARK: – Loggvy
struct LogView: View {
    @ObservedObject var log = AppLog.shared
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            List(log.entries.reversed(), id: \.self) {
                Text($0).font(.system(size: 12, design: .monospaced))
            }
            .navigationTitle("Intern logg")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") { dismiss() }
                }
            }
        }
    }
}

// MARK: – Huvudvy (kompakt layout – säkert inom skärmen)
struct AssistantView: View {
    @StateObject private var vm = ConversationViewModel()
    @State private var showLog = false

    var body: some View {
        ZStack {
            AssistantBackground()
            // Centrera innehåll vertikalt; bakgrunden ignorerar safe area
            ScrollView {
                VStack(spacing: 16) {
                    Spacer(minLength: 40)
                    // Ersatt video → FramedHalo med pulserande cirkel
                    FramedHalo(active: vm.isActive && vm.agentConnected)

                    // Statuskort
                    AssistantGlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: (vm.isActive && vm.agentConnected) ? "checkmark.circle.fill" : "waveform.and.mic")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle((vm.isActive && vm.agentConnected) ? .green : .neonCyan)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text( (vm.isActive && vm.agentConnected) ? "Redo – samtal igång" :
                                          (vm.isActive ? "Startar samtal…" : "Nio är redo") )
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .minimumScaleFactor(0.8)
                                        .foregroundStyle(.white)
                                    Text( vm.isActive ? (vm.agentConnected ? "Lyssnar och svarar i realtid" : "Ansluter…")
                                          : "Tryck för att börja prata" )
                                        .font(.caption)
                                        .foregroundStyle(Color.subWhite)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer(minLength: 4)
                                Circle()
                                    .fill((vm.isActive && vm.agentConnected) ? .green : .red)
                                    .frame(width: 8, height: 8)
                                    .accessibilityLabel((vm.isActive && vm.agentConnected) ? "Ansluten" : "Ej ansluten")
                            }
                            NioPrimaryButton(title: vm.isActive ? "Stoppa samtal" : "Starta samtal") {
                                vm.toggleConversation()
                            }
                        }
                    }
                    Spacer(minLength: 100) // Plats för navbar
                }
                .frame(maxWidth: 380)
                .padding(.horizontal, 20)
            }
        }
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        // TOP: rubrik i egen safe-area-inset så den hamnar rätt relativt notch
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nio")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.neonBlue, .neonCyan],
                                                        startPoint: .leading, endPoint: .trailing))
                    Text("Din röstassistent i realtid")
                        .font(.footnote)
                        .foregroundStyle(Color.subWhite)
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle()
                        .fill(vm.agentConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(vm.agentConnected ? "Ansluten" : "Ej ansluten")
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.glassStroke, lineWidth: 1))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        // BOTTOM: befintlig kontrollrad
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Menu {
                    Button("Samtalshögtalare (öronsnäcka)") { vm.setRouteReceiver() }
                    Button("Högtalare (standard)") { vm.setRouteSpeaker() }
                    if vm.btDevices.isEmpty {
                        Button("Bluetooth – inga enheter") {}.disabled(true)
                    } else {
                        Section("Bluetooth (HFP)") {
                            ForEach(vm.btDevices) { d in
                                Button(d.name) { vm.setRouteBluetooth(uid: d.id) }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("Ljudväg")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.glassStroke, lineWidth: 1))
                }
                Button { showLog = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Logg")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.glassStroke, lineWidth: 1))
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showLog) { LogView() }
    }
}

// MARK: – ViewModel (MainActor) + Audio/WS
@MainActor
final class ConversationViewModel: ObservableObject {
    struct BTDevice: Identifiable { let id: String; let name: String }

    @Published var btDevices: [BTDevice] = []
    @Published var agentConnected: Bool = false
    @Published var isActive: Bool = false

    private let agent = ElevenAgentController(agentID: ELEVEN_AGENT_ID, apiKey: ELEVEN_API_KEY)

    func onAppear() { start() }
    func onDisappear() { stop() }

    func toggleConversation() { if isActive { stop() } else { start() } }

    func start() {
        guard !isActive else { return }
        Task {
            agent.delegate = self
            do {
                try await agent.connect()
                agentConnected = true
                isActive = true
                refreshRoutes()
                log("🟢 Samtal startat")
            } catch {
                agentConnected = false
                isActive = false
                log("❌ Startfel: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        agent.disconnect()
        isActive = false
        agentConnected = false
        log("🔴 Samtal stoppat")
    }

    func refreshRoutes() {
        let arr = agent.availableBluetoothHFPDevices()
        btDevices = arr.map { BTDevice(id: $0.uid, name: $0.name) }
    }

    func setRouteReceiver() {
        Task { do { try agent.apply(route: .receiver); log("📲 Route: receiver") } catch { log("❌ Route receiver: \(error.localizedDescription)") } }
    }
    func setRouteSpeaker() {
        Task { do { try agent.apply(route: .speaker); log("📢 Route: speaker") } catch { log("❌ Route speaker: \(error.localizedDescription)") } }
    }
    func setRouteBluetooth(uid: String) {
        Task { do { try agent.apply(route: .bluetooth(uid)); log("🔵 Route: BT \(uid)") } catch { log("❌ Route BT: \(error.localizedDescription)") } }
    }
}

// MARK: – Delegate (MainActor)
@MainActor
protocol ElevenAgentDelegate: AnyObject {
    func agentConnectionChanged(_ connected: Bool)
    func agentUserTranscript(_ text: String)
    func agentTentativeResponse(_ text: String)
    func agentFinalResponse(_ text: String)

    func agentDidCaptureUserPCM(_ data: Data)
    func agentDidReceiveAgentPCM(_ data: Data)
    func agentAudioSessionRouteChanged()
}

extension ConversationViewModel: ElevenAgentDelegate {
    func agentConnectionChanged(_ connected: Bool) {
        agentConnected = connected
        log(connected ? "🟢 Agent uppkopplad" : "🔴 Agent nedkopplad")
    }
    func agentUserTranscript(_ text: String) { log("👤 Användare: \(text)") }
    func agentTentativeResponse(_ text: String) { log("🤖 (tentativt) \(min(text.count, 80)) tecken") }
    func agentFinalResponse(_ text: String) { log("🤖 Svar: \(text.prefix(80))…") }
    func agentDidCaptureUserPCM(_ data: Data) { if data.count > 0 { log("📥 Mic PCM bytes=\(data.count)") } }
    func agentDidReceiveAgentPCM(_ data: Data) { log("📦 Agent PCM bytes=\(data.count)") }
    func agentAudioSessionRouteChanged() { refreshRoutes() }
}

// MARK: – PCM-spelare (16 kHz, 16-bit, mono)
final class PCM16Player {
    private let engine = AVAudioEngine()
    private let node   = AVAudioPlayerNode()
    private let fmt    = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!

    private var started = false

    func startIfNeeded() {
        guard !started else { return }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: fmt)
        do {
            // Default: mobilens högtalare
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try s.overrideOutputAudioPort(.speaker)
            try s.setPreferredSampleRate(16_000)
            try s.setPreferredIOBufferDuration(0.02)
            try s.setActive(true)
            try engine.start()
            node.play()
            started = true
            log("🔊 PCM16Player startad")
        } catch {
            log("❌ PCM16Player startfel: \(error.localizedDescription)")
        }
    }

    func enqueue(_ pcm: Data) {
        startIfNeeded()
        let frames = pcm.count / 2
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frames)) else { return }
        buf.frameLength = AVAudioFrameCount(frames)
        pcm.withUnsafeBytes { raw in
            guard let src = raw.baseAddress else { return }
            let m = buf.audioBufferList.pointee.mBuffers
            guard let dst = m.mData else { return }
            memcpy(dst, src, min(Int(m.mDataByteSize), pcm.count))
        }
        node.scheduleBuffer(buf, at: nil, options: []) { }
    }

    func stop() {
        node.stop()
        engine.stop()
        started = false
    }
}

// MARK: – Realtime ElevenLabs agent via WebSocket (ConvAI)
final class ElevenAgentController: NSObject {
    // MainActor-notifiering (löser Swift 6-kravet)
    @inline(__always) private func notify(_ body: @escaping @MainActor @Sendable (_ d: ElevenAgentDelegate) -> Void) {
        Task { @MainActor in if let d = self.delegate { body(d) } }
    }

    weak var delegate: ElevenAgentDelegate?

    private let agentID: String
    private let apiKey: String

    private var socket: URLSessionWebSocketTask?
    private let session = AVAudioSession.sharedInstance()

    // Upptagning
    private let micEngine = AVAudioEngine()
    private var hasTap = false
    private var converter: AVAudioConverter?

    // Uppspelning
    private let player = PCM16Player()

    // State
    private var connected = false {
        didSet { notify { $0.agentConnectionChanged(self.connected) } }
    }
    private var chunksSent: Int = 0
    enum RouteChoice { case receiver, speaker, bluetooth(String) }
    private var preferredRoute: RouteChoice = .speaker   // default: mobilens högtalare

    private var vadTimer: Timer?
    private var lastSpeechAt: Date = .distantFuture
    private let speechThreshold: Double = 0.006   // mer känsligt än 0.012
    private var forceCommitTimer: Timer?

    private var routeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?

    init(agentID: String, apiKey: String) {
        self.agentID = agentID
        self.apiKey  = apiKey
    }

    func availableBluetoothHFPDevices() -> [(uid: String, name: String)] {
        let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
        return inputs.filter { $0.portType == .bluetoothHFP }.map { ($0.uid, $0.portName) }
    }

    func apply(route: RouteChoice) throws {
        preferredRoute = route
        try configureRouteForPreferred(restartMic: true)
        player.startIfNeeded()
    }

    private func configureRouteForPreferred(restartMic: Bool) throws {
        let s = AVAudioSession.sharedInstance()
        if restartMic { stopMicStreaming() }

        try s.setActive(false, options: .notifyOthersOnDeactivation)

        switch preferredRoute {
        case .receiver:
            try s.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
            try s.overrideOutputAudioPort(.none)
            try s.setPreferredInput(nil)

        case .speaker:
            try s.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try s.overrideOutputAudioPort(.speaker)
            try s.setPreferredInput(nil)

        case .bluetooth(let uid):
            try s.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
            if let bt = s.availableInputs?.first(where: { $0.uid == uid }) {
                try s.setPreferredInput(bt)
                log("🔵 BT vald: \(bt.portName)")
            } else {
                log("⚠️ BT-enhet ej hittad, behåller aktuell input")
            }
        }

        try s.setPreferredSampleRate(16_000)
        try s.setPreferredIOBufferDuration(0.02)
        try s.setActive(true)

        let r = s.currentRoute
        let outs = r.outputs.map { $0.portName }.joined(separator: ",")
        let ins  = r.inputs.map { $0.portName }.joined(separator: ",")
        log("🎚️ Route satt | OUT[\(outs)] IN[\(ins)]")

        if restartMic { try startMicStreaming() }
    }

    func connect() async throws {
        try await ensureMicPermission()
        try setupAudioSession()

        var comps = URLComponents(string: "wss://api.elevenlabs.io/v1/convai/conversation")!
        comps.queryItems = [URLQueryItem(name: "agent_id", value: agentID)]
        var req = URLRequest(url: comps.url!)
        req.addValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let cfg = URLSessionConfiguration.default
        let session = URLSession(configuration: cfg, delegate: self, delegateQueue: .main)
        let ws = session.webSocketTask(with: req)
        socket = ws
        ws.resume()
        log("🔗 WS ansluter mot ElevenLabs-agent \(agentID)")

        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let r = AVAudioSession.sharedInstance().currentRoute
            let outs = r.outputs.map { $0.portType.rawValue + ":" + $0.portName }.joined(separator: ",")
            let ins  = r.inputs.map { $0.portType.rawValue + ":" + $0.portName }.joined(separator: ",")
            log("🔄 Route change: OUT[\(outs)] IN[\(ins)]")
            self.player.startIfNeeded()
            self.notify { $0.agentAudioSessionRouteChanged() }
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let info = note.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
            switch type {
            case .began:
                log("⛔️ Audio interruption began")
                self.stopMicStreaming()
            case .ended:
                log("✅ Audio interruption ended – restarting mic")
                do { try self.startMicStreaming() } catch { log("❌ restart mic after interruption: \(error.localizedDescription)") }
            @unknown default: break
            }
        }
    }

    func disconnect() {
        if let ro = routeObserver { NotificationCenter.default.removeObserver(ro) }
        if let io = interruptionObserver { NotificationCenter.default.removeObserver(io) }
        routeObserver = nil
        interruptionObserver = nil

        stopVADTimer()
        stopForceCommitTimer()
        stopMicStreaming()
        player.stop()
        socket?.cancel(with: .goingAway, reason: "app_closed".data(using: .utf8))
        socket = nil
        connected = false
        log("🔌 WS frånkopplad")
    }

    private func setupAudioSession() throws {
        guard session.isInputAvailable else {
            throw NSError(domain: "audio.session", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ingen inspelningskälla tillgänglig"])
        }
        try configureRouteForPreferred(restartMic: false) // default: speaker
        let r = session.currentRoute
        let outs = r.outputs.map { $0.portName }.joined(separator: ",")
        let ins  = r.inputs.map { $0.portName }.joined(separator: ",")
        log("🎛️ Ljudsession init: OUT[\(outs)] IN[\(ins)]")
    }

    // iOS 17+ permission API, med bakåtkompabilitet
    private func ensureMicPermission() async throws {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return
            case .undetermined:
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    AVAudioApplication.requestRecordPermission { ok in
                        ok ? cont.resume() :
                        cont.resume(throwing: NSError(domain: "mic.perm", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mikrofontillstånd nekades."]))
                    }
                }
            case .denied:
                throw NSError(domain: "mic.perm", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mikrofontillstånd är avstängt i Inställningar."])
            @unknown default:
                return
            }
        } else {
            let s = AVAudioSession.sharedInstance()
            switch s.recordPermission {
            case .granted: return
            case .undetermined:
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    s.requestRecordPermission { ok in
                        ok ? cont.resume() :
                        cont.resume(throwing: NSError(domain: "mic.perm", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mikrofontillstånd nekades."]))
                    }
                }
            case .denied:
                throw NSError(domain: "mic.perm", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mikrofontillstånd är avstängt i Inställningar."])
            @unknown default: return
            }
        }
    }

    private func startVADTimer() {
        vadTimer?.invalidate()
        vadTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastSpeechAt) > 0.8 {
                self.send(["type": "user_audio_buffer_commit"])
                self.lastSpeechAt = .distantFuture
                log("📤 Commit user audio buffer")
            }
        }
        if let t = vadTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func startForceCommitTimer() {
        forceCommitTimer?.invalidate()
        forceCommitTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.send(["type": "user_audio_buffer_commit"])
            log("⏱️ Force-commit")
        }
        if let t = forceCommitTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func stopVADTimer() {
        vadTimer?.invalidate()
        vadTimer = nil
    }
    private func stopForceCommitTimer() {
        forceCommitTimer?.invalidate()
        forceCommitTimer = nil
    }

    // MARK: – Mic → WS
    private func startMicStreaming() throws {
        let input = micEngine.inputNode
        let inFmt = input.outputFormat(forBus: 0)
        let outFmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!
        converter = AVAudioConverter(from: inFmt, to: outFmt)

        if hasTap {
            input.removeTap(onBus: 0)
            hasTap = false
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: inFmt) { [weak self] (buffer, _) in
            guard let self, let conv = self.converter else { return }

            guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFmt, frameCapacity: 4096) else { return }
            var err: NSError?
            let status = conv.convert(to: outBuf, error: &err, withInputFrom: { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            })
            if status == .error || err != nil {
                log("❌ Mic konverteringsfel: \(err?.localizedDescription ?? "okänt")")
                return
            }

            let frames = Int(outBuf.frameLength)
            if frames <= 0 { return }
            let bytesPerFrame = Int(outBuf.format.streamDescription.pointee.mBytesPerFrame)
            let byteCount = frames * bytesPerFrame

            let m = outBuf.audioBufferList.pointee.mBuffers
            guard let mData = m.mData else { return }
            let data = Data(bytes: mData, count: byteCount)

            // Logg + VAD
            if byteCount > 0 {
                self.notify { $0.agentDidCaptureUserPCM(data) }
                let sampleCount = byteCount / 2
                var sum: Int64 = 0
                data.withUnsafeBytes { raw in
                    let p = raw.bindMemory(to: Int16.self)
                    for i in 0..<sampleCount { let v = Int32(p[i]); sum += Int64(v * v) }
                }
                let rms = sqrt(Double(sum) / Double(max(sampleCount,1))) / Double(Int16.max)
                if rms > self.speechThreshold { self.lastSpeechAt = Date() }
                if (self.chunksSent % 25) == 0 {
                    log(String(format: "🎤 Mic chunk: bytes=%d rms=%.3f", byteCount, rms))
                }
            }

            self.send(["type": "user_audio_chunk", "audio": data.base64EncodedString()])

            self.chunksSent &+= 1
            if (self.chunksSent % 100) == 0 { self.send(["type": "user_activity"]) }
        }
        hasTap = true

        micEngine.prepare()
        try micEngine.start()
        log("🎙️ Mic streaming startad (→ WS)")
        // Meddela servern att en ny “buffer session” startar
        self.send(["type": "user_audio_buffer_start"])

        lastSpeechAt = .distantFuture
        startVADTimer()
        startForceCommitTimer()
    }

    private func stopMicStreaming() {
        micEngine.stop()
        stopVADTimer()
        stopForceCommitTimer()
        if hasTap {
            micEngine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        log("🛑 Mic streaming stoppad")
    }

    // MARK: – WS helpers
    private func startReceiving() {
        socket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                log("❌ WS fel: \(error.localizedDescription)")
                self.connected = false
            case .success(let msg):
                switch msg {
                case .string(let s):
                    self.handleMessageString(s)
                case .data(let d):
                    if let s = String(data: d, encoding: .utf8) { self.handleMessageString(s) }
                @unknown default:
                    break
                }
                self.startReceiving()
            }
        }
    }

    private func handleMessageString(_ s: String) {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any] else {
            log("ℹ️ WS (okänt json) \(s.prefix(120))")
            return
        }

        if let ping = obj["ping_event"] as? [String: Any], let id = ping["event_id"] {
            send(["type": "pong", "event_id": id]); return
        }

        if let initMeta = obj["conversation_initiation_metadata_event"] as? [String: Any] {
            let aFmt = initMeta["agent_output_audio_format"] as? String ?? "?"
            let uFmt = initMeta["user_input_audio_format"] as? String ?? "?"
            log("ℹ️ WS init: agent_audio=\(aFmt) user_audio=\(uFmt)")
            return
        }

        if let tr = obj["user_transcription_event"] as? [String: Any], let t = tr["user_transcript"] as? String {
            notify { $0.agentUserTranscript(t) }; return
        }

        if let tent = obj["tentative_agent_response_internal_event"] as? [String: Any], let t = tent["tentative_agent_response"] as? String {
            notify { $0.agentTentativeResponse(t) }; return
        }

        if let resp = obj["agent_response_event"] as? [String: Any], let t = resp["agent_response"] as? String {
            notify { $0.agentFinalResponse(t) }; return
        }

        if let audio = obj["audio_event"] as? [String: Any],
           let b64 = audio["audio_base_64"] as? String,
           let data = Data(base64Encoded: b64) {
            notify { $0.agentDidReceiveAgentPCM(data) }
            player.enqueue(data)
            return
        }

        // ✅ FIX: korrekt separator-sträng inuti interpolation (ingen backslash-escape här)
        log("ℹ️ WS (okänt event): \(Array(obj.keys).joined(separator: ", "))")
    }

    private func send(_ dict: [String: Any]) {
        guard let ws = socket else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        ws.send(.string(String(data: data, encoding: .utf8)!)) { err in
            if let err { log("❌ WS send-fel: \(err.localizedDescription)") }
        }
    }
}

extension ElevenAgentController: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol `protocol`: String?) {
        log("✅ WS uppkopplad")
        connected = true

        // Säkerställ default = mobilens högtalare vid uppkoppling
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setActive(false, options: .notifyOthersOnDeactivation)
            switch preferredRoute {
            case .speaker:
                try s.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
                try s.overrideOutputAudioPort(.speaker)
                try s.setPreferredInput(nil)
            case .receiver:
                try s.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
                try s.overrideOutputAudioPort(.none)
                try s.setPreferredInput(nil)
            case .bluetooth(let uid):
                try s.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
                if let bt = s.availableInputs?.first(where: { $0.uid == uid }) {
                    try s.setPreferredInput(bt)
                }
            }
            try s.setPreferredSampleRate(16_000)
            try s.setPreferredIOBufferDuration(0.02)
            try s.setActive(true)

            // Viktigt: starta spelare och skicka init med input audio format
            self.player.startIfNeeded()

            // Skicka initdata (språk + input_audio_format) först efter att WS är öppen
            self.send([
                "type": "conversation_initiation_client_data",
                "conversation_config_override": [
                    "agent": ["language": "sv"],
                    "user":  ["input_audio_format": "pcm_16000"]
                ]
            ])
        } catch {
            log("⚠️ Route-prep vid open misslyckades: \(error.localizedDescription)")
        }

        self.startReceiving()
        do { try self.startMicStreaming() } catch { log("❌ startMicStreaming vid open: \(error.localizedDescription)") }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        let r = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        log("🔻 WS stängd \(closeCode.rawValue) \(r)")
        connected = false
    }
}

// MARK: – Preview
#Preview { AssistantView() }
