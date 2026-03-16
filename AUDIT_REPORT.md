# Lilla Jag – Kodbas-granskning (Audit Report)

**Datum:** 2026-03-16
**Granskad av:** Claude Sonnet 4.6 (automatiserad fullständig granskning)
**Branch:** `claude/fix-project-bugs-rBQcM`

---

## Sammanfattning

Fullständig genomgång och förbättring av hela kodbasen i 7 faser. Totalt åtgärdades **17 buggar/fel**, **2 arkitekturbrister**, **1 duplicerad definition** och **1 dead file** togs bort.

---

## FAS 1 – Kodbasinventering

### Teknikstack
- SwiftUI + Swift 5.9, iOS 17+
- llama.cpp (C-API) för lokal LLM-inferens (Qwen3)
- CoreML för emotionsanalys
- AVFoundation/AVKit för videospelning
- Firebase (integrerat i `Inlogg.swift` men EJ aktiverat i app-flödet)
- JSON-persistens lokalt (Documents-katalogen)

### Arkitekturöversikt
- **Navigation:** Custom `NavRouter`-singleton med ZStack-baserad `RootContainer` (ej `TabView`)
- **State management:** `@MainActor` singletons (`DagbokStore`, `KrisplanStore`, `LillaJagAIService`, `LillaJagMLEngine`, `MoodStore`)
- **AI-pipeline:** `QwenEngine` (actor) → `LillaJagAIService` → `LillaJagMLEngine` (CoreML fallback till NLEmbedding)

### Orphaned/Inaktiva moduler
| Fil | Status | Anledning |
|---|---|---|
| `Inlogg.swift` | Ej integrerad | `Lilla_jag_3App.swift` navigerar direkt till `ContentView` utan auth-gate |
| `WeatherBoard.swift` | Ej åtkomlig | Ingen navigationslänk i appen. Kräver OpenAI API-nyckel (tom). |
| `Monster.swift` | Ej åtkomlig | `MonsterPanel` visas inte från någon vy i navigation |

---

## FAS 2 – Buggar och fel åtgärdade

### Kritiska buggar

| # | Fil | Problem | Åtgärd |
|---|---|---|---|
| 1 | `LillaJagAI.swift` | Dubbel användarmessage i Qwen-prompt — `messages` innehöll redan det nya meddelandet när historiken byggdes, vilket gav en duplicerad rad i varje prompt | Ändrade `messages.suffix(8)` till `messages.dropLast().suffix(8)` |
| 2 | `Mood1.swift` | `AVPlayer(url:)` skapades inline i `summaryStep` view body → ny instans varje re-render, aldrig frigörd | Flyttade till `@State private var summaryPlayer: AVPlayer?` med lazy `onAppear`-init |
| 3 | `Diagnoser.swift` | `AVPlayer(url:)` inline i `DiagnosisDetailView` body — samma mönster som #2 | Lagt till `@State private var videoPlayer: AVPlayer?` med `onAppear`-init |
| 4 | `Mood1.swift` | Dubbla `MoodStore`-instanser i `Mood1View` — `_store` och `_viewModel` pekade på separata `MoodStore()`, vilket gav desync | Lade till custom `init()` som skapar en delad instans och initierar båda med den |

### Medelsvåra buggar

| # | Fil | Problem | Åtgärd |
|---|---|---|---|
| 5 | `Assistant.swift` | `@StateObject private var ai = LillaJagAIService.shared` — fel property wrapper för singleton; `@StateObject` äger objektets livscykel men singletons ska observeras, inte ägas | Ändrat till `@ObservedObject` |
| 6 | `Dagbok.swift` | Samma singleton-mönster med `@StateObject` | Ändrat till `@ObservedObject` |
| 7 | `Krisplan.swift` | Samma singleton-mönster med `@StateObject` | Ändrat till `@ObservedObject` |
| 8 | `MeditationView.swift` | `Timer.scheduledTimer` med `.default` RunLoop-mode — pausas under scrollning och user interaction | Ändrade till `RunLoop.main.add(t, forMode: .common)` + explicit `timer`-tilldelning |
| 9 | `SocialView.swift` | `NavigationStack` wrappade `MeditationView` som var presenterad via `fullScreenCover` → dubbel NavigationStack-nesting | Tog bort den inre `NavigationStack` i presentationen |
| 10 | `ContentView.swift` | `Coordinator` i `LoopingVideoPlayer` hade ingen `player`-referens, vilket orsakade potential memory leak / felaktig `removeTimeObserver` | Lade till `var player: AVPlayer?` i `Coordinator` och korrekt `deinit` |
| 11 | `PsykologView.swift` | `emotionContext` beräknades men användes aldrig i prompt-strängen | Lade till `\(emotionContext)` som prefix i prompt |
| 12 | `Forum.swift` | Banner visade `posts.count` oavsett aktiva filter → inkorrekt antal vid sökning | Ändrat till `filtered.count` |
| 13 | `WeatherBoard.swift` | `onChange(of:)` med deprecated 1-parameter closure (iOS 16-stil) | Uppdaterat till 2-parameter closure (iOS 17-stil) |
| 14 | `Assistant.swift` | Samma deprecated `onChange(of:)` | Uppdaterat |
| 15 | `Inlogg.swift` | Firebase-callbacks utan `DispatchQueue.main.async` — UI-uppdateringar från bakgrundstråd | Wrappade alla callbacks |

