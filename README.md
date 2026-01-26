# FlickSlides

**Gesture-controlled presentations using Apple Watch — flick your wrist to advance slides.**

Control Keynote, PowerPoint, or any presentation app with natural wrist flick gestures on your Apple Watch. No more clunky clickers or being tethered to your laptop.

```
Watch (gesture) → iPhone (bridge) → Mac (keystroke)
     ↓                  ↓                  ↓
 Wrist flick    WatchConnectivity    Arrow keys
```

## Features

- **Wrist flick forward** — Advance to next slide
- **Wrist flick backward** — Go to previous slide
- **Manual buttons** — Fallback controls on Watch and iPhone
- **Haptic feedback** — Feel every command confirmed
- **Personalized calibration** — Train the app to recognize your gestures
- **Zero false positives** — Explicit activation prevents accidental triggers

<!-- TODO: Add animated GIF demo here -->

## Requirements

| Device | Minimum |
|--------|---------|
| Apple Watch | Series 4+ or Ultra 1/2 |
| iPhone | iOS 18.0+ |
| Mac | macOS 15.0+ |

Works with any presentation software that responds to arrow keys.

## Quick Start

1. **Mac:** Launch FlickSlides — grant Accessibility permission when prompted
2. **iPhone:** Open FlickSlides — select your Mac from the list
3. **Watch:** Open FlickSlides — tap **Start** to activate presentation mode

That's it. Flick your wrist forward to advance slides.

## How It Works

FlickSlides uses motion sensors (accelerometer and gyroscope) combined with a workout session to detect wrist gestures while keeping the app responsive in the background. Commands travel from your wrist to your Mac in under 500ms.

**Gestures in presentation mode:**

| Gesture | Action |
|---------|--------|
| Flick forward | Next slide |
| Flick backward | Previous slide |
| Tap Stop | Exit presentation mode |

**Calibration** (optional): Train FlickSlides to recognize your personal gesture style for improved accuracy.

## Documentation

- [Getting Started](docs/user-guide/getting-started.md) — Installation and first connection
- [Gestures Guide](docs/user-guide/gestures.md) — How to use gestures
- [Calibration](docs/user-guide/calibration.md) — Personalize gesture recognition
- [Troubleshooting](docs/user-guide/troubleshooting.md) — Common problems and solutions
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

[GPL v3](LICENSE)

For commercial licensing options, contact the author.
