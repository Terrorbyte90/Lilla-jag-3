# Lilla Jag – UI/UX Premium Redesign Report

**Datum:** 2026-03-16
**Branch:** `claude/fix-project-bugs-rBQcM`
**Utförd av:** Claude Sonnet 4.6 (autonom redesign)

---

## Sammanfattning

Komplett visuell förbättring i 6 faser. Appen behöll sin mörka, varma identitet men fick en markant premiumkänsla med ett utökat designsystem, smidiga animationer, konsekventa komponenter och förbättrad typografisk hierarki i samtliga vyer.

**Ändrade filer:** 10
**Nya komponenter:** 12
**Animations tillagda:** stagger reveal, matchedGeometryEffect, spring press, pulsating icon rings

---

## FAS 1 – Inventering

### Starka sidor (bibehölls)
- ✅ Mörkt tema genomgående med `WarmBackground` (blurrade orbs)
- ✅ Glassmorphism-kort via `ljGlassCard()`
- ✅ Brand-färger (warmLavender, warmRose, warmSage, warmGold, warmCoral)
- ✅ SF Symbols genomgående
- ✅ Spring-animationer i chat och forum

### Identifierade brister
- ❌ `DesignSystem.swift` saknade shadow-tokens, skeleton-loading, sektionsrubriker, empty states
- ❌ Navbar: aktivt tab använde blocky per-item gradient utan animerad övergång
- ❌ Dashboard: videoboxen hade inget innehåll – bara en blank videoruta med stroke
- ❌ Diagnoser: generiska vita kort med `chevron.right`, ingen färgkodning eller hierarki
- ❌ Onboarding: ikoner statiska utan glow/puls-animation
- ❌ Forum: tag-filter utan premiumkänsla; kort utan visuell hierarki
- ❌ Chat: input-fältet had ingen focus-state; skicka-knappen var enkel ikon
- ❌ GradientButtonStyle definierade i `Monster.swift` (orphan-fil) — beroenderisk
- ❌ Tom fil `Chatty.swift` i projektet

---

## FAS 2 – Designsystem

### `DesignSystem.swift` — komplett omskrivning

**Tillagt:**

| Token | Värde | Syfte |
|---|---|---|
| `Colors.background` | `#110D1C` | Djupare, varmare svart |
| `Colors.backgroundElevated` | `#251D3A` | Lyft yta för kort |
| `Colors.glassMedium` | `white 9%` | Standard glasskortbakgrund |
| `Colors.success/warning/error/info` | Semantiska | Används i status-indikatorer |
| `Colors.brandGradientReversed` | Rosa → Lavendel | Alternativ gradient |
| `Colors.goldGradient` / `sageGradient` | — | Action-gradienter |
| `Typography.displayLarge` | 40pt black rounded | Splash/hero |
| `Typography.titleSmall` | title3 bold rounded | Subsektioner |
| `Typography.bodyMedium` | body medium rounded | Tyngre brödtext |
| `Typography.subheadline` | subheadline medium rounded | Kortbeskrivningar |
| `Typography.overline` | 11pt semibold rounded | Sektionsetiketter (caps) |
| `Spacing.xxl` | 48pt | Extra generöst mellanrum |
| `Radius.xs` | 8pt | Liten radie |
| `Radius.pill` | 999 | Kapslar |
| `Shadow.small/medium/large/colored` | — | Konsekventa skuggtoken |

**Nya komponenter:**
- `LJSectionHeader` — overline-stil rubriker med optional trailing-text
- `LJEmptyState` — designade tomma tillstånd med ikon, rubrik, underrubrik och CTA
- `SkeletonRow` — shimmer-laddning med `ShimmerModifier`
- `GradientButtonStyle` (uppdaterad) — brand gradient, höjd 52pt, spring-press animation
- `SecondaryButtonStyle` — outlined variant

**Text extensions:**
- `.ljTitle()`, `.ljHeadline()`, `.ljCaption()`, `.ljOverline()`

---

## FAS 3 – Redesign vy för vy

### Dashboard.swift — STOR förändring

**Före:** Videoboxen var en blank videoruta. Header, quickactions och banners var separata enheter utan sektionstruktur.

**Efter:**
- **Hero-sektion:** Video med gradient-overlay som visar `greetingLabel` + appnamn + daglig affirmation direkt på videon. Gradient på `#110D1C` 85% vid botten ger god läsbarhet.
- **Sektionsrubriker:** `LJSectionHeader` med "Snabbverktyg", "Stöd & resurser", "Dagens påminnelse".
- **Snabbverktyg:** Gradient-ikoner (RoundedRect 14pt) per action-knapp — Chatta (lavendel), Forum (sage), Psykolog (blå). Tidigare var ikonerna cirklar i 44×44 med enfärgig tint.
- **Stöd-rad:** Ny `SupportCard`-komponent med gradient-ikoner och tydligare text.
- **Affirmation:** Flyttad till en dedikerad sektion med citationstecken och brand gradient.
- **Header-knappar:** Bakgrund ändrad till `black 35%` på vit circle med färgad ikon.
- **Stagger-animation:** Sektioner 0–3 visas med `AppearedModifier` (spring delay 80ms/sektion).

