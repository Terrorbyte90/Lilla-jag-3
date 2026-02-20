//
//  MeditationView.swift
//  Lilla jag 3
//

import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// Körs i Xcode canvas-preview?
fileprivate let IS_PREVIEW =
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

// Kompatibel onChange (iOS 17/18 signaturskillnad + mindre typinferens)
fileprivate extension View {
    @ViewBuilder
    func onChangeCompat<T: Equatable>(of value: T, perform action: @escaping (T) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

// MARK: - Nycklar (hårdkodade)
fileprivate enum Secrets {
    static let openAIKey =
    "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"
    static let openAIModel = "gpt-4o-mini"
    static let elevenKey =
    "sk_64b296789f8b47a7daf5e26bbf42e2c7dd7ee553663f7e99"
    static let elevenVoiceID = "sX23zF6gtG6GdRB8ndmK"
}

// MARK: - 20 ambient-presets
enum AmbientPreset: String, CaseIterable, Identifiable {
    case havsbris        = "Havsbris"
    case sommarregn      = "Sommarregn"
    case norrsken        = "Norrsken"
    case skogsglänta     = "Skogsglänta"
    case eldstad         = "Eldstad"
    case fjällvind       = "Fjällvind"
    case midnatt         = "Midnatt"
    case zenKlockor      = "Zen-klockor"
    case stillhet        = "Stillhet"
    case vågsvall        = "Vågsvall"
    case dämpatAskvader  = "Dämpat åskväder"
    case mjukaSyntar     = "Mjuka syntar"
    case stjärnhimmel    = "Stjärnhimmel"
    case lugnFläkt       = "Lugn fläkt"
    case tibetiskSkål    = "Tibetisk skål"
    case drömsekvens     = "Drömsekvens"
    case skymning        = "Skymning"
    case varmFilt        = "Varm filt"
    case morgonljus      = "Morgonljus"
    case rymddrift       = "Rymddrift"
    var id: String { rawValue }
}

// MARK: - Meditationslägen
enum MeditationMode: String, CaseIterable, Identifiable {
    case andning = "Andning"
    case kroppsscanning = "Kroppsscanning"
    case sömn = "Sömn"
    case tryggPlats = "Trygg plats"
    case sos = "SOS"
    case tyst = "Tyst (ingen röst)"
    var id: String { rawValue }
}

// MARK: - Firebase: namnlagring
final class MeditationUserStore: ObservableObject {
    @Published var uid: String = ""
    @Published var displayName: String = ""
    @Published var isReady: Bool = false
    private var db: Firestore { Firestore.firestore() }
    
    init() {
        if IS_PREVIEW {
            // Minimal mock för preview
            self.uid = "preview"
            self.displayName = "Ted"
            self.isReady = true
            return
        }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        ensureAuth()
    }
    private func ensureAuth() {
        if let user = Auth.auth().currentUser {
            uid = user.uid
            fetch()
            return
        }
        Auth.auth().signInAnonymously { [weak self] result, _ in
            guard let self else { return }
            if let u = result?.user {
                self.uid = u.uid
                self.fetch()
            } else {
                self.isReady = true
            }
        }
    }
    private func fetch() {
        if IS_PREVIEW { self.isReady = true; return }
        guard !uid.isEmpty else { isReady = true; return }
        db.collection("users").document(uid).getDocument { snap, _ in
            if let name = snap?.data()?["displayName"] as? String {
                self.displayName = name
            }
            self.isReady = true
        }
    }
    func saveName(_ name: String) {
        if IS_PREVIEW { self.displayName = name; return }
        guard !uid.isEmpty else { return }
        displayName = name
        db.collection("users").document(uid).setData([
            "displayName": name,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}

// MARK: - GPT-manus
final class MeditationScriptGenerator {
    private let apiKey: String
    private let model: String
    init(apiKey: String, model: String) { self.apiKey = apiKey; self.model = model }
    
    func generate(mode: MeditationMode, minutes: Int, name: String?) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let you = (name?.isEmpty == false) ? name! : "vännen"
        let prompt = """
        Skriv ett komplett manus på svenska för en lugn meditation.
        Läge: \(mode.rawValue). Längd: ca \(minutes) minuter.
        Tilltala deltagaren ibland som "\(you)". Inga medicinska löften.
        Använd andningsmarkörer: [andas in], [håll], [andas ut], [vila].
        Trygg start, mjuk mitt, varm avslutning. Enhetlig ton.
        """
        let body: [String: Any] = [
            "model": model,
            "temperature": 0.8,
            "messages": [
                ["role":"system","content":"Du är en svensk meditationspedagog. Skriv varmt, tryggt och icke-dömande."],
                ["role":"user","content": prompt]
            ],
            "max_tokens": 1500
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, _) = try await URLSession.shared.data(for: req)
        
        struct Resp: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String }
                let message: Msg
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

// MARK: - ElevenLabs TTS
final class TTSSpeaker: NSObject, AVAudioPlayerDelegate, ObservableObject {
    private let apiKey: String
    private let voiceID: String
    private var player: AVAudioPlayer?
    @Published var isSpeaking = false
    
    init(apiKey: String, voiceID: String) {
        self.apiKey = apiKey; self.voiceID = voiceID
        super.init()
    }
    @MainActor func setVolume(_ v: Float) { player?.volume = v }
    func stop() { player?.stop(); isSpeaking = false }
    
    func speak(text: String, volume: Float) async throws {
        if IS_PREVIEW {
            DispatchQueue.main.async { self.isSpeaking = false }
            return
        }
        try prepareSession()
        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)?optimize_streaming_latency=0&output_format=mp3_44100_128")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue(apiKey, forHTTPHeaderField: "xi-api-key")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("audio/mpeg", forHTTPHeaderField: "Accept")
        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.4,
                "similarity_boost": 0.85,
                "style": 0.15,
                "use_speaker_boost": true
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "TTS", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "ElevenLabs \(http.statusCode)"])
        }
        let p = try AVAudioPlayer(data: data)
        p.volume = volume
        p.delegate = self
        p.prepareToPlay()
        p.play()
        self.player = p
        DispatchQueue.main.async { self.isSpeaking = true }
    }
    private func prepareSession() throws {
        if IS_PREVIEW { return }
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try s.setActive(true)
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

// MARK: - AmbientEngine (syntetiska ljud lokalt)
final class AmbientEngine {
    enum NoiseColor { case white, pink, brown }
    private let engine = AVAudioEngine()
    private let mix = AVAudioMixerNode()
    private let noiseNode = AVAudioPlayerNode()
    private let padNode = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()
    private let delay = AVAudioUnitDelay()
    private let rate: Double = 44_100
    private let ch: AVAudioChannelCount = 2
    private lazy var fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: ch)!
    private var noiseBuf: AVAudioPCMBuffer?
    private var padBuf: AVAudioPCMBuffer?
    
    init() { setup() }
    private func setup() {
        engine.attach(mix); engine.attach(noiseNode); engine.attach(padNode)
        engine.attach(reverb); engine.attach(delay)
        engine.connect(noiseNode, to: mix, format: fmt)
        engine.connect(padNode, to: mix, format: fmt)
        engine.connect(mix, to: reverb, format: fmt)
        engine.connect(reverb, to: delay, format: fmt)
        engine.connect(delay, to: engine.mainMixerNode, format: fmt)
        reverb.loadFactoryPreset(.largeHall2); reverb.wetDryMix = 25
        delay.delayTime = 0.35; delay.feedback = 15; delay.wetDryMix = 12
        if IS_PREVIEW { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try engine.start()
        } catch { print("engine start:", error) }
    }
    func start() {
        if IS_PREVIEW { return }
        if !engine.isRunning { try? engine.start() }
        if let b = noiseBuf, !noiseNode.isPlaying {
            noiseNode.scheduleBuffer(b, at: nil, options: .loops)
            noiseNode.play()
        }
        if let b = padBuf, !padNode.isPlaying {
            padNode.scheduleBuffer(b, at: nil, options: .loops)
            padNode.play()
        }
    }
    func stop() { noiseNode.stop(); padNode.stop() }
    func setVolumes(ambience: Float) { mix.outputVolume = ambience }
    
    func applyPreset(_ p: AmbientPreset) {
        switch p {
        case .havsbris:       configure(.brown, lp: 1200, hp: 40,  pad: [110, 220, 330], rMix: 30, dT: 0.28, fb: 10)
        case .sommarregn:     configure(.white, lp: 5000, hp: 200, pad: [261.6, 392, 523.3], rMix: 22, dT: 0.22, fb: 12)
        case .norrsken:       configure(.pink,  lp: 2500, hp: 60,  pad: [174.6, 261.6, 349.2], rMix: 40, dT: 0.38, fb: 18)
        case .skogsglänta:    configure(.pink,  lp: 3000, hp: 150, pad: [196, 293.7, 392],   rMix: 28, dT: 0.31, fb: 14)
        case .eldstad:        configure(.brown, lp: 1800, hp: 80,  pad: [98, 147, 196],      rMix: 18, dT: 0.12, fb: 8)
        case .fjällvind:      configure(.brown, lp: 1400, hp: 50,  pad: [220, 330, 440],     rMix: 32, dT: 0.34, fb: 16)
        case .midnatt:        configure(.pink,  lp: 2000, hp: 40,  pad: [55, 110, 220],      rMix: 45, dT: 0.42, fb: 20)
        case .zenKlockor:     configure(.white, lp: 8000, hp: 300, pad: [523.3, 659.3, 783.9], rMix: 35, dT: 0.48, fb: 12)
        case .stillhet:       configure(.pink,  lp: 1500, hp: 50,  pad: [110, 220, 440],     rMix: 20, dT: 0.18, fb: 10)
        case .vågsvall:       configure(.brown, lp: 1200, hp: 35,  pad: [165, 247, 330],     rMix: 33, dT: 0.30, fb: 14)
        case .dämpatAskvader: configure(.brown, lp: 900,  hp: 25,  pad: [82, 110, 147],      rMix: 38, dT: 0.36, fb: 22)
        case .mjukaSyntar:    configure(.white, lp: 7000, hp: 200, pad: [261.6, 329.6, 415.3], rMix: 27, dT: 0.24, fb: 10)
        case .stjärnhimmel:   configure(.pink,  lp: 2400, hp: 70,  pad: [246.9, 370, 493.9], rMix: 42, dT: 0.40, fb: 16)
        case .lugnFläkt:      configure(.brown, lp: 1600, hp: 55,  pad: [175, 262, 350],     rMix: 25, dT: 0.26, fb: 12)
        case .tibetiskSkål:   configure(.white, lp: 9000, hp: 400, pad: [440, 554, 659],     rMix: 45, dT: 0.52, fb: 18)
        case .drömsekvens:    configure(.pink,  lp: 2200, hp: 60,  pad: [147, 220, 294],     rMix: 36, dT: 0.33, fb: 14)
        case .skymning:       configure(.brown, lp: 1300, hp: 40,  pad: [98, 147, 220],      rMix: 34, dT: 0.32, fb: 15)
        case .varmFilt:       configure(.pink,  lp: 1700, hp: 50,  pad: [130.8, 196, 261.6], rMix: 26, dT: 0.22, fb: 10)
        case .morgonljus:     configure(.white, lp: 6000, hp: 180, pad: [262, 392, 523],     rMix: 24, dT: 0.20, fb: 10)
        case .rymddrift:      configure(.pink,  lp: 2000, hp: 40,  pad: [55, 110, 165],      rMix: 48, dT: 0.55, fb: 22)
        }
    }
    private func configure(_ color: NoiseColor, lp: Double, hp: Double, pad: [Double], rMix: Float, dT: Double, fb: Float) {
        noiseBuf = makeNoiseBuffer(color: color, seconds: 6, lowpass: lp, highpass: hp)
        padBuf = makePadBuffer(tones: pad, seconds: 6)
        reverb.loadFactoryPreset(.cathedral); reverb.wetDryMix = rMix
        delay.delayTime = dT; delay.feedback = fb
        restart()
    }
    private func restart() {
        let wasNoise = noiseNode.isPlaying, wasPad = padNode.isPlaying
        noiseNode.stop(); padNode.stop()
        if let b = noiseBuf { noiseNode.scheduleBuffer(b, at: nil, options: .loops) }
        if let b = padBuf { padNode.scheduleBuffer(b, at: nil, options: .loops) }
        if wasNoise { noiseNode.play() }; if wasPad { padNode.play() }
    }
    private func makeNoiseBuffer(color: NoiseColor, seconds: Double, lowpass: Double, highpass: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * rate)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
        buf.frameLength = frames
        guard let c0 = buf.floatChannelData?[0] else { return buf }
        let c1 = buf.floatChannelData?[1]
        var lastBrown: Float = 0
        var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
        let lpA = Float(1.0 - exp(-2.0 * Double.pi * lowpass / rate))
        let hpA = Float(1.0 - exp(-2.0 * Double.pi * highpass / rate))
        var lpy: Float = 0, hpy: Float = 0
        for i in 0..<Int(frames) {
            var x: Float = 0
            switch color {
            case .white:
                x = Float.random(in: -1...1)
            case .pink:
                let w = Float.random(in: -1...1)
                b0 = 0.99886*b0 + w*0.0555179
                b1 = 0.99332*b1 + w*0.0750759
                b2 = 0.96900*b2 + w*0.1538520
                b3 = 0.86650*b3 + w*0.3104856
                b4 = 0.55000*b4 + w*0.5329522
                b5 = -0.7616*b5 - w*0.0168980
                x = (b0+b1+b2+b3+b4+b5+b6 + w*0.5362) * 0.11
                b6 = w * 0.115926
            case .brown:
                let w = Float.random(in: -1...1) * 0.02
                lastBrown = max(min(lastBrown + w, 1), -1)
                x = lastBrown
            }
            lpy = lpA * x + (1 - lpA) * lpy
            hpy = hpA * (lpy - hpy) + hpy
            c0[i] = hpy; c1?[i] = hpy
        }
        return buf
    }
    private func makePadBuffer(tones: [Double], seconds: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * rate)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
        buf.frameLength = frames
        guard let c0 = buf.floatChannelData?[0] else { return buf }
        let c1 = buf.floatChannelData?[1]
        let twoPi = 2.0 * Double.pi
        for i in 0..<Int(frames) {
            let t = Double(i)/rate
            var s: Double = 0
            for (k, f) in tones.enumerated() { s += sin(twoPi*f*t + Double(k)*0.7) }
            s /= Double(max(1, tones.count))
            let lfo = 0.35 + 0.25 * sin(twoPi*0.08*t)
            let v = Float(s*lfo*0.5)
            c0[i] = v; c1?[i] = v
        }
        return buf
    }
}

