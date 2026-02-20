//
//  Dagbok.swift
//  LillaJag
//
//  27 jul 2025 – kompilerar rent
//

import SwiftUI
import AVKit
import AVFoundation

// MARK: ‑ Datum‑hjälp
extension DateFormatter {
    static let svLong : DateFormatter = { let d = DateFormatter(); d.locale = .init(identifier:"sv_SE")
                                          d.dateStyle = .long;  d.timeStyle = .none;  return d }()
    static let svShort: DateFormatter = { let d = DateFormatter(); d.locale = .init(identifier:"sv_SE")
                                          d.dateStyle = .short; d.timeStyle = .short; return d }()
    static let svFull : DateFormatter = { let d = DateFormatter(); d.locale = .init(identifier:"sv_SE")
                                          d.dateStyle = .full;  d.timeStyle = .short; return d }()
}
extension Date {
    var svLong : String { DateFormatter.svLong .string(from:self) }
    var svShort: String { DateFormatter.svShort.string(from:self) }
    var svFull : String { DateFormatter.svFull .string(from:self) }
}

// MARK: ‑ Datamodeller
enum Humör: String, CaseIterable, Codable, Identifiable {
    case lycklig = "😄", lugn = "🙂", ledsen = "😢", arg = "😠", orolig = "😰"
    var id: String { rawValue }
    var namn: String {
        switch self {
        case .lycklig: "Glad"
        case .lugn:    "Lugn"
        case .ledsen:  "Ledsen"
        case .arg:     "Arg"
        case .orolig:  "Orolig"
        }
    }
    var färg: Color {
        switch self {
        case .lycklig: .green
        case .lugn:    .cyan
        case .ledsen:  .blue
        case .arg:     .red
        case .orolig:  .orange
        }
    }
}
struct Dagboksinlägg: Codable, Identifiable {
    let id: UUID
    var datum: Date
    var humör: Humör
    var text: String
    init(datum: Date = .now, humör: Humör = .lugn, text: String = "") {
        id = UUID(); self.datum = datum; self.humör = humör; self.text = text
    }
}

// MARK: ‑ Lagring
@MainActor
final class DagbokStore: ObservableObject {
    @Published private(set) var inlägg: [Dagboksinlägg] = []
    private let url: URL
    init() {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        url = doc.appendingPathComponent("dagbok.json")
        ladda()
    }
    func läggTill(_ i: Dagboksinlägg) { inlägg.append(i); spara() }
    func uppdatera(_ i: Dagboksinlägg) {
        guard let ix = inlägg.firstIndex(where: { $0.id == i.id }) else { return }
        inlägg[ix] = i; spara()
    }
    private func ladda() {
        guard let d = try? Data(contentsOf: url),
              let e = try? JSONDecoder().decode([Dagboksinlägg].self, from: d) else { return }
        inlägg = e.sorted { $0.datum > $1.datum }
    }
    private func spara() { try? JSONEncoder().encode(inlägg).write(to: url) }
}

// MARK: ‑ ElevenLabs‑TTS
struct ElevenLabsTjänst {
    static func ljudData(för text: String) async throws -> Data {
        let apiKey  = Config.elevenLabsAPIKey
        let voiceID = "4WpEoB5wO1r9MAJoD3s0"
        let url = URL(string:"https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)")!
        let body:[String:Any] = ["text":text,"model_id":"eleven_multilingual_v2","output_format":"mp3_44100_128"]
        var req = URLRequest(url:url)
        req.httpMethod = "POST"
        req.addValue(apiKey, forHTTPHeaderField:"xi-api-key")
        req.addValue("application/json", forHTTPHeaderField:"Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (d,r) = try await URLSession.shared.data(for:req)
        guard let resp = r as? HTTPURLResponse,(200..<300).contains(resp.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return d
    }
}

// MARK: ‑ Talspelare
@MainActor
final class Talspelare: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var spelar = false
    private var spelare: AVAudioPlayer?
    func tala(_ text: String) {
        Task {
            do {
                let d = try await ElevenLabsTjänst.ljudData(för: text)
                spelare = try AVAudioPlayer(data: d)
                spelare?.delegate = self
                spelare?.prepareToPlay(); spelare?.play(); spelar = true
            } catch { print("TTS‑fel:", error) }
        }
    }
    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully: Bool) { spelar = false }
}

