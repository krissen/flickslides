# FlickSlides Testplan

**Version:** 1.0
**Datum:** 2025-01-25
**Ansvarig:** QA/Testare
**Status:** UTKAST

---

## 1. Inledning

### 1.1 Syfte

Denna testplan beskriver en systematisk approach for att verifiera FlickSlides-systemets funktionalitet, tillforlitlighet och användbarhet. Fokus ligger på att vara en **fientlig testare** - aktivt försöka få systemet att misslyckas genom att simulera verkliga, ibland oförutsägbara, användningsscenarier.

### 1.2 Målsättning

- Säkerställa **noll false positives** under 30 minuters presentation
- Verifiera end-to-end-latens **under 500ms**
- Bekräfta **batterförbrukning under 10% per timme**
- Validera funktion på **Apple Watch Ultra 1** (Produktägarens primära enhet)

### 1.3 Avgränsningar

- Testning fokuserar på watchOS 11+, iOS 18+, macOS 15+ (Sequoia)
- Primär testenhet: Apple Watch Ultra 1
- Sekundär jämförelse: Apple Watch Series 9 eller Ultra 2 (om tillgänglig)

---

## 2. Testmiljö

### 2.1 Hårdvarukrav

| Enhet | Roll | Krav |
|-------|------|------|
| Apple Watch Ultra 1 | Primär testning | Produktägarens enhet, MÅSTE fungera |
| Apple Watch Series 9/Ultra 2 | Jämförelse | För Double Tap-verifiering |
| iPhone | Brygga | iOS 18+, parkopplad med Watch |
| Mac | Mottagare | macOS 15+ (Sequoia) |

### 2.2 Mjukvarukrav

| Applikation | Version | Syfte |
|-------------|---------|-------|
| Keynote | Senaste | Primär presentationsapp |
| Microsoft PowerPoint | Senaste | Kompatibilitetstest |
| PDF Preview | System | Alternativ presentation |
| Safari | Senaste | Google Slides-test |
| Google Chrome | Senaste | Alternativ browser-test |

### 2.3 Testmiljöer - Nätverksscenarier

| Scenario | Beskrivning |
|----------|-------------|
| **Standard** | iPhone och Mac på samma Wi-Fi-nätverk |
| **Bluetooth-only** | Wi-Fi avstängt, enbart Bluetooth |
| **BT-störning** | Många aktiva BT-enheter i närheten |
| **Svagt Wi-Fi** | iPhone i gränsen av Wi-Fi-räckvidd |
| **Nätverksbyte** | Mac byter nätverk under session |

---

## 3. Acceptanskriterier

### 3.1 Kvantitativa mål

| Krav | Mål | Kritisk gräns | Mätmetod |
|------|-----|---------------|----------|
| Gestrespons | < 500 ms | < 750 ms | Loggning med tidsstämplar |
| False positives | 0 per 30 min | < 2 per 30 min | Scenariotest med naturliga rörelser |
| False negatives | < 5% | < 10% | Räkning av missade avsiktliga gester |
| Anslutningsstabilitet | 100% | > 98% | 1h kontinuerlig session |
| Batterförbrukning (Watch) | < 10%/h | < 15%/h | Mätning under aktiv presentation |
| Återanslutning | < 5s | < 10s | Tid från avbrott till återhämtning |

### 3.2 Kvalitativa krav

- Användare ska kunna installera och koppla ihop systemet **utan utvecklarhjälp**
- Haptisk feedback ska vara **tydlig och distinkt**
- UI ska visa **aktuell anslutningsstatus** korrekt i realtid
- Systemgester (Double Tap på S9+) ska **inte konfliktera** med FlickSlides

---

## 4. Funktionella tester

### 4.1 Gestigenkänning

#### TC-G01: Double Clench - Aktivering

| Fält | Värde |
|------|-------|
| **ID** | TC-G01 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Verifiera att double clench aktiverar Presentationsläge |
| **Förkrav** | App startad, Presentationsläge INAKTIVT |
| **Steg** | 1. Utför double clench (två snabba knytnävsslag) |
| | 2. Observera haptisk feedback |
| | 3. Verifiera UI-indikator |
| **Förväntat** | Haptisk bekräftelse, UI visar "Aktivt" |
| **Acceptans** | Lyckad aktivering i >95% av fallen |

#### TC-G02: Double Clench - Avaktivering

| Fält | Värde |
|------|-------|
| **ID** | TC-G02 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Verifiera att double clench avaktiverar Presentationsläge |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Utför double clench |
| | 2. Observera haptisk feedback |
| | 3. Verifiera UI-indikator |
| **Förväntat** | Haptisk bekräftelse (annorlunda mönster), UI visar "Inaktivt" |
| **Acceptans** | Lyckad avaktivering i >95% av fallen |

#### TC-G03: Double Pinch - Nästa slide