// MARK: - Dekor
fileprivate struct MedBackground: View {
    var body: some View {
        let c1 = Color(red: 0.05, green: 0.06, blue: 0.12)
        let c2 = Color(red: 0.06, green: 0.08, blue: 0.20)
        let c3 = Color(red: 0.11, green: 0.12, blue: 0.24)
        ZStack {
            LinearGradient(colors: [c1, c2, c3], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Circle().fill(Color.purple.opacity(0.45))
                .blur(radius: 120)
                .frame(width: 280, height: 280)
                .offset(y: -260)
            MedWaveView().opacity(0.85)
        }
    }
}

fileprivate struct MedWaveView: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        Canvas { ctx, size in
            let path = Self.wavePath(size: size, phase: phase)
            let g = Gradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)])
            ctx.fill(path, with: .linearGradient(g, startPoint: .zero, endPoint: .init(x: size.width, y: size.height)))
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                phase = .pi*2
            }
        }
        .allowsHitTesting(false)
    }
    private static func wavePath(size: CGSize, phase: CGFloat) -> Path {
        var p = Path()
        let w = size.width, h = size.height
        let mid = h * 0.62
        p.move(to: .init(x: 0, y: mid))
        let step: CGFloat = 4
        let steps = Int(max(1, w/step))
        let twoPi: CGFloat = .pi * 2
        for i in 0...steps {
            let x = CGFloat(i) * step
            let nx = x / max(1, w)
            let s1 = sin(nx * twoPi + phase)
            let s2 = sin(nx * twoPi * 3 - phase * 0.7)
            let y = mid + 12 * s1 + 4 * s2
            p.addLine(to: .init(x: x, y: y))
        }
        p.addLine(to: .init(x: w, y: h))
        p.addLine(to: .init(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

fileprivate struct MedBreathRing: View {
    @State private var scale: CGFloat = 0.92
    var diameter: CGFloat = 64
    var body: some View {
        Circle()
            .strokeBorder(
                AngularGradient(gradient: Gradient(colors: [Color.white.opacity(0.5),
                                                            .white.opacity(0.1),
                                                            .white.opacity(0.5)]),
                                center: .center),
                lineWidth: 2
            )
            .frame(width: diameter, height: diameter)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    scale = 1.06
                }
            }
    }
}

// MARK: - Minispelare + helpers
enum MedCorner { case topLeading, topTrailing, bottomLeading, bottomTrailing
    var alignment: Alignment {
        switch self {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }
}

fileprivate func presetSymbol(_ p: AmbientPreset) -> String {
    switch p {
    case .havsbris: return "wind"
    case .sommarregn: return "cloud.rain"
    case .norrsken: return "sparkles"
    case .skogsglänta: return "leaf"
    case .eldstad: return "flame"
    case .fjällvind: return "wind.snow"
    case .midnatt: return "moon.stars"
    case .zenKlockor: return "bell"
    case .stillhet: return "pause.circle"
    case .vågsvall: return "water.waves"
    case .dämpatAskvader: return "cloud.bolt.rain"
    case .mjukaSyntar: return "music.note"
    case .stjärnhimmel: return "star"
    case .lugnFläkt: return "wind"
    case .tibetiskSkål: return "tuningfork"
    case .drömsekvens: return "cloud.moon"
    case .skymning: return "sunset"
    case .varmFilt: return "sun.max"
    case .morgonljus: return "sunrise"
    case .rymddrift: return "sparkles"
    }
}

fileprivate func presetGradient(_ p: AmbientPreset) -> LinearGradient {
    let colors: [Color]
    switch p {
    case .eldstad, .varmFilt, .skymning:
        colors = [Color.orange, Color.pink]
    case .sommarregn, .vågsvall, .morgonljus:
        colors = [Color.blue, Color.cyan]
    case .norrsken, .stjärnhimmel, .midnatt, .rymddrift:
        colors = [Color.purple, Color.indigo]
    case .skogsglänta, .lugnFläkt:
        colors = [Color.green, Color.teal]
    default:
        colors = [Color.blue, Color.purple]
    }
    return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
}

fileprivate struct MedMiniPlayerContent: View {
    let isPlaying: Bool
    let presetText: String
    let symbolName: String
    let bgGradient: LinearGradient
    let onPlayPause: () -> Void
    let onTapChoose: () -> Void
    
    var body: some View {
        let capsuleBG = Capsule().fill(.white.opacity(0.12))
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(bgGradient).opacity(0.55)
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)
            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(presetText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(isPlaying ? "Spelar" : "Pausad")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 6)
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.white.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            
            Image(systemName: "music.note.list")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(capsuleBG)
        .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
        .contentShape(Rectangle())
        .onTapGesture { onTapChoose() }
    }
}

fileprivate struct MedMiniPlayerFloating: View {
    @Binding var isPlaying: Bool
    @Binding var preset: AmbientPreset
    @Binding var corner: MedCorner
    let onPlayPause: () -> Void
    let onTapChoose: () -> Void
    @State private var drag = CGSize.zero
    
    var body: some View {
        // Typ-erasure bryter upp den tunga generiska kedjan
        let content = MedMiniPlayerContent(
            isPlaying: isPlaying,
            presetText: preset.rawValue,
            symbolName: presetSymbol(preset),
            bgGradient: presetGradient(preset),
            onPlayPause: onPlayPause,
            onTapChoose: onTapChoose
        )
        return AnyView(
            ZStack {
                content
                    .offset(drag)
                    .gesture(
                        DragGesture()
                            .onChanged { v in drag = v.translation }
                            .onEnded { v in
                                drag = .zero
                                let horizontalRight = v.translation.width > 0
                                let verticalDown = v.translation.height > 0
                                switch (horizontalRight, verticalDown) {
                                case (true, true):  corner = .bottomTrailing
                                case (false, true): corner = .bottomLeading
                                case (true, false): corner = .topTrailing
                                case (false, false):corner = .topLeading
                                }
                            }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner.alignment)
            .padding()
            .allowsHitTesting(true)
        )
    }
}

// MARK: - Mindre UI-bitar
fileprivate struct MedHeaderCard: View {
    var title: String
    var subtitle: String
    var isPlaying: Bool
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.white.opacity(0.08))
                MedBreathRing(diameter: 64)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(width: 64, height: 64)
            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
    }
}