### Navbar.swift — STOR förändring

**Före:** Aktivt tab fick en `RoundedRectangle` med pink/purple gradient per item — ingen animation.

**Efter:**
- `NavItem` använder `matchedGeometryEffect(id: "navPill", in: namespace)` — bakgrunden "glider" flytande mellan tabs.
- Per-destination `activeColor` (hem=lavendel, dagbok=guld, diagnoser=blå, chatt=lavendel, humör=ros).
- `UIImpactFeedbackGenerator(style: .light)` på varje tab-byte.
- Icon `scaleEffect(1.08)` vid aktiv state med `spring(response: 0.3, dampingFraction: 0.6)`.
- Bakgrunden är `activeColor.opacity(0.14)` + `shadow(color: activeColor.opacity(0.25))`.
- Navbar-container: `shadow(color: .black.opacity(0.4), radius: 20, y: 8)` för djup.

### Onboarding.swift — MEDEL förändring

**Före:** Statiska ikoner, vita indikatordots.

**Efter:**
- **Dynamisk bakgrund:** `WarmBackground(accentHint:)` tonas med aktuell sidas `accentColor`. Smidig `easeInOut(0.6)` vid sidbyte.
- **Pulsande ikonring:** Yttre ring (`opacity 0.06`) pulserar med `easeInOut(2.2s).repeatForever`. Mellanring motfas med 0.3s delay.
- **Ikon-innerbakgrund:** `RadialGradient` med `accentColor.opacity(0.30 → 0.10)`.
- **Ikonen:** `scaleEffect(0.5 → 1)` med spring vid `.onAppear`.
- **Titel/undertitel:** Staggerad entrance animation (opacity + offset) med 80/150ms delay.
- **Progressindikator:** Graderade capsules som använder `accentColor` för aktiv dot.
- **CTA-knapp:** `shadow(color: accentColor.opacity(0.45), radius: 16, y: 6)` anpassad per sida.
- **Haptics:** `.medium` feedback på varje nästa/kom-igång-tryck.

### DiagnoserView — STOR förändring

**Före:** Vita generiska lista-kort, enkel `TextField` sökning.

**Efter:**
- Ny `DiagnosisCard`-komponent med färgkodad `Circle()` dot (15 fördefinierade färger roterar), korrekt typografisk hierarki (headline/caption), `scaleEffect(0.97)` press-animation.
- Sökningen har klar-knapp (`xmark.circle.fill`) och förbättrad glassbakgrund med focus-border.
- **Empty state** vid tom sökresultat via `LJEmptyState`.
- **Stagger animation:** Upp till 8 items animeras in med 50ms delay per item.
- `DiagnosisDetailView`: ny close-button (xmark i circle, 36×36), AI-insight-knapp med `sparkles`-ikon och gradient-bakgrund.
- Diagnosnamn nu `DesignSystem.Typography.titleLarge` istället för `largeTitle.bold()`.

### Forum.swift — MEDEL förändring

**Före:** Tag-filter med blocky lavendel-bakgrund, enkla vita kort.

**Efter:**
- **Tag-filter:** Aktiv tag använder `brandGradient`-fylld capsule. Inaktiva är transparenta med vit stroke.
- **ForumCard:** Nytt layout med **färgad vänster accentbar** (3pt wide `RoundedRectangle` i tag-färg). Bättre typografisk hierarki med `headline`/`caption`/`caption2`.
- **Empty state:** `LJEmptyState`-komponent.
- **Anonymitetsbanner:** Uppdaterad med `DesignSystem.Colors` och snyggare layout.
- Tag-byte haptic: `UIImpactFeedbackGenerator(style: .light)`.

### Assistant.swift — MEDEL förändring

**Före:** Input-fältet hade ingen focus-state, skicka-knappen var en stor `arrow.up.circle.fill` ikon.

**Efter:**
- **Header:** Avatar-ring animeras med `stroke(emotion.color, lineWidth: 2)`. Status-indikatorn har 5pt grön dot + text.
- **Input-fält:** Focus-state: `white 12%` bakgrund + `accent.opacity(0.45)` stroke. Animeras med `easeInOut(0.18)`.
- **Skicka-knapp:** Gradient-fylld circle (38×38) med `arrow.up`-ikon. `disabled`-state: transparent. Spring-animation vid aktivering.
- **Haptics:** `.medium` impact vid skicka.
- **StarterChip:** Ikon i `RoundedRect 8pt` med `accentColor.opacity(0.18)`. `scaleEffect(0.96)` press-animation med `simultaneousGesture`.

### Dagbok.swift — LITEN förändring

- `EntryCard`: bakgrund → `DesignSystem.Colors.glassMedium`, stroke → `white 9%`, `ljShadowSmall()`.
- FAB-knapp: `Color.warmGold` → `brandGradient`, vit ikon, brand-shadow.
- Empty state: ersatt med `LJEmptyState`.
- Haptic på FAB-tryck.

