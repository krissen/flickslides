# FlickSlides Gestdesign och Aktiveringsmodell

**Roll:** UX/UI-designer
**Datum:** 2025-01-25
**Status:** Utforskningsfas - Leverans

---

## 1. Apple Human Interface Guidelines - Sammanfattning

### 1.1 watchOS-gester (HIG-principer)

Apple betonar följande principer för gestdesign på watchOS:

**Grundprinciper:**
- Gester ska vara naturliga och intuitiva
- Undvik att överbelasta med för många gester
- Varje gest ska ha tydlig, konsekvent feedback
- System-gester har prioritet - krocka aldrig med dem

**watchOS standardgester (ska EJ användas för app-funktioner):**
- Tap: Välj/aktivera
- Long press: Kontextmeny
- Swipe: Navigera/avfärda
- Digital Crown: Scrolla/justera
- Side button: Multitasking/Apple Pay

**AssistiveTouch-gester (tillgänglighet):**

| Gest | Beskrivning | Användning |
|------|-------------|------------|
| **Pinch** | Tumme + pekfinger ihop en gång | Tap-ersättning |
| **Double pinch** | Tumme + pekfinger ihop två gånger snabbt | Sekundär aktion |
| **Clench** | Knyt handen en gång | Aktivera meny |
| **Double clench** | Knyt handen två gånger snabbt | Primär aktion |

**Viktigt:** AssistiveTouch-gester aktiveras via Settings > Accessibility > AssistiveTouch. De fungerar på Series 4+ och Ultra 1/2. Gesterna är designade för att vara MEDVETNA - de kräver distinkt muskelansträngning som skiljer dem från vanliga handrörelser.

### 1.2 Double Tap-gesten (S9/Ultra 2)

Apple introducerade "Double Tap" i watchOS 10.1 för Series 9 och Ultra 2:
- Kräver S9-chipets Neural Engine
- Officiellt stöd endast för system-aktioner (notiser, Keynote)
- **Inget officiellt API för tredjepartsappar**
- Kan aktivera "Primary Action" i watchOS 11+ via `.handGestureShortcut(.primaryAction)`

**Implikation för FlickSlides:** Ultra 1 saknar Double Tap. Vi måste använda AssistiveTouch-gester eller egen sensordetektion.

### 1.3 Haptisk feedback-konventioner

**watchOS haptiska typer (WKHapticType):**

| Typ | Användning | Beskrivning |
|-----|------------|-------------|
| `.success` | Lyckad aktion | Kort, nöjd "tick" |
| `.failure` | Misslyckad aktion | Tre snabba pulser |
| `.notification` | Uppmana uppmärksamhet | Två distinkta pulser |
| `.directionUp` | Uppåt/framåt | Stigande känsla |
| `.directionDown` | Nedåt/bakåt | Fallande känsla |
| `.click` | Neutral bekräftelse | Subtil klick |
| `.start` | Påbörjad aktivitet | Uppbyggande känsla |
| `.stop` | Avslutad aktivitet | Avslutande känsla |
| `.retry` | Försök igen | Uppmuntrande puls |

**Apple HIG-rekommendationer:**
- Använd haptik sparsamt - överanvändning trampar ut effekten
- Matcha haptik med visuell/auditiv feedback
- Bekräfta ALLA viktiga aktioner haptiskt
- Undvik haptik för bakgrundsprocesser

---

## 2. Konkurrentanalys

### 2.1 Silent Slide

**Styrkor:**
- Använder double-tap (S9/Ultra 2) för "nästa bild"
- Digital Crown för precision-bläddring
- Haptisk bekräftelse vid varje bildbyte
- Timer med haptiska nudgar (50%, 75%, 1 min kvar)
- Blackout-funktion med en knapptryckning
- "Works with any app using arrow keys"
- Automatisk anslutning över lokalt nätverk
- Ingen datainsamling

**Svagheter:**
- Begränsat till S9/Ultra 2 för gestigenkänning
- Ingen explicit aktiveringsmodell (alltid aktiv?)
- Risk för false positives vid naturlig gestikulering

**Lärdomar:** Timer-funktionen med haptiska nudgar är värdefull. Digital Crown som backup är smart.

### 2.2 PPT Control

**Styrkor:**
- Bluetooth-anslutning till Mac/Windows
- Double tap-stöd (tillagt feb 2025)
- Muspekarkontroll
- Skärmljusstyrka

**Svagheter:**
- Kräver separat desktop-app
- Komplex Bluetooth-parkoppling
- Otydligt vilka gester som stöds på äldre klockor

**Lärdomar:** Muspekare är "nice-to-have" men utanför MVP-scope.

### 2.3 WowMouse/DoublePoint