| Fält | Värde |
|------|-------|
| **ID** | TC-G03 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Verifiera att double pinch avancerar till nästa slide |
| **Förkrav** | Presentationsläge AKTIVT, presentation pågår på Mac |
| **Steg** | 1. Utför double pinch (två snabba nyp) |
| | 2. Observera haptisk feedback på Watch |
| | 3. Verifiera att Mac visar nästa slide |
| | 4. Mät tid från gest till slidebytet |
| **Förväntat** | Slide avancerar, latens < 500ms |
| **Acceptans** | Lyckad i >95%, latens < 500ms i >90% |

#### TC-G04: Flick - Nästa slide (alternativ)

| Fält | Värde |
|------|-------|
| **ID** | TC-G04 |
| **Prioritet** | HÖG |
| **Beskrivning** | Verifiera att handflick framåt avancerar slide |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Utför snabb handflick framåt (>0.8g, >18 grader) |
| | 2. Verifiera slidebytet på Mac |
| **Förväntat** | Slide avancerar |
| **Acceptans** | Lyckad i >90% av fallen |

#### TC-G05: Flick bakåt - Föregående slide

| Fält | Värde |
|------|-------|
| **ID** | TC-G05 |
| **Prioritet** | HÖG |
| **Beskrivning** | Verifiera att handflick bakåt går till föregående slide |
| **Förkrav** | Presentationsläge AKTIVT, inte på första slide |
| **Steg** | 1. Utför snabb handflick bakåt |
| | 2. Verifiera slidebytet på Mac |
| **Förväntat** | Slide går bakåt |
| **Acceptans** | Lyckad i >90% av fallen |

#### TC-G06: Blackout-kommando

| Fält | Värde |
|------|-------|
| **ID** | TC-G06 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Verifiera att blackout-gesten svärtar skärmen |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Utför blackout-gest (TBD baserat på UX-design) |
| | 2. Verifiera att presentationen blir svart |
| **Förväntat** | Skärmen blir svart (B-tangent simulerad) |
| **Acceptans** | Lyckad i >95% av fallen |

### 4.2 Anslutning och kommunikation

#### TC-C01: Watch-iPhone-parkoppling

| Fält | Värde |
|------|-------|
| **ID** | TC-C01 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Verifiera WCSession-anslutning |
| **Förkrav** | Watch och iPhone parkopplade, appar installerade |
| **Steg** | 1. Starta Watch-appen |
| | 2. Starta iPhone-appen |
| | 3. Verifiera anslutningsindikator |
| **Förväntat** | Anslutning etableras automatiskt inom 5s |
| **Acceptans** | Lyckad första gången i >95% av fallen |

#### TC-C02: iPhone-Mac-parkoppling

| Fält | Värde |
|------|-------|
| **ID** | TC-C02 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Verifiera MultipeerConnectivity-anslutning |
| **Förkrav** | iPhone och Mac på samma nätverk |
| **Steg** | 1. Starta Mac-appen (advertiser) |
| | 2. Starta iPhone-appen (browser) |
| | 3. Välj Mac från listan |
| | 4. Verifiera anslutning |
| **Förväntat** | Anslutning etableras, båda visar "Ansluten" |
| **Acceptans** | Lyckad inom 10s |

#### TC-C03: End-to-end-kedja

| Fält | Värde |
|------|-------|
| **ID** | TC-C03 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Verifiera hela kedjan Watch -> iPhone -> Mac |
| **Förkrav** | Alla tre enheter anslutna |
| **Steg** | 1. Aktivera Presentationsläge på Watch |
| | 2. Utför gest på Watch |
| | 3. Verifiera att Mac-appen tar emot kommandot |
| **Förväntat** | Kommando når Mac inom 500ms |
| **Acceptans** | Lyckad i >98% av fallen |

#### TC-C04: Återanslutning efter avbrott

| Fält | Värde |
|------|-------|
| **ID** | TC-C04 |
| **Prioritet** | HÖG |
| **Beskrivning** | Verifiera automatisk återanslutning |
| **Förkrav** | Systemet fungerar |
| **Steg** | 1. Avbryt Bluetooth (gå ur räckhåll eller stäng av) |
| | 2. Vänta 10 sekunder |
| | 3. Återaktivera/kom tillbaka i räckhåll |
| | 4. Mät tid till återanslutning |
| **Förväntat** | Automatisk återanslutning < 10s |
| **Acceptans** | Återanslutning sker utan användarinteraktion |

### 4.3 macOS-specifika tester

#### TC-M01: Keynote-kontroll

| Fält | Värde |
|------|-------|
| **ID** | TC-M01 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Verifiera tangentbordsstyrning i Keynote helskärm |
| **Förkrav** | Keynote-presentation i helskärmsläge |
| **Steg** | 1. Skicka NEXT-kommando |
| | 2. Skicka PREV-kommando |
| | 3. Skicka BLACKOUT-kommando |
| **Förväntat** | Alla kommandon fungerar |
| **Acceptans** | 100% funktionalitet |