### Mindre buggar / Dead code

| # | Fil | Problem | Åtgärd |
|---|---|---|---|
| 16 | `WeatherBoard.swift` | Dead function `dailySummary()` — definierad men aldrig kallad | Borttagen |
| 17 | `Onboarding.swift` | `@State var dragOffset` och `@State var animateContent` — definierade men aldrig använda | Borttagna |
| 18 | `Navbar.swift` | `.onAppear { router.current = dest }` i `NavbarModifier` — kördes varje gång en vy syntes och orsakade onödig navigation | Borttagen |
| 19 | `Monster.swift` | `MonsterStore` utan `@MainActor` trots `@Published` state och UI-uppdateringar | Lade till `@MainActor` |

---

## FAS 3 – UI/UX-granskning

### Designkonsistens ✅
- Hela appen håller konsistent mörkt tema (`WarmBackground`, `.preferredColorScheme(.dark)`)
- Färgpalett (warmLavender, warmGold, warmRose, warmSage, warmCoral) konsekvent använd
- Rounded fonts (`design: .rounded`) genomgående

### Navigation ✅
- Tab-navigation via `RootContainer` + `NavRouter.shared` fungerar korrekt
- Modala vyer (`SocialView`, `PsykologView`, `MeditationView`) via `fullScreenCover`/`sheet` med egna `NavigationStack`

### Tomma tillstånd ✅
- `AITherapistView` visar välkomstsektion med conversation starters när `ai.messages.isEmpty`
- `DagbokDashboardView` visar mock-data på första start (2 exempelinlägg)
- `Mood1View` hanterar tomma humörlistor korrekt

### Kvarvarande UI-anmärkningar
- **`DagbokStore.loadMockData()`:** Fyller dagboken med exempeldata på fresh install. Bra för onboarding-UX men kan förvirra användare som tror det är deras data. Överväg att tydligt märka dem som "Exempelanteckningar".
- **Haptic feedback:** Inga `UIImpactFeedbackGenerator`-anrop. Lägg till vid viktiga actions (skicka meddelande, spara krisplan etc.) för bättre iOS-känsla.
- **Loading states:** `PsykologView` och `DiagnosisDetailView` visar AI-insikt-laddning bra, men `Forum.swift` har ingen laddningsindikator för AI-genererat innehåll om den lades till.

---

## FAS 4 – Kodkvalitet

### Åtgärdat

| Problem | Åtgärd |
|---|---|
| `Chatty.swift` — tom fil (0 bytes), `ChattyView` definieras i `Assistant.swift` | Fil borttagen |
| `GradientButtonStyle` definierades i `Monster.swift` men användes av `Mood1.swift` — beroende på orphaned feature | Flyttad till `DesignSystem.swift`, borttagen från `Monster.swift` |

### Kvarvarande kodkvalitetsanmärkningar (lågprioritet)
- **`glass()` vs `ljGlassCard()`:** Två liknande glassmorphism-helpers med subtila skillnader. `glass()` (i `Mood1.swift`) lägger till padding; `ljGlassCard()` (i `DesignSystem.swift`) clips. Konsolidering möjlig men kräver noggrann verifiering av visuell output.
- **`FooterContainer`, `average(default:)`, `MoodStore.last7()`:** Definierade i slutet av `Mood1.swift`. Logiskt skulle `last7()` höra till en separat `MoodStore`-fil. Lågprioriterat refaktoreringsarbete.
- **`typealias PrimaryButton = GradientButtonStyle`** i `Mood1.swift` är oanvänd. Kan tas bort.
- **Dubbel emotionsanalys per meddelande:** `addUserMessage()` anropar `analyzeEmotion()` och `generateResponse()` anropar det igen internt. Redundant beräkning (~2×). Optimering: cachat resultat från `addUserMessage` kunde skickas till `generateResponse`.

---

## FAS 5 – Förbättringsförslag (prioriterade)

### Hög prioritet

1. **Autentisering och datasynkronisering**
   `Inlogg.swift` (Firebase) är komplett men ej kopplad till app-flödet. Att aktivera auth och CloudKit/Firestore-sync skulle göra appen användbar vid byte av enhet och möjliggöra pushnotiser.

2. **Qwen-modell saknas i bundle**
   Appen startar och faller tillbaka på keyword-matching om GGUF-modellen saknas. Lägg till ett onboarding-steg för modellnedladdning (Background URL Session) eller inkludera en minimal modell. Utan modell är AI-assistenten kraftigt degraderad.

