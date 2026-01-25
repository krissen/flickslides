# FlickSlides Apps

## Snabbstart med XcodeGen

```bash
# Installera xcodegen (om inte installerat)
brew install xcodegen

# Generera Xcode-projekt
cd Apps
xcodegen generate

# Öppna projektet
open FlickSlides.xcodeproj
```

## Manuell setup i Xcode

Om du föredrar att skapa projektet manuellt:

### 1. Skapa nytt Xcode-projekt

1. Öppna Xcode 16+
2. File → New → Project
3. Välj "App" under Multiplatform
4. Projektnamn: `FlickSlides`
5. Bundle ID: `com.kristianniemi.FlickSlides`
6. Spara i `Apps/`-mappen

### 2. Lägg till targets

#### watchOS App
1. File → New → Target → watchOS → App
2. Namn: `FlickSlidesWatch`
3. Bundle ID: `com.kristianniemi.FlickSlides.watchkitapp`
4. Aktivera HealthKit capability
5. Dra in filer från `Watch/Sources/`
6. Använd `Watch/Info.plist` och `Watch/FlickSlidesWatch.entitlements`

#### macOS App
1. File → New → Target → macOS → App
2. Namn: `FlickSlidesMac`
3. Bundle ID: `com.kristianniemi.FlickSlidesMac`
4. Dra in filer från `Mac/Sources/`
5. Använd `Mac/Info.plist` och `Mac/FlickSlidesMac.entitlements`
6. **VIKTIGT:** Stäng av App Sandbox i Signing & Capabilities

### 3. Lägg till FlickSlidesKit

1. File → Add Package Dependencies
2. Välj lokal package: `../` (FlickSlidesKit)
3. Lägg till som dependency till alla targets

### 4. Konfigurera signing

- iOS: Automatic signing med ditt Developer Team
- watchOS: Automatic signing
- macOS: **Developer ID Application** (krävs för notarisering)

## Projektstruktur

```
Apps/
├── project.yml          # XcodeGen-konfiguration
├── Watch/
│   ├── Sources/         # Swift-källkod
│   ├── Info.plist
│   └── FlickSlidesWatch.entitlements
├── Phone/
│   ├── Sources/
│   ├── Info.plist
│   └── FlickSlidesPhone.entitlements
└── Mac/
    ├── Sources/
    ├── Info.plist
    └── FlickSlidesMac.entitlements
```

## Capabilities per target

### FlickSlidesWatch (watchOS)
- ✅ HealthKit (Background Delivery)
- ✅ Background Modes → Workout Processing

### FlickSlidesPhone (iOS)
- ✅ Multicast Networking

### FlickSlidesMac (macOS)
- ❌ App Sandbox (måste vara AV för CGEvent)
- ✅ Hardened Runtime
- ✅ Network → Incoming/Outgoing Connections

## Deployment targets

| Plattform | Minimum |
|-----------|---------|
| iOS | 18.0 |
| watchOS | 11.0 |
| macOS | 15.0 (Sequoia) |

## Testning

1. Bygg och kör macOS-appen först
2. Starta iOS-appen och välj din Mac
3. Starta watchOS-appen via Xcode på fysisk klocka
4. Testa gester på Apple Watch Ultra 1