#### TC-M02: Keynote fönsterläge

| Fält | Värde |
|------|-------|
| **ID** | TC-M02 |
| **Prioritet** | HÖG |
| **Beskrivning** | Verifiera styrning i Keynote fönsterläge |
| **Förkrav** | Keynote-presentation i fönsterläge |
| **Steg** | 1. Verifiera att Keynote har fokus |
| | 2. Skicka NEXT-kommando |
| **Förväntat** | Slide avancerar |
| **Varning** | Kan kräva att Keynote är fokuserad app |

#### TC-M03: PowerPoint-kontroll

| Fält | Värde |
|------|-------|
| **ID** | TC-M03 |
| **Prioritet** | HÖG |
| **Beskrivning** | Verifiera tangentbordsstyrning i PowerPoint |
| **Förkrav** | PowerPoint-presentation i presentationsläge |
| **Steg** | 1. Skicka NEXT-kommando |
| | 2. Skicka PREV-kommando |
| **Förväntat** | Alla kommandon fungerar |
| **Acceptans** | 100% funktionalitet |

#### TC-M04: PDF Preview-kontroll

| Fält | Värde |
|------|-------|
| **ID** | TC-M04 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Verifiera navigering i PDF Preview |
| **Förkrav** | PDF öppen i Preview |
| **Steg** | 1. Skicka NEXT-kommando |
| | 2. Skicka PREV-kommando |
| **Förväntat** | Navigering till nästa/föregående sida |
| **Not** | Kan kräva att man är i enkelsidesläge |

#### TC-M05: Google Slides i Safari

| Fält | Värde |
|------|-------|
| **ID** | TC-M05 |
| **Prioritet** | HÖG |
| **Beskrivning** | Verifiera styrning i Google Slides (browser) |
| **Förkrav** | Google Slides i presentationsläge i Safari |
| **Steg** | 1. Skicka NEXT-kommando |
| | 2. Skicka PREV-kommando |
| **Förväntat** | Slides navigerar korrekt |
| **Acceptans** | Fungerar i Safari och Chrome |

#### TC-M06: Accessibility-behörighet

| Fält | Värde |
|------|-------|
| **ID** | TC-M06 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Verifiera behörighetsflöde vid första start |
| **Förkrav** | Ny installation, inga behörigheter givna |
| **Steg** | 1. Starta Mac-appen |
| | 2. Verifiera att behörighetsdialog visas |
| | 3. Följ instruktioner till Systeminställningar |
| | 4. Aktivera behörighet |
| | 5. Verifiera att appen fungerar |
| **Förväntat** | Tydliga instruktioner, app fungerar efter aktivering |
| **Acceptans** | Användare kan genomföra utan hjälp |

---

## 5. Edge Cases och Gränsvärden

### 5.1 Naturliga rörelser (False Positive-tester)

Dessa tester ska **INTE** trigga någon gest.

#### TC-FP01: Naturlig gestikulering

| Fält | Värde |
|------|-------|
| **ID** | TC-FP01 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Livlig gestikulering under presentation |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Håll 10-minuters presentation med naturlig gestikulering |
| | 2. Peka, vifta, illustrera med händerna |
| | 3. Räkna alla oavsiktliga triggers |
| **Förväntat** | NOLL oavsiktliga triggers |
| **Acceptans** | Absolut noll tolerance |

#### TC-FP02: Handklapp

| Fält | Värde |
|------|-------|
| **ID** | TC-FP02 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Klappa händer ska INTE trigga gest |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Klappa händer normalt 10 gånger |
| | 2. Klappa entusiastiskt 10 gånger |
| **Förväntat** | Ingen gest triggas |
| **Acceptans** | 100% - noll false positives |

#### TC-FP03: Titta på klockan

| Fält | Värde |
|------|-------|
| **ID** | TC-FP03 |
| **Prioritet** | HÖG |
| **Beskrivning** | Lyfta arm för att titta på klockan |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Lyft armen för att titta på klockan 10 gånger |
| | 2. Variera hastighet och vinkel |
| **Förväntat** | Ingen gest triggas |
| **Acceptans** | 100% - noll false positives |

#### TC-FP04: Peka på skärm

| Fält | Värde |
|------|-------|
| **ID** | TC-FP04 |
| **Prioritet** | HÖG |
| **Beskrivning** | Peka mot projektorduk/skärm |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Peka snabbt mot skärmen 20 gånger |
| | 2. Variera vinklar och hastighet |
| **Förväntat** | Ingen gest triggas |
| **Acceptans** | 100% - noll false positives |

#### TC-FP05: Dricka kaffe/vatten

| Fält | Värde |
|------|-------|
| **ID** | TC-FP05 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Lyfta kopp för att dricka |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Simulera att dricka ur kopp 5 gånger |
| **Förväntat** | Ingen gest triggas |
| **Acceptans** | 100% - noll false positives |