3. **Persistens för forum-inlägg**
   `samplePosts` är `private var` (ej `@Published`-drivna och ej sparade). Nya inlägg försvinner vid omstart. Lägg till JSON-persistens eller CloudKit.

4. **Avsaknad av push-notiser**
   Inga påminnelser för daglig humörloggning, andningsövning etc. `UNUserNotificationCenter` med schemalagda notiser är en viktig retention-funktion för mental health-appar.

### Medelhög prioritet

5. **`DiagnosisDetailView.loadAIInsight()` + `PsykologView.loadAISuggestion()`**
   Dessa anropar `LillaJagAIService.shared.generateResponse()` vilket sätter global `isThinking = true`. Typing-indikatorn syns i AI-chatfliken under dessa laddningar. Separera ML-servicen från chat-service eller lägg till separat `isThinking`-flagga per context.

6. **`WeatherBoard.swift` och `MonsterPanel`**
   Dessa är kompletta vyer (väder-dashboard och monster-gamification) men är ej åtkomliga från main navigation. Integrera eller ta bort för att reducera kodbasens komplexitet.

7. **Tillgänglighet (Accessibility)**
   Inga `.accessibilityLabel()`, `.accessibilityHint()` eller VoiceOver-anpassningar. Viktigt för en mental health-app vars användare ofta har kognitiva funktionsnedsättningar.

8. **Onboarding → Auth-integration**
   `@AppStorage("hasCompletedOnboarding")` hanterar onboarding men Firebase-login (`Inlogg.swift`) är ej kopplad. Enhetlig autentiseringsgate saknas.

### Lågprioritet

9. **`DagbokStore.loadMockData()`** — märk exempeldata tydligare eller lägg till ett "Kom igång"-banner.
10. **Haptic feedback** — `UIImpactFeedbackGenerator` vid viktiga actions.
11. **`typealias PrimaryButton = GradientButtonStyle`** i `Mood1.swift` — ta bort oanvänd alias.
12. **CoreML-modeller saknas** — appen faller tillbaka korrekt, men ladda ned eller bunta med lättvikts-modeller för bättre initial upplevelse.
13. **`QwenEngine.deduplicateSentences`** — sammanfogar meningar med `". "` vilket kan ge konstiga meningsslut. Minor polish.

### Säkerhet

- **Inga API-nycklar i koden** ✅ (`Config.openAIAPIKey` är tom sträng)
- **Lokal AI utan nätverkstrafik** ✅
- **JSON-filer i Documents (ej KeyChain):** Känslig data (krisplan, dagbok) lagras i okrypterad JSON. Överväg Data Protection Level `.completeUnlessOpen` eller kryptering.
- **Firebase-beroende vid framtida aktivering:** Se till att Firebase SDK-versionen är uppdaterad innan auth aktiveras.

---

## Buggar åtgärdade – Kompletta filer påverkade

| Fil | Ändringar |
|---|---|
| `LillaJagAI.swift` | `messages.suffix(8)` → `messages.dropLast().suffix(8)` |
| `Assistant.swift` | `@StateObject` → `@ObservedObject`; `onChange` 2-param |
| `Mood1.swift` | Delad `MoodStore`-instans via custom `init()`; `AVPlayer` till `@State` |
| `Diagnoser.swift` | `AVPlayer` till `@State private var videoPlayer` |
| `MeditationView.swift` | Timer `.default` → `.common` RunLoop-mode |
| `SocialView.swift` | Borttagen nested `NavigationStack` |
| `ContentView.swift` | `Coordinator` deinit med `removeTimeObserver` |
| `PsykologView.swift` | `emotionContext` nu inkluderat i prompt |
| `Forum.swift` | Banner visar `filtered.count` |
| `Dagbok.swift` | `@StateObject` → `@ObservedObject` |
| `Krisplan.swift` | `@StateObject` → `@ObservedObject` |
| `WeatherBoard.swift` | `onChange` 2-param; borttagen dead function `dailySummary` |
| `Onboarding.swift` | Borttagna oanvända `@State`-variabler |
| `Navbar.swift` | Borttagen redundant `.onAppear` |
| `Monster.swift` | `@MainActor` på `MonsterStore`; `GradientButtonStyle` borttagen (flyttad till DesignSystem) |
| `Inlogg.swift` | Firebase-callbacks wrappade i `DispatchQueue.main.async`; `onChange` 2-param |
| `DesignSystem.swift` | `GradientButtonStyle` tillagd |
| `Chatty.swift` | **Borttagen** (tom fil) |

---

## Slutsats

Kodbasen är välstrukturerad med ett konsistent visuellt språk och tydlig separation av ansvar. De åtgärdade buggarna är väsentliga för stabilitet (minneshantering, trådsäkerhet, state-konsistens). De viktigaste framtida insatserna är: aktivera Firebase-autentisering, lösa Qwen-modellens tillgänglighet och implementera push-notiser för dagliga påminnelser.