// MARK: ‑ Video‑banner
struct VideoBanner: View {
    let namn: String
    var body: some View {
        GeometryReader { geo in
            if let path = Bundle.main.path(forResource: namn, ofType: "mp4") {
                VideoPlayer(player:{
                    let p = AVPlayer(url:URL(fileURLWithPath:path))
                    p.actionAtItemEnd = .none
                    p.play()
                    NotificationCenter.default.addObserver(forName:.AVPlayerItemDidPlayToEndTime,
                                                           object:p.currentItem, queue:.main){ _ in
                        p.seek(to:.zero); p.play()
                    }
                    return p
                }())
                .frame(width:geo.size.width,height:geo.size.height)
                .clipped()
                .allowsHitTesting(false) // döljer uppspelningsknappar
            }
        }
    }
}

// MARK: ‑ Månadshuvud
struct MånadHeader: View {
    @Binding var månad: Date
    private let fmt: DateFormatter = { let f = DateFormatter(); f.locale = .init(identifier:"sv_SE")
                                       f.dateFormat = "LLLL yyyy"; return f }()
    var body: some View {
        HStack {
            Button(action: { ändraMånad(-1) }) {
                Image(systemName:"chevron.left").font(.title3.weight(.bold))
            }
            Spacer()
            Text(fmt.string(from:månad).capitalized)
                .font(.title3.weight(.semibold))
            Spacer()
            Button(action: { ändraMånad(1) }) {
                Image(systemName:"chevron.right").font(.title3.weight(.bold))
            }
        }
        .foregroundColor(.white)
        .padding(.vertical,6).padding(.horizontal,12)
        .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:14))
    }
    private func ändraMånad(_ v:Int){
        guard let ny = Calendar.current.date(byAdding:.month,value:v,to:månad) else { return }
        månad = ny
    }
}

// MARK: ‑ Kalender
struct Månadskalender: View {
    let månad: Date
    let markerade: Set<DateComponents>
    @Binding var vald: DateComponents?
    
    private var c: Calendar {
        var cal = Calendar(identifier:.gregorian)
        cal.locale = .init(identifier:"sv_SE")
        cal.timeZone = .init(identifier:"Europe/Stockholm")!
        return cal
    }
    private var celler:[DateComponents] {
        let start = c.date(from:c.dateComponents([.year,.month], from:månad))!
        guard let r = c.range(of:.day,in:.month,for:start) else { return [] }
        return r.map{ d in var comp = c.dateComponents([.year,.month], from:start); comp.day=d; return comp }
    }
    private let col = Array(repeating:GridItem(.flexible()), count:7)
    
    var body: some View {
        LazyVGrid(columns:col,spacing:4){
            ForEach(c.shortWeekdaySymbols,id:\.self) {
                Text($0.capitalized).font(.caption2).opacity(0.6)
            }
            ForEach(celler,id:\.self){ comp in
                let marker = markerade.contains(comp)
                let valt   = comp == vald
                VStack(spacing:2){
                    Text(String(comp.day ?? 0))
                        .font(.body.bold())
                        .foregroundColor(valt ? .white : .primary)
                        .frame(maxWidth:.infinity)
                        .padding(6)
                        .background(valt ? Color.blue : Color.clear, in:Circle())
                    Circle()
                        .fill(marker ? (valt ? .white : .blue) : .clear)
                        .frame(width:4,height:4)
                }
                .onTapGesture {
                    if vald == comp {
                        // tryck igen på samma datum avmarkerar det
                        vald = nil
                    } else {
                        vald = comp
                    }
                }
            }
        }
        .padding(.horizontal,6)
    }
}

// MARK: ‑ Huvudvy
struct DagbokDashboardView: View {
    @StateObject private var store = DagbokStore()
    @State private var showEditor = false
    @State private var filterHumör: Humör? = nil
    @State private var valdDag: DateComponents? = nil
    @State private var visadMånad: Date = .now
    @State private var visaKalender: Bool = false
    