#### TC-FP06: Skaka hand

| Fält | Värde |
|------|-------|
| **ID** | TC-FP06 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Handskakning ska inte trigga gest |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Skaka hand med någon 5 gånger |
| **Förväntat** | Ingen gest triggas |
| **Acceptans** | 100% - noll false positives |

#### TC-FP07: Skriva på whiteboard

| Fält | Värde |
|------|-------|
| **ID** | TC-FP07 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Skrivrörelse på whiteboard |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Simulera skrivning på whiteboard i 2 minuter |
| **Förväntat** | Ingen gest triggas |
| **Acceptans** | 100% - noll false positives |

#### TC-FP08: Hålla mikrofon

| Fält | Värde |
|------|-------|
| **ID** | TC-FP08 |
| **Prioritet** | LÅG |
| **Beskrivning** | Hålla och röra mikrofon |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Håll mikrofon (eller simulerad) |
| | 2. Rör dig naturligt medan du talar |
| **Förväntat** | Ingen gest triggas |
| **Acceptans** | 100% - noll false positives |

### 5.2 Gränsvärdestest

#### TC-GV01: Svaga gester

| Fält | Värde |
|------|-------|
| **ID** | TC-GV01 |
| **Prioritet** | HÖG |
| **Beskrivning** | Testa gester strax under tröskel |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Utför svag version av varje gest |
| | 2. Dokumentera vilka som triggar |
| **Förväntat** | Svaga gester ska INTE triggas |
| **Syfte** | Säkerställa att trösklar är korrekt satta |

#### TC-GV02: Extremt snabba gester

| Fält | Värde |
|------|-------|
| **ID** | TC-GV02 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Verifiera debounce-logik |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Utför gest |
| | 2. Omedelbart (inom 0.5s) utför gest igen |
| | 3. Räkna antal registrerade kommandon |
| **Förväntat** | Endast en gest registrerad (debounce 1s) |
| **Acceptans** | Debounce fungerar |

#### TC-GV03: Gest med fel hand

| Fält | Värde |
|------|-------|
| **ID** | TC-GV03 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Gest med hand utan klocka |
| **Förkrav** | Klocka på vänster handled |
| **Steg** | 1. Utför gest med höger hand |
| **Förväntat** | Ingen gest registreras (klocka är på andra armen) |
| **Syfte** | Verifiera att endast klockhand räknas |

### 5.3 Systemstörningar

#### TC-S01: Inkommande samtal

| Fält | Värde |
|------|-------|
| **ID** | TC-S01 |
| **Prioritet** | HÖG |
| **Beskrivning** | Verifiera beteende vid inkommande samtal |
| **Förkrav** | Presentationsläge AKTIVT, presentation pågår |
| **Steg** | 1. Ring till iPhone från annan telefon |
| | 2. Observera Watch och Mac |
| | 3. Avvisa samtal |
| | 4. Verifiera att systemet återhämtar sig |
| **Förväntat** | System fungerar efter samtal avvisats |
| **Not** | Dokumentera om samtal pausar gestdetektering |

#### TC-S02: Notifikationer

| Fält | Värde |
|------|-------|
| **ID** | TC-S02 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Verifiera beteende vid notifikationer |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Skicka flera notifikationer till Watch |
| | 2. Utför gest medan notifikation visas |
| **Förväntat** | Gester ska fortfarande fungera |
| **Acceptans** | Notifikationer påverkar inte gestdetektering |

#### TC-S03: Siri-aktivering

| Fält | Värde |
|------|-------|
| **ID** | TC-S03 |
| **Prioritet** | HÖG |
| **Beskrivning** | Verifiera att "Raise to Speak" inte konflikter |
| **Förkrav** | "Raise to Speak" aktiverat, Presentationsläge AKTIVT |
| **Steg** | 1. Lyft armen mot ansiktet (trigger för Siri) |
| | 2. Observera om Siri aktiveras |
| | 3. Observera om gest triggas |
| **Förväntat** | Antingen Siri ELLER gest, inte båda |
| **Not** | Kan kräva rekommendation att stänga av Raise to Speak |

#### TC-S04: Double Tap-konflikt (Series 9+)

| Fält | Värde |
|------|-------|
| **ID** | TC-S04 |
| **Prioritet** | HÖG |
| **Beskrivning** | Verifiera att systemets Double Tap inte konflikter |
| **Förkrav** | Series 9 eller Ultra 2 med Double Tap aktiverat |
| **Steg** | 1. Utför double pinch (vår gest) |
| | 2. Observera om systemets Double Tap aktiveras |
| **Förväntat** | Ingen konflikt, eller dokumenterad workaround |
| **Not** | Ultra 1 har INTE Double Tap - detta är jämförelsetest |

#### TC-S05: Glömt stänga av gestläge