fileprivate struct MedChip: View {
    var text: String
    var selected: Bool
    var body: some View {
        ZStack {
            Capsule().fill(Color.white.opacity(0.08))
            if selected {
                Capsule().fill(
                    LinearGradient(colors: [.purple, .blue],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            }
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .overlay(Capsule().stroke(.white.opacity(selected ? 0.0 : 0.12), lineWidth: 1))
    }
}

fileprivate struct MedSliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 1
    var onChange: (Double) -> Void = { _ in }
    var body: some View {
        // Splitta formatteringen -> lättare typkontroll
        let valText: String = (floor(value) == value) ? "\(Int(value))" : String(format: "%.2f", value)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(valText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.06), in: Capsule())
            }
            Slider(value: $value, in: range, step: step)
                .tint(.purple)
                .onChangeCompat(of: value) { v in onChange(v) }
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

fileprivate struct MedToggleRow: View {
    var title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.9))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.purple)
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

fileprivate struct MedModeChips: View {
    @Binding var mode: MeditationMode
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MeditationMode.allCases) { m in
                    Button { mode = m } label: { MedChip(text: m.rawValue, selected: mode == m) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

fileprivate struct PresetMenuLabelView: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
        .foregroundStyle(.white)
    }
}

fileprivate struct MedPresetMenuRow: View {
    @Binding var selected: AmbientPreset
    var body: some View {
        HStack {
            Image(systemName: presetSymbol(selected))
                .foregroundStyle(.white.opacity(0.9))
            Menu {
                ForEach(AmbientPreset.allCases) { p in
                    Button {
                        selected = p
                    } label: { Text(p.rawValue) }
                }
            } label: {
                PresetMenuLabelView(text: selected.rawValue)
            }
            Spacer()
        }
    }
}

