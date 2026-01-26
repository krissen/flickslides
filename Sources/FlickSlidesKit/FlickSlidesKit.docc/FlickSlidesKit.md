# ``FlickSlidesKit``

Shared models and protocols for the FlickSlides presentation control system.

## Overview

FlickSlidesKit provides the common data types, protocols, and constants used across all FlickSlides apps (watchOS, iOS, and macOS).

The library includes:
- **Presentation commands** — The command types sent from Watch to Mac
- **Gesture templates** — Data structures for calibrated gesture recognition
- **Constants** — Shared configuration values for gesture detection
- **Communication protocols** — Calibration message formats

## Topics

### Essentials

- ``PresentationCommand``
- ``CommandAck``
- ``FlickSlidesConstants``

### Gesture Recognition

- ``GestureLabel``
- ``GestureTemplate``
- ``MotionSample``
- ``MotionSampleBatch``

### Calibration

- ``CalibrationMessage``
- ``CalibrationStats``
- ``OutlierDetector``

### Communication

- ``AppMessage``
- ``AppInfo``
- ``ConnectionState``