| Fält | Värde |
|------|-------|
| **ID** | TC-S05 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Vad händer om användaren glömmer avaktivera? |
| **Förkrav** | Presentationsläge AKTIVT |
| **Steg** | 1. Stäng Mac-appen |
| | 2. Gå iväg med klockan |
| | 3. Rör dig normalt i 10 minuter |
| **Förväntat** | Inga negativa effekter, rimlig batterförbrukning |
| **Syfte** | Verifiera fail-safe beteende |

---

## 6. Nätverks- och anslutningsscenarier

### 6.1 Standardscenarier

#### TC-N01: Wi-Fi + Bluetooth

| Fält | Värde |
|------|-------|
| **ID** | TC-N01 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Normalt läge med båda aktiva |
| **Steg** | 1. Anslut alla enheter på samma Wi-Fi |
| | 2. Verifiera full funktionalitet |
| | 3. Mät latens |
| **Förväntat** | Latens < 500ms |

#### TC-N02: Endast Bluetooth

| Fält | Värde |
|------|-------|
| **ID** | TC-N02 |
| **Prioritet** | HÖG |
| **Beskrivning** | Fallback till enbart Bluetooth |
| **Steg** | 1. Stäng av Wi-Fi på iPhone |
| | 2. Verifiera att systemet fungerar |
| | 3. Mät latens |
| **Förväntat** | Fungerar, latens kanske högre |
| **Acceptans** | Latens < 750ms |

### 6.2 Störningsscenarier

#### TC-N03: BT-trängsel

| Fält | Värde |
|------|-------|
| **ID** | TC-N03 |
| **Prioritet** | HÖG |
| **Beskrivning** | Många BT-enheter i närheten |
| **Steg** | 1. Aktivera 5+ BT-enheter i rummet |
| | 2. Testa full funktionalitet |
| | 3. Mät latens och pakeförlust |
| **Förväntat** | Fungerar med acceptabel latens |
| **Not** | Simulerar konferensrum |

#### TC-N04: Wi-Fi-störning

| Fält | Värde |
|------|-------|
| **ID** | TC-N04 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Svagt eller instabilt Wi-Fi |
| **Steg** | 1. Placera iPhone i gränsen av Wi-Fi-räckvidd |
| | 2. Testa 10 gester |
| | 3. Dokumentera misslyckanden |
| **Förväntat** | Automatisk fallback till BT |

### 6.3 Avbrott och återhämtning

#### TC-N05: iPhone lämnar räckhåll

| Fält | Värde |
|------|-------|
| **ID** | TC-N05 |
| **Prioritet** | HÖG |
| **Beskrivning** | iPhone flyttas ur räckhåll under presentation |
| **Steg** | 1. Starta presentation |
| | 2. Flytta iPhone till annat rum |
| | 3. Verifiera att Watch och Mac indikerar avbrott |
| | 4. Flytta tillbaka iPhone |
| | 5. Mät tid till återanslutning |
| **Förväntat** | Tydlig indikering, automatisk återanslutning < 10s |

#### TC-N06: Mac-app kraschar

| Fält | Värde |
|------|-------|
| **ID** | TC-N06 |
| **Prioritet** | HÖG |
| **Beskrivning** | Mac-appen stängs/kraschar |
| **Steg** | 1. Starta presentation |
| | 2. Force-quit Mac-appen |
| | 3. Verifiera att iPhone/Watch indikerar |
| | 4. Starta Mac-appen igen |
| | 5. Verifiera automatisk återanslutning |
| **Förväntat** | Tydlig indikering, återanslutning utan ny parkoppling |

#### TC-N07: iPhone-skärm låst

| Fält | Värde |
|------|-------|
| **ID** | TC-N07 |
| **Prioritet** | KRITISK |
| **Beskrivning** | iPhone i fickan med låst skärm |
| **Förkrav** | Alla enheter anslutna |
| **Steg** | 1. Lås iPhone-skärmen |
| | 2. Lägg iPhone i fickan |
| | 3. Utför 10 gester från Watch |
| **Förväntat** | Alla gester fungerar |
| **Acceptans** | 100% - kritiskt för användbarhet |

---

## 7. Apple Watch Ultra 1-specifika tester

### 7.1 Primära tester

#### TC-U01: Action-knapp

| Fält | Värde |
|------|-------|
| **ID** | TC-U01 |
| **Prioritet** | HÖG |
| **Beskrivning** | Verifiera Action-knapp-integration |
| **Förkrav** | Ultra 1, App Intent konfigurerat |
| **Steg** | 1. Konfigurera Action-knappen för FlickSlides |
| | 2. Tryck på Action-knappen |
| | 3. Verifiera att Presentationsläge aktiveras |
| **Förväntat** | Snabb aktivering via fysisk knapp |
| **Not** | Alternativ till double-clench |

#### TC-U02: Utan S9-chip