fileprivate struct MedVolumeRow: View {
    var title: String
    @Binding var value: Float
    var body: some View {
        let b = Binding<Double>(
            get: { Double(value) },
            set: { v in value = Float(v) }
        )
        MedSliderRow(title: title, value: b, range: 0...1, step: 0.01)
    }
}

fileprivate struct ScriptScrollView: View {
    let text: String
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .padding(12)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxHeight: 140)
    }
}

fileprivate struct MedPrimaryButton: View {
    var title: String; var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                .foregroundStyle(.white)
        }
    }
}

fileprivate struct MedSecondaryButton: View {
    var title: String; var action: () -> Void; var enabled: Bool
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white.opacity(0.95))
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
    }
}

// MARK: - ViewModel
@MainActor
final class MeditationVM: ObservableObject {
    @Published var selectedPreset: AmbientPreset = .havsbris {
        didSet { ambient.applyPreset(selectedPreset); updateNowPlayingTitle() }
    }
    @Published var mode: MeditationMode = .andning
    @Published var minutes: Double = 10
    @Published var ambienceVol: Float = 0.65 {
        didSet { ambient.setVolumes(ambience: ambienceVol) }
    }
    @Published var voiceVol: Float = 0.85 {
        didSet { Task { @MainActor in tts.setVolume(voiceVol) } }
    }
    @Published var voiceEnabled = true
    @Published var isPlaying = false
    @Published var generating = false
    @Published var scriptText = ""
    @Published var miniCorner: MedCorner = .bottomTrailing
    