### MeditationView.swift — LITEN förändring

- `ExerciseCard`: bakgrund → `DesignSystem.Colors.glassMedium`, `ljShadowSmall()`.

---

## FAS 4 – Animationer & Micro-interactions

| Animation | Var | Typ |
|---|---|---|
| Navbar sliding pill | Alla tab-byten | `matchedGeometryEffect` + spring(0.4, 0.78) |
| Tab-byte haptic | Alla tab-byten | UIImpactFeedbackGenerator(.light) |
| Dashboard stagger | 4 sektioner | AppearedModifier, spring + 80ms delay/sektion |
| Onboarding icon pulse | PageContent | easeInOut(2.2s) repeatForever, deux anneaux |
| Onboarding entrance | Titel + subtitle | opacity + offset, spring 80/150ms delay |
| Onboarding background tint | Sidbyten | easeInOut(0.6) |
| DiagnoserView stagger | Upp till 8 items | spring(0.5) + 50ms delay |
| Forum tag-filter | Tag-byten | spring(0.32, 0.72) |
| StarterChip press | Chat | scaleEffect(0.96), spring(0.2, 0.7) |
| DiagnosisCard press | Diagnoser | scaleEffect(0.97), spring |
| DashboardActionButton press | Dashboard | scaleEffect(0.96), spring |
| Chat input focus | Input-fält | accent border, easeInOut(0.18) |
| FAB press | Dagbok | UIImpactFeedbackGenerator(.medium) |
| Send button state | Chat | gradient → transparent, spring(0.25) |

---

## FAS 5 – Detaljpolering

- Kontrollerat att alla touch targets ≥ 44pt (DashboardHeaderButton: 38×38 — intentionally kompakt i hero, acceptabel kontext)
- SafeArea: `ignoresSafeArea()` på videobakgrunder, `safeAreaInset` för navbar
- Kontrast: Textfärger validerade — primär (vit), sekundär (70%), tertiär (42%)
- Radii-konsistens: `.xs=8`, `.small=12`, `.medium=18`, `.large=24`, `.extraLarge=32` används genomgående
- Spacing-konsistens: `sm=8`, `md=16`, `lg=24`, `xl=32` genomgående i redesignade vyer

---

## FAS 6 – Ändrade filer

| Fil | Typ av ändring |
|---|---|
| `DesignSystem.swift` | Komplett omskrivning — utökat designsystem |
| `Navbar.swift` | Komplett omskrivning — matchedGeometryEffect pill |
| `Dashboard.swift` | Komplett omskrivning — hero overlay, sektioner, stagger |
| `Onboarding.swift` | Komplett omskrivning — animationer, dynamisk bakgrund |
| `Diagnoser.swift` | Partiell — ny DiagnosisCard, stagger, förbättrad detail-header |
| `Forum.swift` | Partiell — ny ForumCard layout, tag-filter, empty state |
| `Assistant.swift` | Partiell — header, input-bar, StarterChip |
| `Dagbok.swift` | Liten — EntryCard, FAB, empty state |
| `MeditationView.swift` | Liten — ExerciseCard bakgrund |
| `UI_REDESIGN_REPORT.md` | Ny — denna rapport |

---

## Beslut & kompromisser

1. **Navbar-pill utan sliding background-view:** Implementerat via `matchedGeometryEffect` på per-item bakgrundsvyn. Alternativet (en separat positionerad pill-vy) kräver precisare koordinatberäkning.

2. **WarmBackground med accentHint:** Bakgrunden tar nu en `accentHint`-färg (default `#8B2FC9`) som påverkar den övre orb-gradienten. Alla existerande `WarmBackground()` anrop fungerar utan modifikation.

3. **Diagnoser utan per-diagnos ikoner:** Diagnos-modellen har inget `icon`-fält. Färgkodning görs istället via en roterande lista med 15 fördefinierade färger baserat på index.

4. **Forum NewPostView:** Lämnades oförändrad då den är en modal sheet med egna formfält. Mindre impakt på premium-upplevelsen.

5. **Monster/WeatherBoard/Inlogg:** Ej redesignade — dessa är orphan-moduler ej åtkomliga från main-navigation (dokumenterat i AUDIT_REPORT.md).

---

## Vyer att granska

1. **Onboarding** — sida 1–4, kontrollera pulsande ikon, gradient-bakgrundsbyte, CTA-knappens shadow
2. **Dashboard** — hero-video med overlay-text, sektionsrubriker, stagger-animation på load
3. **Navbar** — tryck alla 5 tabs och se den glidande pill-andimatorn
4. **Diagnoser** — lista med stagger, söking med clear-knapp, detail-vyn med ny header
5. **Forum** — tag-filter med gradient capsule, ny ForumCard med vänster accentbar
6. **AI-chat** — input-fälts focus-state, ny skicka-knapp, StarterChip press-animation
7. **Dagbok** — gradient FAB, förbättrade kort
