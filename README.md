# Lilla Jag – AI KBT-Terapeut

**Lilla Jag** är en iOS-app för personer med psykisk ohälsa. Appen kombinerar lokal AI-terapi (KBT), humörloggning, dagboksskrivande och stödresurser i ett sammanhållet, mörkt och varmt gränssnitt.

---

## Funktioner

| Modul | Beskrivning |
|---|---|
| **AI-assistent** | Lokal KBT-chatbot driven av Qwen3 (llama.cpp). Analyserar känslor med CoreML. 100% privat – ingen data lämnar enheten. |
| **Humörloggning** | 14-stegs flöde för att logga sömn, stress, socialt liv, kost och känsloläge. Veckostatistik och AI-genererad sammanfattning. |
| **KBT-dagbok** | ABC-modell (Händelse → Automatisk tanke → Konsekvens → Omstrukturerad tanke). JSON-persistens lokalt. |
| **Diagnoser** | 15 psykiska diagnoser med symptom, behandlingsinformation och AI-insikt. |
| **Krisstöd** | Krisplan med personliga varningssignaler, trygga platser och kontakter. Direktlänk till Självmordslinjen (90101). |
| **Forum** | Community-forum med kategorier och sökning (session-only, ingen server). |
| **Socialt stöd** | Guider till professionell hjälp (1177, iKBT, Ahum), andningsövningar och externa resurser. |
| **Meditation** | Guidade andningsövningar med anpassningsbara mönster (4-7-8, box breathing, m.fl.). |

---

## Teknisk arkitektur

```
iOS 17+  ·  SwiftUI  ·  Swift 5.9+
```

### Nyckelkomponenter

- **`QwenEngine`** – `actor` wrapping llama.cpp C-API. Kör Qwen3 GGUF-modell lokalt på enhetens CPU/GPU.
- **`LillaJagAIService`** – `@MainActor` singleton. Koordinerar QwenEngine + ML-analys + chathistorik.
- **`LillaJagMLEngine`** – CoreML-motor med tre modeller: `EmotionMultiLabel` (8 Plutchik-emotioner), `SentimentScorer` och `TopicClassifier`. Faller tillbaka på `NLEmbedding` om modeller saknas.
- **`NavRouter`** – Global `ObservableObject` för tab-navigation via `RootContainer` (ZStack-baserad, ej `TabView`).
- **`DagbokStore` / `KrisplanStore` / `MoodStore`** – `@MainActor` singletons med JSON-persistens i Documents-katalogen.

### Filstruktur

```
Lilla jag 3/
├── Lilla_jag_3App.swift     # Entrypunkt, onboarding-gate
├── ContentView.swift         # Introsplash med loopande video
├── Navbar.swift              # Tab-navigering och RootContainer
├── Dashboard.swift           # Hemvy med quick-actions
├── Assistant.swift           # AI-chatvy
├── LillaJagAI.swift          # AI-tjänst (singleton)
├── LillaJagMLEngine.swift    # CoreML-emotionsanalys
├── QwenEngine.swift          # llama.cpp-integration
├── Mood1.swift               # Humörloggning (14-stegs flöde)
├── MoodViewModel.swift       # Veckostatistik-ViewModel
├── Dagbok.swift              # KBT-dagbok
├── Diagnoser.swift           # Diagnosbibliotek
├── Krisplan.swift            # Krisplan-editor
├── Forum.swift               # Community-forum
├── MeditationView.swift      # Andningsövningar
├── SocialView.swift          # Socialt stöd och resurser
├── PsykologView.swift        # Professionell hjälp
├── Onboarding.swift          # 4-sida onboarding
├── Numbers.swift             # Krisnummer
├── Monster.swift             # Gamification (ej i navigation)
├── WeatherBoard.swift        # Väder-dashboard (ej i navigation)
├── Inlogg.swift              # Firebase-autentisering (ej integrerad)
├── DesignSystem.swift        # Designsystem, tokens, komponenter
└── LillaJagColors.swift      # Färgpaletten
```

---

## Krav

- **Xcode 15+**
- **iOS 17.0+** (target)
- **Qwen3 GGUF-modell** – placeras i app-bundle (t.ex. `qwen3-0.6b-q4.gguf`)
- **CoreML-modeller** (valfritt) – `EmotionMultiLabel.mlpackage`, `SentimentScorer.mlpackage`, `TopicClassifier.mlpackage`, `KBBertSwedish.mlpackage`
- **Videofiler** – `Start.mp4` (introvideo), `bipolar.mp4` (humörsammanfattning), diagnosvideor

### Paketberoenden

Inga externa Swift Package Manager-beroenden. llama.cpp inkluderas som statiskt C/C++-bibliotek.

---

## Konfiguration

`Config.swift` innehåller konfigurationsvärden:

```swift
struct Config {
    static let openAIAPIKey = ""  // Ej i bruk – all AI är lokal
    static let modelFileName = "qwen3-0.6b-q4.gguf"
}
```

> **OBS:** OpenAI API-nyckeln är avsiktligt tom. `WeatherBoard` och `MonsterGPT` är inaktiva orphan-funktioner.

---

## Integritet

All data och AI-inferens sker lokalt på enheten. Ingen nätverkstrafik skickas förutom:
- Länköppningar (1177, Mind.se etc.) – sker i Safari
- Telefonsamtal (krislinjer)

---

## Upphovsman

Utvecklad av **Ted Svärd**.
