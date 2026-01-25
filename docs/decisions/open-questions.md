# Öppna frågor från utforskningsfasen

*Sammanställt: 2025-01-25*

---

## Frågor som kräver Produktägarens beslut

### Q1: iOS-förgrund under presentation ✅ BESLUTAT
**Källa:** iOS-utvecklare
**Fråga:** Accepterar vi kravet på att iOS-appen måste vara i förgrund under presentation?

**Bakgrund:** WCSession `sendMessage` fungerar inte om iOS-appen är terminerad eller i djup bakgrund. För att garantera pålitlig kommunikation måste iPhone-appen vara i förgrund med `isIdleTimerDisabled = true`.

**Beslut:** JA - iOS-appen körs i förgrund under presentation
**Beslutare:** Produktägare (2025-01-25)

**Status:** ✅ Beslutat

---

### Q2: Digital Crown-riktning ✅ BESLUTAT
**Källa:** UX-designer
**Fråga:** Ska vridning medsols = NEXT eller PREV?

**Beslut:** Medsols = NEXT (intuitivt "framåt")
**Beslutare:** Produktägare (2025-01-25)

**Status:** ✅ Beslutat

---

### Q3: BLACKOUT-gest ✅ BESLUTAT
**Källa:** UX-designer
**Fråga:** Ska det finnas en dedikerad gest för BLACKOUT, eller endast skärmknapp?

**Beslut:** Endast skärmknapp (eliminerar false-positive-risk)
**Beslutare:** Produktägare (2025-01-25)

**Status:** ✅ Beslutat

---

### Q4: Timer-default ✅ BESLUTAT
**Källa:** UX-designer
**Fråga:** Vilken standardlängd på presentationstimer?

**Beslut:** 30 minuter
**Beslutare:** Produktägare (2025-01-25)

**Status:** ✅ Beslutat

---

## Frågor som Projektledaren beslutat

### D1: Verifieringskod vid parkoppling
**Källa:** iOS-utvecklare
**Fråga:** Behövs verifieringskod vid parkoppling mellan iPhone och Mac?

**Beslut:** NEJ i v1
**Motivering:** Lokal nätverksavgränsning (MultipeerConnectivity) räcker för säkerhet. Verifieringskod ökar komplexitet utan proportionerlig säkerhetsvinst i hemmiljö.

**Status:** ✅ Beslutat

---

### D2: Automatisk återanslutning
**Källa:** iOS-utvecklare
**Fråga:** Ska automatisk återanslutning implementeras vid avbrott?

**Beslut:** JA
**Motivering:** Kritiskt för användarupplevelse. Presentatörer ska inte behöva manuellt återansluta mitt i presentation.

**Status:** ✅ Beslutat

---

### D3: Distributionsmetod (macOS)
**Källa:** macOS-utvecklare
**Fråga:** App Store eller Developer ID?

**Beslut:** Developer ID (notariserad distribution)
**Motivering:** App Store sandbox blockerar CGEventPost() som krävs för tangentbordssimulering. Teknisk begränsning, inget val.

**Status:** ✅ Beslutat (teknisk begränsning)

---

### D4: Aktiveringsgest
**Källa:** UX-designer
**Fråga:** Vilken gest ska aktivera/avaktivera Presentationsläge?

**Beslut:** Double clench (dubbel knytnäve)
**Motivering:**
- Kraftfullare än pinch - kräver medveten handling
- Semantisk koppling: "knyta näven" = "ta kontroll"
- AssistiveTouch har redan tränat användare på gesten
- Låg risk för false positive

**Status:** ✅ Beslutat

---

### D5: Tröskelbaserad vs ML-gestdetektering
**Källa:** watchOS-utvecklare
**Fråga:** Ska vi börja med tröskellogik eller ML-modell?

**Beslut:** Tröskellogik först, förbered för ML
**Motivering:**
- Enklare att implementera och debugga
- Lägre latens och batterianvändning
- ML kan läggas till som förbättring om trösklar visar sig otillräckliga
- Best practice: börja enkelt, iterera

**Status:** ✅ Beslutat

---

## Risker identifierade

| Risk | Källa | Sannolikhet | Åtgärd |
|------|-------|-------------|--------|
| HKWorkoutSession-avslag | watchOS | Medel | Beskriv som "presentation controller with activity tracking" |
| iOS termineras i bakgrund | iOS | Medel | Kräv förgrund (se Q1) |
| False positives | UX/QA | Låg (med mitigation) | Double-gester, cooldown, explicit läge |
| Batteri tar slut | watchOS | Medel | Mät och optimera |