| Fält | Värde |
|------|-------|
| **ID** | TC-U02 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Verifiera att alla funktioner fungerar utan S9 |
| **Förkrav** | Ultra 1 (S8-chip) |
| **Steg** | 1. Kör fullständig testsvit |
| | 2. Dokumentera eventuella begränsningar |
| **Förväntat** | Full funktionalitet |
| **Acceptans** | Ingen funktionalitet kräver S9 |

#### TC-U03: Batteritest Ultra 1

| Fält | Värde |
|------|-------|
| **ID** | TC-U03 |
| **Prioritet** | HÖG |
| **Beskrivning** | Mät batteriförbrukning under presentation |
| **Steg** | 1. Ladda klockan till 100% |
| | 2. Notera batterinivå |
| | 3. Kör 1 timmes presentation med gester var 2:a minut |
| | 4. Notera batterinivå efter |
| **Förväntat** | Förbrukning < 10% per timme |
| **Not** | Ultra 1 har större batteri - kan vara bättre än kravet |

### 7.2 Jämförelsetest (om tillgänglig Series 9/Ultra 2)

#### TC-U04: Double Tap-jämförelse

| Fält | Värde |
|------|-------|
| **ID** | TC-U04 |
| **Prioritet** | MEDEL |
| **Beskrivning** | Jämför vår double-pinch med systemets Double Tap |
| **Förkrav** | Series 9 eller Ultra 2 |
| **Steg** | 1. Testa systemets Double Tap (watchOS 11 Primary Action) |
| | 2. Testa vår double-pinch |
| | 3. Dokumentera skillnader i tillförlitlighet |
| **Förväntat** | Vår implementation jämförbar eller bättre för vårt use case |

---

## 8. Användaracceptanstest (UAT)

### 8.1 Installation och setup

#### TC-UAT01: Förstainstallation

| Fält | Värde |
|------|-------|
| **ID** | TC-UAT01 |
| **Prioritet** | HÖG |
| **Beskrivning** | Ny användare installerar och konfigurerar |
| **Testperson** | Extern person utan utvecklarbakgrund |
| **Steg** | 1. Ge användaren instruktion att installera |
| | 2. Observera utan att hjälpa |
| | 3. Dokumentera alla problem och frågor |
| **Förväntat** | Lyckad setup utan hjälp |
| **Not** | Mät tid och frustrationsmoment |

### 8.2 Presentation simulation

#### TC-UAT02: 30-minuters presentation

| Fält | Värde |
|------|-------|
| **ID** | TC-UAT02 |
| **Prioritet** | KRITISK |
| **Beskrivning** | Realistisk presentationssimulering |
| **Testperson** | Presentatör som ger riktig presentation |
| **Steg** | 1. Förklara gester på 2 minuter |
| | 2. Låt användaren presentera i 30 minuter |
| | 3. Räkna false positives och false negatives |
| | 4. Efterintervju: "Litade du på systemet?" |
| **Förväntat** | 0 false positives, < 5% false negatives |
| **Acceptans** | Användaren säger "Ja, jag litade på det" |

### 8.3 Förtroende-test

#### TC-UAT03: Nervös presentatör

| Fält | Värde |
|------|-------|
| **ID** | TC-UAT03 |
| **Prioritet** | HÖG |
| **Beskrivning** | Simulera stress-situation |
| **Steg** | 1. Säg till användaren att "detta är viktigt" |
| | 2. Låt dem presentera under press |
| | 3. Observera gestprecision under stress |
| **Förväntat** | Systemet fungerar även under stress |
| **Syfte** | Verifiera att gester är robusta nog |

---

## 9. Prestanda och mätmetodik

### 9.1 Latensmätning

#### Metod: Loggbaserad tidsstämpling

1. **Förberedelse:**
   - Aktivera debug-loggning i alla appar (Watch, Phone, Mac)
   - Säkerställ synkroniserade klockor mellan enheter

2. **Procedur:**
   - Utför gest
   - Samla loggar från alla enheter
   - Beräkna latens mellan tidsstämplar:
     - T1: Gestdetektering (Watch)
     - T2: Kommando mottaget (Mac)
     - T3: Slidebyte utfört
   - Konvertera till millisekunder

3. **Beräkning:**
   ```
   Latens (ms) = T3 - T1
   Delsträckor: Watch→Phone (T2-T1), Phone→Mac (T3-T2)
   ```

4. **Mätpunkter:**
   - Mät minst 20 gester
   - Beräkna medelvärde, min, max, standardavvikelse
   - Notera outliers (>750ms)

### 9.1.1 Event-queue med subjektiv upplevelse

För att korrelera objektiv latens med användarupplevelse:

1. **Event-queue:**
   - Varje steg i kedjan loggar till en gemensam event-queue
   - Format: `[timestamp_ms] [device] [event_type] [details]`
   - Exempel:
     ```
     1706234567890 WATCH GESTURE_DETECTED flick_next
     1706234567920 WATCH WC_MESSAGE_SENT cmd=NEXT
     1706234567985 PHONE WC_MESSAGE_RECEIVED cmd=NEXT
     1706234568010 PHONE MC_MESSAGE_SENT peer=Mac
     1706234568095 MAC MC_MESSAGE_RECEIVED cmd=NEXT
     1706234568120 MAC KEYPRESS_SENT keycode=124
     ```

