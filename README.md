# FlickSlides

**Gesture-controlled presentations using Apple Watch — flick your wrist to advance slides.**

Control Keynote, PowerPoint, or any presentation app with subtle hand gestures on your Apple Watch. No more clunky clickers or being tethered to your laptop.

```
Watch (gesture) → iPhone (bridge) → Mac (keystroke)
     ↓                  ↓                  ↓
 Double-pinch    WatchConnectivity    Arrow keys
```

## Features

- **Double-pinch** — Advance to next slide
- **Digital Crown** — Navigate slides with precision
- **Action Button** (Ultra) — Toggle presentation mode
- **Haptic feedback** — Feel every command confirmed
- **Zero false positives** — Explicit activation prevents accidental triggers

## Requirements

| Device | Minimum |
|--------|---------|
| Apple Watch | Series 4+ or Ultra 1/2 |
| iPhone | iOS 18.0+ |
| Mac | macOS 15.0+ |

Works with any presentation software that responds to arrow keys.

## Quick Start

1. **Mac:** Launch FlickSlides — grant Accessibility permission when prompted
2. **iPhone:** Open FlickSlides — it finds your Mac automatically
3. **Watch:** Open FlickSlides — double-clench to activate presentation mode

That's it. Double-pinch to advance slides.

## How It Works

FlickSlides uses AssistiveTouch gestures (built into watchOS) combined with a workout session to keep the app responsive. Commands travel from your wrist to your Mac in under 500ms.

**Gestures in presentation mode:**

| Gesture | Action |
|---------|--------|
| Double-pinch | Next slide |
| Digital Crown turn | Next/Previous |
| Double-clench | Exit presentation mode |

## Documentation

- [Gesture Design](docs/research/gesture-design.md) — How gestures were chosen
- [Architecture Decisions](docs/decisions/) — Technical decisions and rationale

## Building

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd Apps
xcodegen generate
open FlickSlides.xcodeproj
```

Build targets: **FlickSlidesMac**, **FlickSlidesPhone**, **FlickSlidesWatch**

## Status

Under active development. Primary test device: Apple Watch Ultra 1.

## License

[MIT](LICENSE)
