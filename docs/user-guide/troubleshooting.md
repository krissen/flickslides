# Felsökning

Vanliga problem och lösningar för FlickSlides.

## Anslutningsproblem

### iPhone hittar inte Mac

**Kontrollera:**
- Båda enheterna är på samma Wi-Fi-nätverk
- FlickSlides körs på Mac (ikon i menyraden)
- Brandväggen blockerar inte FlickSlides

**Lösning:**
1. Stäng och starta om FlickSlides på båda enheterna
2. Om Mac har brandvägg aktiverad, lägg till FlickSlides som undantag

### Watch visar "iPhone ej nåbar"

**Kontrollera:**
- iPhone är upplåst och FlickSlides är öppet
- Bluetooth är aktiverat på båda enheterna
- Enheterna är parkopplade i Watch-appen

**Lösning:**
1. Stäng FlickSlides på Watch och öppna igen
2. Starta om Bluetooth på iPhone
3. I värsta fall: Avparkoppla och parkoppla Watch på nytt

### Mac visar "Behörighet saknas"

FlickSlides behöver Accessibility-behörighet:
1. Öppna **Systeminställningar > Integritet och säkerhet > Tillgänglighet**
2. Ta bort FlickSlides från listan (om den finns)
3. Lägg till FlickSlides igen
4. Starta om FlickSlides

## Gestproblem

### Gester registreras inte

**Kontrollera:**
- Presentationsläge är aktivt (grön "Aktivt" på Watch)
- iPhone är ansluten till Mac

**Prova:**
1. Justera accelerationströskeln nedåt (mer känslig)
2. Gör tydligare, snabbare gester
3. Kalibrera om du inte gjort det

### För många false positives

Oavsiktliga gester registreras:

**Lösning:**
1. Öka accelerationströskeln (mindre känslig)
2. Öka debounce-intervallet
3. Kalibrera med negativa exempel

### Gester fungerar bara ibland

**Kontrollera:**
- Klockan sitter rätt (sidan som registrerats i inställningar)
- Batteriet på Watch är inte för lågt

**Prova:**
1. Rensa kalibrering och börja om
2. Gör tester i lugn miljö utan rörelse

## Presentationsproblem

### Slidebyte fungerar inte i min app

FlickSlides skickar standard tangentbordskommandon (←/→). Om din app inte svarar:

**Kontrollera:**
- Appen är i presentationsläge
- Appen är det aktiva fönstret
- Appen stöder piltangenterna för navigation

**Appar som stöds:**
- Keynote
- PowerPoint
- Google Slides (i webbläsare)
- Preview (PDF)
- Skim
- Adobe Acrobat

### Slidebyte går till fel app

Om du har flera presentationsappar öppna:
1. På iPhone, välj rätt app under "Målapp"
2. Eller stäng andra presentationsappar

### Svart skärm (B) fungerar inte

Blackout-funktionen (B-tangenten) stöds inte av alla appar:
- **Keynote:** Fungerar
- **PowerPoint:** Fungerar
- **PDF-läsare:** Fungerar oftast inte

## Batteriproblem

### Watch-batteriet dräneras snabbt

FlickSlides använder sensorer kontinuerligt under presentation:

**Tips:**
- Avsluta presentationsläge när du inte presenterar
- Under Inställningar: Slå av "Spara som träning i Hälsa"

### iPhone-batteriet dräneras

iPhone fungerar som brygga och håller anslutningar aktiva:

**Tips:**
- Anslut iPhone till laddare under längre presentationer
- Skärmen kan vara låst, men appen måste vara öppen

## Återställning

### Fabriksåterställning av inställningar

Om inget annat fungerar:

**På iPhone:**
1. Gå till Inställningar
2. Tryck "Återställ till standardvärden"
3. Rensa kalibrering

**På Mac:**
1. Avsluta FlickSlides
2. Ta bort `~/Library/Preferences/com.kristianniemi.FlickSlides.plist`
3. Starta FlickSlides igen

## Kontakta support

Om du fortfarande har problem:
- Skapa ett issue på [GitHub](https://github.com/...)
- Inkludera: iOS/macOS/watchOS-version, enhetmodell, steg för att reproducera