    private var markerade:Set<DateComponents>{
        let cal = Calendar.current
        return Set(store.inlägg.map{ cal.dateComponents([.year,.month,.day], from:$0.datum) })
    }
    private var filtrerade:[Dagboksinlägg]{
        let cal = Calendar.current
        let start = cal.date(from:cal.dateComponents([.year,.month], from:visadMånad))!
        let end   = cal.date(byAdding:.month,value:1,to:start)!
        var list  = store.inlägg.filter{ $0.datum>=start && $0.datum<end }
        if let h = filterHumör { list = list.filter{ $0.humör == h } }
        if let d = valdDag     { list = list.filter{ cal.isDate($0.datum, equalTo: cal.date(from:d)!, toGranularity:.day) } }
        return list
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment:.bottomTrailing) {
                ScrollView {
                    VStack(spacing:16) {
                        rubrik
                        banner
                        kalenderBlock
                        humörFilter
                        inläggLista
                    }
                    .padding(.bottom, 100) // Plats för navbar
                }
            }
            .background(Color.black.ignoresSafeArea())
            .environment(\.locale,.init(identifier:"sv_SE"))
            .fullScreenCover(isPresented:$showEditor) {
                InläggEditorView(store:store)
            }
        }
    }
    
    // MARK: – Delvyer
    private var rubrik: some View {
        VStack(alignment:.leading,spacing:2) {
            Text("Dagbok").font(.largeTitle.weight(.heavy))
            Text("Tryck på monstret för att skapa inlägg").font(.headline).foregroundColor(.secondary)
        }
        .foregroundColor(.white)
        .padding(.horizontal,20)
        .padding(.top,20)
    }
    private var banner: some View {
        VideoBanner(namn:"diaryLoop")
            .aspectRatio(16/9, contentMode: .fill)
            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 200)
            .clipped()
            .cornerRadius(18)
            .glassify()
            .onTapGesture { showEditor = true }
            .padding(.horizontal,20)
    }
    private var kalenderBlock: some View {
        VStack(spacing: 8) {
            // Månadshuvudet visas alltid; tryck för att expandera/minimera kalendern
            MånadHeader(månad: $visadMånad)
                .onTapGesture {
                    withAnimation(.spring()) { visaKalender.toggle() }
                }

            // Själva kalendern visas bara när den är expanderad
            if visaKalender {
                Månadskalender(månad: visadMånad,
                                markerade: markerade,
                                vald: $valdDag)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .glassify()
        .padding(.horizontal, 20)
        // Nollställ vald dag om månaden byts
        .onChange(of: visadMånad) { _ in
            valdDag = nil
        }
        // Fäll ihop kalendern automatiskt efter dagval
        .onChange(of: valdDag) { _ in
            if visaKalender {
                withAnimation(.spring()) { visaKalender = false }
            }
        }
        // Nollställ vald dag när humörfilter ändras
        .onChange(of: filterHumör) { _ in
            if valdDag != nil {
                valdDag = nil
                // se till att kalendern är stängd
                withAnimation(.spring()) { visaKalender = false }
            }
        }
    }
    private var humörFilter: some View {
        ScrollView(.horizontal,showsIndicators:false) {
            HStack {
                filterKnapp("Alla", aktiv:filterHumör==nil) { filterHumör = nil }
                ForEach(Humör.allCases) { h in
                    filterKnapp("\(h.rawValue) \(h.namn)",
                                aktiv:filterHumör==h) { filterHumör = h }
                }
            }
            .padding(.horizontal,20)
        }
    }
    private var inläggLista: some View {
        Group {
            if filtrerade.isEmpty {
                Text("Inga inlägg")
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top,60)
            } else {
                LazyVStack(spacing:12) {
                    ForEach(filtrerade) { i in
                        NavigationLink {
                            InläggDetaljView(inlägg:i, store:store)
                        } label: {
                            rad(i)
                        }
                    }
                }
                .padding(.horizontal,20)
                .padding(.bottom,20)
            }
        }
    }
    private func filterKnapp(_ text:String, aktiv:Bool, action:@escaping()->Void) -> some View {
        Button(action:action) {
            Text(text)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal,12)
                .padding(.vertical,6)
                .background(aktiv ? Color.blue : Color.clear, in:Capsule())
        }
        .foregroundColor(.white)
    }
    private func rad(_ p:Dagboksinlägg) -> some View {
        HStack(alignment:.top,spacing:16) {
            Text(p.humör.rawValue).font(.largeTitle)
                .padding(8)
                .background(p.humör.färg.opacity(0.2), in:Circle())
            VStack(alignment:.leading,spacing:4) {
                Text(p.datum.svShort)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(p.text).lineLimit(2)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in:RoundedRectangle(cornerRadius:18))
    }
    // plusKnapp has been removed
}