2. **Subjektiv bedömning:**
   - Efter varje gest: testaren anger upplevd respons (1-5)
     - 1: Omedelbar
     - 2: Snabb
     - 3: Acceptabel
     - 4: Märkbar fördröjning
     - 5: Frustrerande långsam
   - Loggas tillsammans med event-queue

3. **Analys:**
   - Korrelera objektiv latens (ms) med subjektiv bedömning
   - Identifiera tröskelvärden: vid vilken latens upplever användaren fördröjning?
   - Hitta flaskhalsar: vilken delsträcka tar längst tid?

### 9.2 False Positive-räkning

#### Metod: Observationsprotokoll

1. **Under test:**
   - En observatör följer med och noterar varje trigger
   - Markera: "Avsiktlig" eller "Oavsiktlig"

2. **Data att samla:**
   - Total tid för test (minuter)
   - Antal avsiktliga gester
   - Antal triggers totalt
   - Antal oavsiktliga triggers

3. **Beräkning:**
   ```
   False Positive Rate = Oavsiktliga triggers / Total tid (min)
   Mål: 0 per 30 min
   ```

### 9.3 Batterimätning

#### Metod: Nivåbaserad mätning

1. **Procedur:**
   - Starta med 100% batteri (eller noterad nivå)
   - Kör test i exakt 60 minuter
   - Notera slutnivå

2. **Formel:**
   ```
   Förbrukning per timme = Startnivå - Slutnivå
   Mål: < 10%
   ```

3. **Variabler att kontrollera:**
   - Skärmljusstyrka
   - Andra appar i bakgrunden
   - Workout-session aktiv/inaktiv

---

## 10. Buggrapportering

### 10.1 Allvarlighetsnivåer

| Nivå | Beskrivning | Exempel |
|------|-------------|---------|
| **KRITISK** | Systemet oanvändbart eller osäkert | False positive under verklig presentation |
| **HÖG** | Betydande funktionsstörning | Latens >1s i >10% av fallen |
| **MEDEL** | Mindre störning, workaround finns | UI visar fel status tillfälligt |
| **LÅG** | Kosmetiskt eller "nice-to-have" | Ikon ser suddig ut |

### 10.2 Buggrapportmall

```markdown
## BUGG: [Kort beskrivning]

**ID:** BUG-XXX
**Allvarlighet:** KRITISK / HÖG / MEDEL / LÅG
**Upptäckt:** [Datum]
**Testfall:** [TC-XXX]
**Enhet:** [Watch Ultra 1 / iPhone X / Mac Y]

### Beskrivning
[Vad hände?]

### Reproduktionssteg
1. [Steg 1]
2. [Steg 2]
3. [Steg N]

### Förväntat resultat
[Vad borde ha hänt]

### Faktiskt resultat
[Vad hände istället]

### Frekvens
[ ] Alltid (100%)
[ ] Ofta (>50%)
[ ] Ibland (<50%)
[ ] Sällan (<10%)
[ ] Engångshändelse

### Bilagor
- [Loggutdrag]

### Ytterligare information
[OS-version, app-version, etc.]
```

---

## 11. Go/No-Go-kriterier

### 11.1 Go-kriterier (ALLA måste uppfyllas)

| Krav | Kriterium | Verifiering |
|------|-----------|-------------|
| False Positives | 0 under 30 min scenariotest | TC-FP01-FP08, TC-UAT02 |
| Latens | Medelvärde < 500ms | TC-G03, TC-C03 |
| Ultra 1 | Full funktionalitet | TC-U01-U03 |
| Anslutning | 100% stabilitet under 1h test | TC-N01 |
| Batteriförbrukning | < 10% per timme | TC-U03 |
| Installation | Lyckad utan utvecklarhjälp | TC-UAT01 |

### 11.2 No-Go-kriterier (ETT räcker för att blockera)

| Krav | Kriterium |
|------|-----------|
| Kritiska buggar | En eller fler öppna KRITISKA buggar |
| Ultra 1 | Någon funktion fungerar inte på Ultra 1 |
| False Positives | Mer än 1 under 30 min |
| Latens | Medelvärde > 750ms |
| Användartillit | UAT-person säger "Nej, jag litade inte på det" |

### 11.3 Villkorade Go

| Situation | Beslut |
|----------|--------|
| 1-2 HÖG-buggar utan workaround | Eskalera till Produktägare |
| Latens 500-750ms | Acceptabelt med dokumentation |
| 1 false positive på 30 min | Endast om reproduktion misslyckas |

---

## 12. Testsekvens och prioritering

### 12.1 Testordning