**Styrkor:**
- Handrörelser styr muspekare
- Nyp = klick
- Handvridning (handflata upp) för aktivering/avslut
- "Handflata upp + dubbelnyp" för föregående

**Svagheter:**
- Precisionssvårt - användare rapporterar instabilitet
- För generell (muspekare vs presentation)
- Wear OS-fokus

**Lärdomar:** Handvridning som "mode switch" är intressant - distinkt rörelse.

---

## 3. Gestmappning - FlickSlides

### 3.1 Gestmappningstabell

| Gest | Kommando | Feedback | Prioritet | Stöd |
|------|----------|----------|-----------|------|
| **Double pinch** | NEXT (nästa bild) | Haptisk `.success` + visuell blink | PRIMÄR | Ultra 1+ (AssistiveTouch) |
| **Double clench** | Aktivera/avaktivera Presentationsläge | Haptisk `.start`/`.stop` + visuell | PRIMÄR | Ultra 1+ (AssistiveTouch) |
| **Digital Crown vrid** | NEXT/PREV (beroende på riktning) | Haptisk `.click` per steg | SEKUNDÄR | Alla klockor |
| **Action-knapp (Ultra)** | Toggle Presentationsläge | Haptisk `.notification` | ULTRA ONLY | Ultra 1/2 |
| **Skärmknappar** | NEXT/PREV/BLACKOUT | Haptisk `.click` | FALLBACK | Alla klockor |

### 3.2 Gester som INTE ska användas

| Gest | Anledning |
|------|-----------|
| Arm-lyft (raise to wake) | För vanlig naturlig rörelse |
| Enkel pinch | För lik "peka på någon" |
| Enkel clench | Kan ske vid frustration/koncentration |
| Kraftig armvift | Presentatörer gestikulerar konstant |
| Handvridning ensam | Kan ske vid anpassning av klocka |

### 3.3 Motivering

**Double pinch för NEXT:**
- Kräver medveten, upprepad rörelse
- Ovanlig för naturlig gestikulering
- Snabb att utföra (0.3-0.5s)
- Validerad av Apple (Keynote, AssistiveTouch)

**Double clench för Presentationsläge:**
- Kraftfullare än pinch - kräver medvetet
- "Knyta näven" = "ta kontroll" (semantisk koppling)
- Distinkt från alla vanliga presentationsgester
- AssistiveTouch har redan tränat användare

**Digital Crown som backup:**
- Alltid tillgänglig
- Precision vid behov av specifik slide
- Ingen risk för false positive

---

## 4. Aktiveringsmodell - "Presentationsläge"

### 4.1 Designprincip

**Problem:** Gesttolkning som alltid är aktiv = false positives.
**Lösning:** Explicit "Presentationsläge" som måste aktiveras.

### 4.2 Aktiveringsflöde (text-diagram)

```
[IDLE STATE]
    |
    | Användare startar FlickSlides-app på Watch
    v
[APP ÖPPEN - EJ AKTIVT]
    |
    | Skärm visar: "Double-clench för att starta"
    | eller: tryck "Starta presentation"-knapp
    | eller: tryck Action-knapp (Ultra)
    v
[PRESENTATIONSLÄGE AKTIVT]
    |
    | Haptik: .start (uppbyggande vibration)
    | Skärm: Grön indikator, "Aktivt"
    | Watch face: Complication blinkar grönt
    | iPhone: Visar "Ansluten - Presentationsläge"
    | Mac: Menyrad-ikon går från grå till grön
    |
    | -- Gester lyssnas nu --
    | Double pinch -> NEXT -> haptik .success
    | Digital Crown -> NEXT/PREV -> haptik .click
    |
    v
[AVSLUTA PRESENTATIONSLÄGE]
    |
    | Double-clench (igen)
    | eller: tryck "Avsluta"-knapp
    | eller: Action-knapp (Ultra)
    | eller: timeout efter 2h utan aktivitet
    |
    | Haptik: .stop (avslutande vibration)
    | Skärm: Grå indikator, "Inaktivt"
    v
[IDLE STATE]
```

### 4.3 Visuella tillstånd

| Tillstånd | Watch-skärm | Watch Complication | iPhone | Mac menyrad |
|-----------|-------------|--------------------|--------|-------------|
| App stängd | - | Grå ikon | - | Grå ikon |
| App öppen, ej aktiv | "Starta presentation" | Grå ikon | "Redo att ansluta" | Grå ikon |
| Presentationsläge | Grön puls, slide-info | Grön ikon | "Aktivt - [Mac-namn]" | Grön ikon |
| Fel/frånkopplad | Röd varning | Röd ikon | "Tappad anslutning" | Röd ikon |

### 4.4 Timeout-logik

- **Aktiv timeout:** Om ingen gest/interaktion på 5 minuter -> haptisk påminnelse
- **Förlängt timeout:** 2 timmar -> automatisk avaktivering med haptik `.stop`
- **Anledning:** Förhindra att presentation-läge är kvar efter att användaren glömt stänga av