    @Published var userStore = MeditationUserStore()
    
    private let ambient = AmbientEngine()
    private let tts = TTSSpeaker(apiKey: Secrets.elevenKey, voiceID: Secrets.elevenVoiceID)
    private let generator = MeditationScriptGenerator(apiKey: Secrets.openAIKey, model: Secrets.openAIModel)
    
    init() {
        setupAudio()
        ambient.applyPreset(selectedPreset)
        ambient.setVolumes(ambience: ambienceVol)
        if !IS_PREVIEW { setupNowPlaying() }
    }
    
    var displayName: String { userStore.displayName }
    func saveName(_ name: String) { userStore.saveName(name) }
    
    func togglePlay() async {
        if isPlaying {
            ambient.stop()
            tts.stop()
            isPlaying = false
            updateNowPlaying(isPlaying: false)
            return
        }
        ambient.applyPreset(selectedPreset)
        ambient.setVolumes(ambience: ambienceVol)
        ambient.start()
        isPlaying = true
        updateNowPlaying(isPlaying: true)
        if voiceEnabled { await regenerateGuidance() }
    }
    
    func regenerateGuidance() async {
        guard voiceEnabled else { return }
        if IS_PREVIEW {
            scriptText = "Förhandsvisning – exempel på guidning.\n[andas in] [håll] [andas ut] [vila]\nSlappna av i käkar och axlar."
            return
        }
        generating = true
        do {
            let text = try await generator.generate(mode: mode, minutes: Int(minutes), name: displayName)
            scriptText = text
            try await tts.speak(text: text, volume: voiceVol)
        } catch {
            scriptText = "Låt oss vila här en stund. [andas in] [andas ut] Känn hur kroppen får vara precis som den är."
            try? await tts.speak(text: scriptText, volume: voiceVol)
        }
        generating = false
    }
    
