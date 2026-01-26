# FlickSlides – Referensbibliotek

Detta dokument samlar resurser och best practices för varje roll i projektet.

---

## HR (Personalansvarig)

### Primära resurser
- [Prompt Engineering Guide](https://www.promptingguide.ai/) - Best practices för effektiva system-prompts
- [Effective Agent Design](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching) - Anthropics riktlinjer för agent-arkitektur

### Best practices
- **Tydlig rolluppdelning** - En roll ska ha ett primärt ansvarsområde
- **Mätbara leverabler** - Varje roll ska kunna verifiera sin output
- **Realistiska CV-krav** - Krav som faktiskt behövs, inte önskelista
- **Iterativ förbättring** - Rollprofiler utvecklas baserat på faktisk användning

---

## UX/UI-designer

### Primära resurser
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) - Huvudsaklig designreferens
- [watchOS Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos) - Specifikt för Apple Watch
- [iOS Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios) - Specifikt för iPhone
- [macOS Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) - Specifikt för Mac

### Gestdesign
- [AssistiveTouch](https://support.apple.com/guide/watch/assistivetouch-apd57583eba2/watchos) - Apples tillgänglighetsgester
- [Double Tap](https://support.apple.com/guide/watch/use-double-tap-apd54c0b0e69/watchos) - S9-chipets gestigenkänning (referens för framtid)

### Tillgänglighet
- [WCAG 2.2 Guidelines](https://www.w3.org/WAI/WCAG22/quickref/) - Web Content Accessibility Guidelines
- [Apple Accessibility](https://developer.apple.com/accessibility/) - Apples tillgänglighetsresurser
- [VoiceOver Programming Guide](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/iPhoneAccessibility/Introduction/Introduction.html) - VoiceOver-implementation

### Designmetodik
- [Design Thinking (IDEO)](https://designthinking.ideo.com/) - Ramverk för användarcentrerad design
- [Double Diamond (Design Council)](https://www.designcouncil.org.uk/our-resources/the-double-diamond/) - Designprocess
- [Nielsen's 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) - Heuristisk utvärdering

### Haptik
- [Apple Haptics Guidelines](https://developer.apple.com/design/human-interface-guidelines/playing-haptics) - Riktlinjer för haptisk feedback
- [WKHapticType](https://developer.apple.com/documentation/watchkit/wkhaptictype) - Tillgängliga haptiska mönster på watchOS

### Best practices
- **Gestsäkerhet först** - Designa för noll false positives
- **Minimalistisk Watch-UI** - Presentatören ska inte behöva titta på skärmen
- **Tydlig feedback** - Varje gest ska bekräftas haptiskt
- **Plattformsidiom** - Respektera varje plattforms konventioner
- **Tillgänglighet från start** - VoiceOver-stöd är inte en eftertanke

---

## watchOS-utvecklare

### Primära resurser
- [watchOS App Programming Guide](https://developer.apple.com/documentation/watchos-apps) - Officiell dokumentation
- [CoreMotion Framework](https://developer.apple.com/documentation/coremotion) - Accelerometer och gyroskop
- [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity) - Kommunikation med iPhone

### Gestigenkänning
- [CMMotionManager](https://developer.apple.com/documentation/coremotion/cmmotionmanager) - Sensoråtkomst
- [CMDeviceMotion](https://developer.apple.com/documentation/coremotion/cmdevicemotion) - Kombinerad rörelsedata
- [Dynamic Time Warping](https://en.wikipedia.org/wiki/Dynamic_time_warping) - Algoritm för gestmatchning

### Bakgrundsaktivitet
- [HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession) - Bakgrunds-sensoråtkomst
- [Extended Runtime Sessions](https://developer.apple.com/documentation/watchkit/wkextendedruntime) - Utökad körning

### Action-knapp (Ultra)
- [App Intents](https://developer.apple.com/documentation/appintents) - Siri Shortcuts-integration
- [Action Button](https://support.apple.com/guide/watch-ultra/action-button-apd0c67de2ec/watchos) - Ultra-specifik dokumentation

### Best practices
- **Testa på fysisk enhet** - Simulator ger inga sensordata
- **Debounce är kritiskt** - Undvik dubbelregistreringar
- **Batterioptimering** - Använd lämplig samplingsfrekvens (50-100 Hz)
- **State machine** - Strukturera gestigenkänning som tillstånd
- **Tröskelbaserad fallback** - DTW efter kalibrering, trösklar som backup

---

## iOS-utvecklare

### Primära resurser
- [iOS App Dev Tutorials](https://developer.apple.com/tutorials/app-dev-training) - Officiella tutorials
- [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity) - Watch-kommunikation
- [MultipeerConnectivity](https://developer.apple.com/documentation/multipeerconnectivity) - Peer-to-peer-nätverk

### Bakgrundslägen
- [Background Execution](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background) - Bakgrundsaktivitet
- [Maintaining Connections](https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background) - Persistenta anslutningar

### App Groups
- [App Groups](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups) - Delad data

### Best practices
- **Bryggan är osynlig** - Användaren ska fokusera på Watch och presentation
- **Automatisk återanslutning** - Hantera nätverksavbrott transparent
- **Logga latens** - Tidsstämpla varje steg för debugging
- **Bakgrundsstöd** - Appen måste fungera med skärmen låst

---

## macOS-utvecklare

### Primära resurser
- [macOS App Dev](https://developer.apple.com/macos/) - Officiell dokumentation
- [AppKit Framework](https://developer.apple.com/documentation/appkit) - UI-ramverk
- [Menu Bar Apps](https://developer.apple.com/documentation/appkit/nsstatusbar) - Menyradsappar

### Tangentbordssimulering
- [Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz_event_services) - CGEvent-API
- [Virtual Key Codes](https://developer.apple.com/documentation/coregraphics/cgkeycode) - Tangentbordskoder

### Accessibility
- [Accessibility API](https://developer.apple.com/documentation/applicationservices/accessibility) - AXIsProcessTrusted
- [Requesting Access](https://developer.apple.com/documentation/applicationservices/kaxtrustetcheckoptionprompt) - Behörighetshantering

### Distribution
- [Notarizing Apps](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution) - App-notarisering
- [ServiceManagement](https://developer.apple.com/documentation/servicemanagement) - Launch at login

### Best practices
- **Accessibility-behörighet krävs** - Visa tydlig guide första gången
- **LSUIElement = YES** - Ingen Dock-ikon för menyradsapp
- **Testa helskärmsläge** - Keynote/PowerPoint kör ofta fullscreen
- **Debounce** - Ignorera snabba dubbelkommandon

---

## QA / Testare

### Primära resurser
- [XCTest](https://developer.apple.com/documentation/xctest) - Apples testramverk
- [UI Testing](https://developer.apple.com/documentation/xctest/user_interface_tests) - UI-tester
- [Xcode Instruments](https://developer.apple.com/documentation/xcode/diagnosing-performance-issues-early) - Prestandaanalys

### Tillgänglighetstestning
- [Accessibility Inspector](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXTestingApps.html) - Inspektera UI
- [VoiceOver Testing](https://developer.apple.com/library/archive/technotes/TestingAccessibilityOfiOSApps/TestAccessibilityonYourDevicewithVoiceOver/TestAccessibilityonYourDevicewithVoiceOver.html) - VoiceOver-testning

### Logganalys
- [Console.app](https://support.apple.com/guide/console/welcome/mac) - Systemloggar
- [OSLog](https://developer.apple.com/documentation/os/oslog) - Strukturerad loggning

### Best practices
- **False positives är KRITISKA** - Ett oavsiktligt slidebyte förstör förtroendet
- **Testa Ultra 1 specifikt** - Produktägarens primära enhet
- **Realistiska scenarier** - Stå upp, prata, gestikulera
- **Kvantifiera allt** - Latens i ms, battery i procent
- **Dokumentera reproduktionssteg** - Buggar utan steg är värdelösa

---

## Technical Writer

### Primära resurser
- [DocC](https://developer.apple.com/documentation/docc) - Apples dokumentationsformat
- [GitHub Flavored Markdown](https://github.github.com/gfm/) - GitHub-specifik Markdown
- [Write the Docs](https://www.writethedocs.org/guide/) - Dokumentations-community

### README-struktur
- [Make a README](https://www.makeareadme.com/) - README best practices
- [Awesome README](https://github.com/matiassingers/awesome-readme) - Exempel på bra READMEs

### API-dokumentation
- [DocC Documentation](https://developer.apple.com/documentation/docc/documenting-a-swift-framework-or-package) - Dokumentera Swift-kod
- [Symbol Documentation](https://developer.apple.com/documentation/xcode/writing-symbol-documentation-in-your-source-files) - Källkodsdokumentation

### Best practices
- **Användarfokus** - Skriv för presentatören, inte utvecklaren
- **Faktabaserat** - Dokumentera bara implementerad funktionalitet
- **Tydlighet** - Förklara tekniska termer
- **Synkronisering** - Uppdatera vid varje release
- **GitHub är skyltfönstret** - README.md är första intrycket

---

## Gemensamma resurser

### Apple Developer
- [Apple Developer Documentation](https://developer.apple.com/documentation/) - Huvudsaklig dokumentation
- [WWDC Videos](https://developer.apple.com/videos/) - Sessioner och tutorials
- [Sample Code](https://developer.apple.com/sample-code/) - Exempelkod

### Swift
- [Swift Language Guide](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/) - Språkreferens
- [Swift Evolution](https://github.com/swiftlang/swift-evolution) - Kommande funktioner
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) - Async/await

### SwiftUI
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/) - Ramverksdokumentation
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui) - Officiella tutorials

---

## Format för nya referenser

När du lägger till nya referenser, använd detta format:

```markdown
### [Kort titel]

- **URL:** https://...
- **Hämtad:** YYYY-MM-DD
- **Gäller:** watchOS X.X / iOS X.X / macOS X.X
- **Sammanfattning:** Kort beskrivning av innehållet och relevans för projektet
- **Använd av:** [roll/agent]
```