// MARK: – Detaljvy
struct InläggDetaljView: View {
    let inlägg: Dagboksinlägg
    @ObservedObject var store: DagbokStore
    @StateObject private var talare = Talspelare()
    
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack {
                    Text(inlägg.humör.rawValue).font(.system(size:56))
                    VStack(alignment:.leading) {
                        Text(inlägg.humör.namn).font(.title2.bold())
                        Text(inlägg.datum.svFull).foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(inlägg.humör.färg.opacity(0.2),
                            in:RoundedRectangle(cornerRadius:20))
                
                Text(inlägg.text)
                    .padding()
                    .glassify()
                
                Button(action:{ talare.tala(inlägg.text) }) {
                    Label(talare.spelar ? "Spelar…" : "Läs upp",
                          systemImage:"speaker.wave.2.fill")
                }
                .buttonStyle(PrimärKnapp())
                .disabled(talare.spelar)
            }
            .padding(24)
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement:.navigationBarTrailing) {
                NavigationLink {
                    InläggEditorView(store:store, redigerar:inlägg)
                } label: {
                    Image(systemName:"square.and.pencil")
                }
            }
        }
    }
}

// MARK: – Editor
struct InläggEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DagbokStore
    @State private var inlägg: Dagboksinlägg
    @StateObject private var talare = Talspelare()
    init(store: DagbokStore, redigerar: Dagboksinlägg? = nil) {
        _store = ObservedObject(initialValue:store)
        _inlägg = State(initialValue:redigerar ?? Dagboksinlägg())
    }
    var body: some View {
        NavigationStack {
            VStack(spacing:16) {
                Text(inlägg.datum.svShort)
                    .font(.subheadline)
                    .foregroundColor(.white)
                emojirad
                TextEditor(text:$inlägg.text)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight:.infinity)
                    .padding()
                    .background(.ultraThinMaterial, in:RoundedRectangle(cornerRadius:18))
                    .foregroundColor(.white)
                Button(action:{ talare.tala(inlägg.text) }) {
                    Label(talare.spelar ? "Spelar…" : "Lyssna på texten",
                          systemImage:"speaker.wave.2.fill")
                }
                .buttonStyle(PrimärKnapp())
                .disabled(inlägg.text.isEmpty || talare.spelar)
            }
            .padding(20)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Nytt inlägg")
            .toolbar {
                ToolbarItem(placement:.cancellationAction) {
                    Button("Avbryt") { dismiss() }
                        .buttonStyle(SekundärKnapp())
                }
                ToolbarItem(placement:.confirmationAction) {
                    Button("Spara") {
                        if store.inlägg.contains(where:{ $0.id == inlägg.id }) {
                            store.uppdatera(inlägg)
                        } else {
                            store.läggTill(inlägg)
                        }
                        dismiss()
                    }
                    .buttonStyle(PrimärKnapp())
                    .disabled(inlägg.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    private var emojirad: some View {
        ScrollView(.horizontal,showsIndicators:false) {
            HStack {
                ForEach(Humör.allCases) { h in
                    Text(h.rawValue)
                        .font(.largeTitle)
                        .padding(8)
                        .background(inlägg.humör == h ? h.färg.opacity(0.8)
                                                      : Color.white.opacity(0.1),
                                    in:Circle())
                        .onTapGesture { inlägg.humör = h }
                }
            }
            .frame(maxWidth:.infinity)
        }
    }
}

// MARK: – Knappar & Glas
struct PrimärKnapp: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth:.infinity)
            .background(Color.blue.opacity(configuration.isPressed ? 0.7 : 0.9),
                        in: RoundedRectangle(cornerRadius:16))
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
struct SekundärKnapp: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth:.infinity)
            .background(Color.white.opacity(configuration.isPressed ? 0.15 : 0.1),
                        in: RoundedRectangle(cornerRadius:16))
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
extension View {
    /// Frostad glass‑effekt
    func glassify(corner: CGFloat = 18) -> some View {
        self.padding()
            .background(.ultraThinMaterial, in:RoundedRectangle(cornerRadius:corner))
            .overlay(RoundedRectangle(cornerRadius:corner)
                        .stroke(Color.white.opacity(0.15), lineWidth:0.5))
    }
}

// MARK: – Preview
#Preview {
    DagbokDashboardView()
        .environment(\.colorScheme,.dark)
}