    // MARK: - Audio/Now Playing
    private func setupAudio() {
        if IS_PREVIEW { return }
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try s.setActive(true)
        } catch { print("Audio session:", error) }
    }
    private func setupNowPlaying() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying { Task { await self.togglePlay() } }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying { Task { await self.togglePlay() } }
            return .success
        }
        updateNowPlaying(isPlaying: false)
    }
    private func updateNowPlaying(isPlaying: Bool) {
        updateNowPlayingTitle()
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    }
    private func updateNowPlayingTitle() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = "Lilla jag – \(selectedPreset.rawValue)"
        info[MPMediaItemPropertyArtist] = "Meditation"
        info[MPNowPlayingInfoPropertyIsLiveStream] = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - Kontrollpanel (kopplad till VM)
fileprivate struct MedControlPanel: View {
    @ObservedObject var vm: MeditationVM
    var body: some View {
        VStack(spacing: 12) {
            MedPresetMenuRow(selected: $vm.selectedPreset)
            MedModeChips(mode: $vm.mode)
            MedSliderRow(title: "Längd (min)", value: $vm.minutes, range: 5...30, step: 1)
            MedToggleRow(title: "Guidning med röst (ElevenLabs)", isOn: $vm.voiceEnabled)
            VStack(spacing: 10) {
                MedVolumeRow(title: "Ambiens", value: $vm.ambienceVol)
                MedVolumeRow(title: "Röst", value: $vm.voiceVol)
            }
        }
    }
}