---

## 5. Haptiska mönster - FlickSlides

### 5.1 Definitioner

| Händelse | Haptik-typ | Mönster | Beskrivning |
|----------|------------|---------|-------------|
| Gest bekräftad (NEXT) | `.success` | En kort tick | "Jag hörde dig" |
| Gest bekräftad (PREV) | `.directionDown` | Fallande tick | "Vi går bakåt" |
| Presentationsläge START | `.start` | Uppbyggande sekvens | "Nu kör vi" |
| Presentationsläge STOPP | `.stop` | Avslutande sekvens | "Klart" |
| Anslutning etablerad | `.notification` | Dubbel tick | "Mac hittad" |
| Anslutning tappad | `.failure` | Tre snabba | "Någonting är fel" |
| Timer-varning (5 min kvar) | `.notification` | Dubbel tick | "Tid att avsluta snart" |
| Timer-varning (1 min kvar) | `.retry` | Tre pulser | "Sista minuten!" |
| Gest avvisad (cooldown) | `.click` | Kort subtil | "Vänta lite" |

---

## 6. Wireframe-beskrivningar

### 6.1 watchOS - Apple Watch

**Huvudskärm (Presentationsläge INAKTIVT):**
```
+---------------------------+
|      FlickSlides          |
|                           |
|   [  STARTA PRESENTATION ]|
|   (stor, tydlig knapp)    |
|                           |
|   Ansluten: Kristians Mac |
|   (liten text, grön punkt)|
|                           |
|   "Double-clench startar" |
|   (instruktionstext)      |
+---------------------------+
```

**Huvudskärm (Presentationsläge AKTIVT):**
```
+---------------------------+
|    AKTIVT    [pulserar]   |
|                           |
|        Slide 5/24         |
|        (stor text)        |
|                           |
|   [<]         [>]         |
|   (fallback-knappar)      |
|                           |
|      12:34 förflutit      |
|   "Double-clench avslutar"|
+---------------------------+
```

**Complication (Circular):**
```
Inaktiv:  [FS] (grå)
Aktiv:    [>]  (grön, pulserar)
Fel:      [!]  (röd)
```

### 6.2 iOS - iPhone

**Huvudskärm:**
```
+----------------------------------+
|          FlickSlides             |
|                                  |
|  +----------------------------+  |
|  |  Anslutningsstatus         |  |
|  |  [GRÖN CIRKEL] Ansluten    |  |
|  |  Kristians MacBook Pro     |  |
|  +----------------------------+  |
|                                  |
|  Presentationsläge: INAKTIVT    |
|  (Starta från klockan)          |
|                                  |
|  +----------------------------+  |
|  |       MANUELL KONTROLL     |  |
|  |   [<< PREV]    [NEXT >>]   |  |
|  |        [ BLACKOUT ]        |  |
|  +----------------------------+  |
|                                  |
|  Timer: 00:00                    |
|  [ STARTA TIMER ]                |
|                                  |
|  [Inställningar]                 |
+----------------------------------+
```

### 6.3 macOS - Menyradsapp

**Menyrad-ikon:**
```
Inaktiv:  [FS] (grå)
Ansluten: [FS] (blå)
Aktiv:    [FS] (grön, pulserar subtilt)
Fel:      [FS] (röd)
```

**Menyrads-dropdown:**
```
+----------------------------------+
|  FlickSlides                     |
+----------------------------------+
|  Status: Ansluten                |
|  iPhone: Kristians iPhone        |
|  Presentationsläge: Aktivt       |
+----------------------------------+
|  Senaste kommando:               |
|  NEXT (för 3 sek sedan)          |
+----------------------------------+
|  [ ] Starta vid systemstart      |
|  [Inställningar...]              |
+----------------------------------+
|  [Avsluta FlickSlides]           |
+----------------------------------+
```

---

## 7. Riskanalys - False Positives

### 7.1 Naturliga rörelser som KAN misstolkas

| Rörelse | Risk | Mitigering |
|---------|------|------------|
| Klappa händer | MEDEL - kan ge acceleration-spike | Require specific pinch-mönster, inte bara spike |
| Peka på någon | LÅG - enkel fingerrörelse | Vi använder DOUBLE pinch, inte enkel |
| Lyfta hand för att se klockan | LÅG | Ingen gest baserad på arm-lyft |
| Gestikulera brett | LÅG | Kräver specifik finger-till-finger-rörelse |
| Justera klocka/armband | LÅG | Rörelser är långsammare än gesttröskel |
| Korsa armar | MEDEL - kan ge clench-liknande | Cooldown-period, krav på DOUBLE clench |
| Dricka vatten | LÅG | Enkel griprörelse, inte dubbelnyp |