**Fas 1: Grundfunktionalitet** (Blockerar allt annat)
1. TC-C01: Watch-iPhone-parkoppling
2. TC-C02: iPhone-Mac-parkoppling
3. TC-C03: End-to-end-kedja
4. TC-M06: Accessibility-behörighet

**Fas 2: Gester** (Kärnan)
1. TC-G01-G02: Aktivering/avaktivering
2. TC-G03: Double pinch (nästa slide)
3. TC-G04-G05: Flick (nästa/föregående)
4. TC-G06: Blackout

**Fas 3: False Positive-verifiering** (Kritiskt)
1. TC-FP01: Naturlig gestikulering
2. TC-FP02: Handklapp
3. TC-FP03: Titta på klockan
4. TC-FP04-FP08: Övriga rörelser

**Fas 4: Applikationskompatibilitet**
1. TC-M01: Keynote helskärm
2. TC-M03: PowerPoint
3. TC-M05: Google Slides
4. TC-M02, TC-M04: Övriga

**Fas 5: Nätverksscenarier**
1. TC-N01-N02: Standard och BT-only
2. TC-N05-N07: Avbrott och återhämtning
3. TC-N03-N04: Störningar

**Fas 6: Ultra 1 och prestandaverifiering**
1. TC-U01-U03: Ultra-specifika
2. Latensmätning (20+ gester)
3. Batterimätning (1h)

**Fas 7: Användaracceptans**
1. TC-UAT01: Installation
2. TC-UAT02: 30-min presentation
3. TC-UAT03: Stress-test

---

## 13. Checklistor

### 13.1 Daglig testning (varje ny build)

```
[ ] Anslutning Watch-iPhone fungerar
[ ] Anslutning iPhone-Mac fungerar
[ ] Nästa slide-gest fungerar
[ ] Föregående slide-gest fungerar
[ ] Aktivering/avaktivering fungerar
[ ] 2 minuters fri gestikulering utan false positive
```

### 13.2 Scenariotest-checklista

```
## Presentation Scenariotest

Datum: ___________
Testare: ___________
Build: ___________

### Före start
[ ] Alla enheter laddade (>50%)
[ ] Keynote-presentation öppen
[ ] Debug-loggning aktiverad

### Under test (30 min)
[ ] Presentationsläge aktiverat
[ ] Presentatören gestikulerar naturligt
[ ] Endast avsiktliga gester för slidebyte
[ ] Observatör räknar triggers

### Mätvärden
- Avsiktliga gester: ___ st
- Lyckade slidebyten: ___ st
- False positives: ___ st
- False negatives: ___ st

### Kvalitativa observationer
- Haptisk feedback tydlig? [ ] Ja [ ] Nej
- Latens märkbar? [ ] Ja [ ] Nej
- Användare litade på systemet? [ ] Ja [ ] Nej

### Resultat
[ ] GODKÄNT - 0 false positives, <5% false negatives
[ ] UNDERKÄNT - Notera problem nedan

Problem:
___________________________________
___________________________________
```

### 13.3 Ultra 1-verifieringschecklista

```
## Ultra 1 Specifik Verifiering

Enhet: Apple Watch Ultra 1 (S8)
watchOS-version: ___________
App-version: ___________

### Grundfunktioner
[ ] App startar
[ ] Gestigenkänning fungerar
[ ] Haptisk feedback fungerar
[ ] Anslutning till iPhone stabil

### Action-knapp
[ ] Går att konfigurera för FlickSlides
[ ] Aktiverar Presentationsläge korrekt

### Sensorbaserade gester
[ ] Double clench fungerar
[ ] Double pinch fungerar
[ ] Flick framåt fungerar
[ ] Flick bakåt fungerar

### Battertest
Startnivå: ____%
Efter 1h: ____%
Förbrukning: ____% (mål: <10%)

### Signatur
Datum: ___________
Testare: ___________
Godkänt: [ ] Ja [ ] Nej
```

---

## Appendix A: Ordlista

| Term | Definition |
|------|------------|
| Double clench | Två snabba knytnävsslag för att aktivera/avaktivera |
| Double pinch | Två snabba nyp (tumme + pekfinger) för nästa slide |
| Flick | Snabb handrörelse som svingar framåt eller bakåt |
| False positive | Oavsiktlig trigger - en naturlig rörelse som felaktigt tolkas som gest |
| False negative | Missad gest - en avsiktlig gest som inte registreras |
| Debounce | Cooldown-period efter gest för att undvika dubbelregistrering |
| Presentationsläge | Aktivt läge där gester lyssnas på |
| End-to-end | Hela kedjan från gest till slidebytet |

---

## Appendix B: Historik

| Version | Datum | Ändringar |
|---------|-------|-----------|
| 1.0 | 2025-01-25 | Första utkast |

---

*Testplanen ägs av QA/Testare och godkänns av Projektledare innan test påbörjas.*
