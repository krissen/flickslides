# Gester och kontroller

FlickSlides känner igen gester från din Apple Watch för att styra presentationer.

## Grundläggande gester

### Nästa slide
**Flicka handleden framåt** (bort från dig)

Snabb, bestämd rörelse som om du "slänger" något framåt. Fungerar bäst med handled i neutral position.

### Föregående slide
**Flicka handleden bakåt** (mot dig)

Samma rörelse som nästa, men i motsatt riktning.

### Tips för bästa resultat

- **Snabb rörelse:** En distinkt "flick" fungerar bättre än en långsam rörelse
- **Neutral start:** Börja med armen avslappnad
- **Undvik rörelse däremellan:** Vänta tills gesten bekräftats (haptisk feedback) innan du gör nästa

## Haptisk feedback

Watch vibrerar för att bekräfta:
- **Kort vibration:** Gest registrerad, kommando skickat
- **Dubbelvibration:** Presentationsläge startat/stoppat

## Fallback-knappar

Om gesterna inte fungerar finns alltid knappar:

### På Apple Watch
Under huvudknappen finns **←** och **→** knappar för manuell kontroll.

### På iPhone
Under "Manuell kontroll" finns:
- **←** Föregående slide
- **■** Svart skärm (blackout)
- **→** Nästa slide

## Målapp

Om du har flera presentationsappar igång kan du välja vilken som ska styras:

1. På iPhone, under "Målapp"
2. Välj appen (Keynote, PowerPoint, etc.)
3. Kommandon skickas endast till vald app

Om ingen app är vald går kommandona till den aktiva appen.

## Tangentbordsgenvägar som används

FlickSlides simulerar dessa tangenter:

| Gest/Kommando | Tangent | Funktion |
|---------------|---------|----------|
| Nästa | → (högerpil) | Nästa slide |
| Föregående | ← (vänsterpil) | Föregående slide |
| Blackout | B | Svart skärm |
| Escape | Esc | Avsluta presentation |

Dessa fungerar i de flesta presentationsprogram (Keynote, PowerPoint, Google Slides i webbläsare, PDF-läsare).

## Latens

FlickSlides är optimerat för snabb respons:
- **Mål:** Under 500ms från gest till slidebyte
- **Typiskt:** 150-300ms

Latensen visas i kommandologgen på iPhone.