### 7.2 Mittigeringsstrategier

**Strategi 1: Explicit Presentationsläge**
- Gesttolkning ENDAST när användaren aktivt startat
- Användare måste göra medveten aktion för att "slå på"
- Eliminerar 100% av false positives utanför presentationstid

**Strategi 2: Double-gester**
- Kräver två snabba repetitioner (double-pinch, double-clench)
- En enkel pinch/clench ignoreras
- Matematiskt: sannolikhet för två naturliga pinches inom 0.5s är minimal

**Strategi 3: Cooldown-period**
- 1.0-2.0 sekunder mellan accepterade gester
- Förhindrar "maskingeväreffekt" från skakiga rörelser
- Konfigurerbar av användare

**Strategi 4: Mönsterigenkänning (ej bara threshold)**
- Accelerometer-spike ensam räcker INTE
- Kräver specifik tidsprofil för pinch (snabb-in, snabb-ut)
- Tränas med ML-modell i framtida version

**Strategi 5: Haptisk bekräftelse**
- Användaren KÄNNER direkt om gest tolkades
- Om de inte avsåg gesten -> de vet att justera beteende

### 7.3 Risk-matris

| Risk | Sannolikhet | Påverkan | Prioritet |
|------|-------------|----------|-----------|
| False positive NEXT under presentation | Låg (med double-gest + cooldown) | Hög (publikstörning) | KRITISK |
| False positive aktivering av Presentationsläge | Mycket låg (kräver double-clench) | Medel | MEDEL |
| Missad avsiktlig gest | Medel (vid låg känslighet) | Medel (använder fallback) | MEDEL |
| Förvirring om tillstånd (aktivt/inaktivt) | Medel | Låg (tydlig visuell feedback) | LÅG |

---

## 8. Rekommendationer till watchOS-utvecklare

### 8.1 Gestigenkänning - teknisk vägledning

```
REKOMMENDATION: Börja med AssistiveTouch, förbered för egen detektion

1. MVP (Fas 1):
   - Utnyttja AssistiveTouch double-pinch som UIAction-trigger
   - Implementera Digital Crown som primär input
   - Action-knapp för Ultra

2. Iteration (Fas 2):
   - Egen sensorbaserad detektion som komplement
   - CoreMotion accelerometer + gyroskop
   - Trösklar: 0.8g acceleration, dubbelspike inom 0.5s

3. Framtid (Fas 3):
   - ML-modell för precision
   - CreateML med träningsdata från verkliga användare
```

### 8.2 Kritiska implementationsdetaljer

- **Debounce:** Minimum 1.0s mellan accepterade gester
- **Aktiveringslogik:** Bool `isPresentationMode` - ENDAST tolka gester när true
- **Haptik-timing:** Skicka feedback INNAN kommando till iPhone (<50ms)
- **Batterihantering:** Sensor-polling endast i aktivt läge

---

## 9. Sammanfattning och beslut

### 9.1 Gestval - beslut

| Beslut | Motivering |
|--------|------------|
| **NEXT = Double pinch** | Validerat av Apple, distinkt, snabb |
| **PREV = Digital Crown** | Precision, ingen false-positive-risk |
| **Toggle Presentationsläge = Double clench** | Kraftfull, medveten, semantiskt passande |
| **Action-knapp (Ultra) = Toggle** | Dedikerad fysisk knapp = noll ambiguitet |

### 9.2 Aktiveringsmodell - beslut

| Beslut | Motivering |
|--------|------------|
| **Explicit Presentationsläge** | Eliminerar false positives utanför presentation |
| **Två aktiveringsmetoder** | Double-clench + skärmknapp = flexibilitet |
| **Auto-timeout 2h** | Säkerhetsnät om användare glömmer |

### 9.3 Öppna frågor för Produktägare

1. **Digital Crown-riktning:** Ska vridning medsols = NEXT eller PREV?
2. **BLACKOUT-gest:** Ska det finnas en dedikerad gest, eller endast skärmknapp?
3. **Timer-default:** Vilken standardlängd på presentationstimer?

---

## Referenser

- **Apple Human Interface Guidelines - Gestures:** https://developer.apple.com/design/human-interface-guidelines/gestures
- **Apple AssistiveTouch for Watch:** https://support.apple.com/guide/watch/use-assistivetouch-apd510a206b0/watchos
- **Apple WKHapticType:** https://developer.apple.com/documentation/watchkit/wkhaptictype
- **Silent Slide App Store:** https://apps.apple.com/app/silent-slide/id6502353616
- **PPT Control App Store:** https://apps.apple.com/app/ppt-control/id1465679264

---

*Dokument skapat av UX/UI-designer, FlickSlides-projektet*
*Datum: 2025-01-25*
