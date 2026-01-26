# Designspecifikation: Menyradsikon (macOS)

## Översikt

Menyradsikonen för FlickSlides ska kommunicera appens funktion (geststyrning av presentationer) och visa aktuell anslutningsstatus. Ikonen baseras på app-ikonens handmotiv men förenklad för att fungera i 18x18 pixlar.

## Storlekar

| Fil | Storlek | Användning |
|-----|---------|------------|
| `menubar-icon.png` | 18x18 px | Standard (1x) |
| `menubar-icon@2x.png` | 36x36 px | Retina (2x) |

**Tekniska krav:**
- PNG med transparens (alpha-kanal)
- Template mode: Endast svart (#000000) med varierande opacitet
- Inga halvtoner utanför standardgråskala

## Design: Förenklad hand

### Koncept

Istället för hela handen med bok/sida från app-ikonen, använd en **stiliserad handsilhuett** som gör en "flick"-gest. Handen ska vara igenkännbar även i 18px.

### Geometri (18x18 canvas)

```
    ┌──────────────────┐
    │                  │
    │      ╭─╮         │
    │    ╭─┤ │         │  ← Pekfinger (pekar uppåt-höger)
    │  ╭─┤ ╰─╯         │  ← Långfinger
    │ ╭┤ ╰───╮         │  ← Ringfinger
    │ │╰─────┤         │  ← Lillfinger
    │ ╰──┬───╯         │
    │    │   ╰╮        │  ← Tumme (vinklad inåt)
    │    ╰────╯        │
    │                  │
    └──────────────────┘
```

### Designprinciper

1. **Pekfingret dominerar** – Pekar i riktningen för "nästa slide" (uppåt-höger)
2. **Handflatan antyds** – Inte detaljerad, bara bas för fingrarna
3. **Tummen synlig** – Ger handen naturlig form
4. **2px linjebredd minimum** – Garanterar synlighet vid 1x

### Proportioner

| Element | Storlek (18x18) | Storlek (36x36) |
|---------|-----------------|-----------------|
| Pekfinger höjd | 8px | 16px |
| Handflata bredd | 10px | 20px |
| Total höjd | 14px | 28px |
| Padding (alla sidor) | 2px | 4px |

## Statusindikering

Menyradsikonen ska visa tre statuslägen. macOS menyradsikoner använder **template mode** som standard, vilket betyder att systemet färgar ikonen automatiskt baserat på menyradens utseende (mörk/ljus).

### Strategi: Statusindikator som accent

Eftersom handen är i template mode (monokrom), lägg till en **liten färgad indikator** för status:

```
┌──────────────────┐
│              ●   │  ← Liten cirkel (3px diameter)
│      ╭─╮         │
│    ╭─┤ │         │
│  ╭─┤ ╰─╯         │
│ ╭┤ ╰───╮         │
│ │╰─────┤         │
│ ╰──┬───╯         │
│    │   ╰╮        │
│    ╰────╯        │
└──────────────────┘
```

### Statuscirkeln

| Status | Färg | Hex | Betydelse |
|--------|------|-----|-----------|
| Ansluten | Grön | `#34C759` | Watch ansluten, redo |
| Frånkopplad | Grå | `#8E8E93` | Ingen Watch ansluten |
| Fel | Röd | `#FF3B30` | Anslutningsfel |

**Positionering:**
- Övre högra hörnet av canvas
- 3x3 px vid 1x, 6x6 px vid 2x
- Fast färg (inte template mode)

### Implementation

Ikonen behöver vara **komposit** i koden:
1. Handsilhuetten som template image (monokrom)
2. Statuscirkeln som separat färgad layer

```swift
// Pseudokod för SwiftUI
struct MenuBarIcon: View {
    let status: ConnectionStatus

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image("menubar-hand")
                .renderingMode(.template)

            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6) // @2x
        }
    }
}
```

## Filstruktur

Leverera följande filer:

```
Assets.xcassets/
└── MenuBarIcon.imageset/
    ├── Contents.json
    ├── menubar-hand.png        (18x18, endast hand)
    └── menubar-hand@2x.png     (36x36, endast hand)
```

**Contents.json:**
```json
{
  "images" : [
    {
      "filename" : "menubar-hand.png",
      "idiom" : "mac",
      "scale" : "1x"
    },
    {
      "filename" : "menubar-hand@2x.png",
      "idiom" : "mac",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
```

## Designtips för export

1. **Arbeta i 36x36** (2x) och skala ner till 18x18
2. **Testa mot båda bakgrunder** – ljus och mörk menyrad
3. **Testa med alla statusfärger** samtidigt
4. **Undvik detaljer under 2px** vid 1x
5. **Centrera vertikalt** i canvas för jämn vikt

## Alternativ design (om hand är för komplex)

Om handen inte läses tydligt vid 18px, överväg:

### Alt A: Stiliserat "flick"-streck
```
    ╲
     ╲
      →
```
Ett böjt streck som antyder rörelse/gest.

### Alt B: Abstrakt "slide"-ikon
```
  ┌───┐
  │ → │
  └───┘
```
En rektangel (slide) med riktningspil.

**Rekommendation:** Börja med handen. Om den inte fungerar vid liten storlek, eskalera till produktägaren med alternativen.

## Sammanfattning

| Aspekt | Beslut |
|--------|--------|
| Motiv | Förenklad hand (flick-gest) |
| Storlekar | 18x18, 36x36 (1x, 2x) |
| Rendering | Template mode (monokrom) |
| Status | Färgad cirkel (3/6px) i övre högra hörnet |
| Färger | Grön/grå/röd enligt Apple HIG |

---

**STATUS:** Klar
**RESULTAT:** Komplett designspecifikation för menyradsikon
**FRÅGOR:** Inga
**NÄSTA:** Grafisk designer skapar PNG-filer enligt spec
**RISKER:** Handen kan vara för detaljerad vid 18px - utvärdera vid implementation