fileprivate struct MedActionsRow: View {
    let isPlaying: Bool
    let voiceEnabled: Bool
    let generating: Bool
    let onTogglePlay: () -> Void
    let onRegenerate: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            MedPrimaryButton(title: isPlaying ? "Pausa" : "Spela", action: onTogglePlay)
            MedSecondaryButton(title: "Ny guidning", action: onRegenerate, enabled: voiceEnabled && !generating)
        }
    }
}

fileprivate struct GreetingRow: View {
    let displayName: String
    let onTapName: () -> Void
    var body: some View {
        let n = displayName.isEmpty ? "vännen" : displayName
        HStack {
            Text("Hej \(n) – det här är din stund.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Button(action: onTapName) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle")
                    Text(displayName.isEmpty ? "Lägg till namn" : "Ändra namn")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
                .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Namn-sheet
fileprivate struct MedNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tempName: String
    var onSave: (String) -> Void
    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color.secondary.opacity(0.4))
                .frame(width: 44, height: 5)
                .padding(.top, 8)
            Text("Vad vill du bli kallad?")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .padding(.top, 8)
            TextField("Skriv ditt namn", text: $tempName)
                .textContentType(.name)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding()
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
                .tint(.purple)
                .onSubmit { save() }
            Button { save() } label: {
                Text("Spara")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [.blue, .purple],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }.padding(.top, 6)
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(colors: [Color.black.opacity(0.85), Color.black.opacity(0.9)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }
    private func save() {
        let name = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { onSave(name) }
        dismiss()
    }
}

fileprivate struct MedMainPanel: View {
    @ObservedObject var vm: MeditationVM
    let onTapName: () -> Void
    let onTogglePlay: () -> Void
    let onRegenerate: () -> Void
    
    var body: some View {
        let subtitle: String = vm.mode.rawValue + " • \(Int(vm.minutes)) min"
        VStack(spacing: 16) {
            MedHeaderCard(title: vm.selectedPreset.rawValue, subtitle: subtitle, isPlaying: vm.isPlaying)
            MedControlPanel(vm: vm)
            MedActionsRow(isPlaying: vm.isPlaying,
                          voiceEnabled: vm.voiceEnabled,
                          generating: vm.generating,
                          onTogglePlay: onTogglePlay,
                          onRegenerate: onRegenerate)
            if !vm.scriptText.isEmpty && vm.voiceEnabled {
                ScriptScrollView(text: vm.scriptText)
            }
            GreetingRow(displayName: vm.displayName, onTapName: onTapName)
        }
        .padding(18)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12), lineWidth: 1))
        .padding(.horizontal)
    }
}

// MARK: - Ljudlandskap-sheet
fileprivate struct MedTrackPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: AmbientPreset
    var body: some View {
        VStack(spacing: 12) {
            Text("Välj ljudlandskap")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .padding(.top, 8)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(AmbientPreset.allCases) { p in
                        MedTrackCard(title: p.rawValue, isSelected: p == selected) {
                            selected = p; dismiss()
                        }
                    }
                }
                .padding(.horizontal).padding(.bottom, 12)
            }
        }
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.08, blue: 0.18),
                         Color(red: 0.10, green: 0.10, blue: 0.22)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }
}

fileprivate struct MedTrackCard: View {
    var title: String
    var isSelected: Bool
    var onTap: () -> Void
    var body: some View {
        let bg = RoundedRectangle(cornerRadius: 14)
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Text(isSelected ? "Vald" : "Tryck för att välja")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.10), in: bg)
            .overlay(bg.stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }
}

// MARK: - Huvudvy
struct MeditationView: View {
    @StateObject private var vm = MeditationVM()
    @State private var askName = false
    @State private var tempName = ""
    @State private var showHome = false
    @State private var showTrackPicker = false
    
    private func togglePlayAction() { Task { await vm.togglePlay() } }
    private func regenerateAction() { Task { await vm.regenerateGuidance() } }
    private func openNameSheet() { tempName = vm.displayName; askName = true }
    
    @ViewBuilder private var headerTitle: some View {
        Text("Meditation")
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.top, 12)
    }
    
    @ViewBuilder private var homeButton: some View {
        let circleFill = LinearGradient(colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing)
        Button { showHome = true } label: {
            ZStack {
                Circle()
                    .fill(circleFill)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                Image(systemName: "house.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.bottom, 16)
        .fullScreenCover(isPresented: $showHome) {
            // Undvik stora beroenden i Preview
            if IS_PREVIEW {
                Color.black.opacity(0.001).ignoresSafeArea()
            } else {
                ContentView().ignoresSafeArea()
            }
        }
    }
    
    @ViewBuilder private var generatingOverlay: some View {
        if vm.generating {
            Color.black.opacity(0.35).ignoresSafeArea()
            ProgressView("Skapar personlig guidning…")
                .tint(.white).foregroundStyle(.white)
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    @ViewBuilder private var miniPlayer: some View {
        // Typ-erasure här med AnyView inuti komponenten
        MedMiniPlayerFloating(
            isPlaying: $vm.isPlaying,
            preset: $vm.selectedPreset,
            corner: $vm.miniCorner,
            onPlayPause: togglePlayAction,
            onTapChoose: { showTrackPicker = true }
        )
    }
    
    var body: some View {
        ZStack {
            MedBackground()
            VStack(spacing: 16) {
                headerTitle
                MedMainPanel(vm: vm,
                             onTapName: openNameSheet,
                             onTogglePlay: togglePlayAction,
                             onRegenerate: regenerateAction)
                Spacer(minLength: 8)
                homeButton
            }
            generatingOverlay
            miniPlayer
        }
        .onAppear {
            if vm.userStore.isReady, vm.displayName.isEmpty { askName = true }
        }
        .onChangeCompat(of: vm.userStore.isReady) { ready in
            if ready, vm.displayName.isEmpty { askName = true }
        }
        .sheet(isPresented: $askName) {
            MedNameSheet(tempName: $tempName) { name in
                vm.saveName(name)
            }
        }
        .sheet(isPresented: $showTrackPicker) {
            MedTrackPickerSheet(selected: $vm.selectedPreset)
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        MeditationView()
    }
    .preferredColorScheme(.dark)
}
