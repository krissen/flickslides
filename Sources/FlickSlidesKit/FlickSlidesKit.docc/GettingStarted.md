# Getting Started with FlickSlidesKit

Learn how to use FlickSlidesKit in your FlickSlides app components.

## Overview

FlickSlidesKit is a shared Swift Package used by all three FlickSlides apps. It provides common types for communication and gesture recognition.

## Using Presentation Commands

Send commands from Watch to Mac using ``PresentationCommand``:

```swift
import FlickSlidesKit

// Create a command
let command = PresentationCommand.next

// Get the keycode for macOS
let keyCode = command.keyCode  // 124 (right arrow)
```

## Working with Gesture Templates

Store calibrated gestures using ``GestureTemplate``:

```swift
import FlickSlidesKit

// Create motion samples from sensor data
let sample = MotionSample(
    timestamp: Date().timeIntervalSince1970,
    accX: 1.2, accY: 0.3, accZ: -0.1,
    rotX: 15.0, rotY: 2.0, rotZ: -5.0
)

// Create a template from samples
let template = GestureTemplate(
    label: .flickForward,
    samples: [sample]
)
```

## Configuration Constants

Access shared configuration values through ``FlickSlidesConstants``:

```swift
import FlickSlidesKit

// Gesture detection thresholds
let accelThreshold = FlickSlidesConstants.accelerationThreshold  // 1.5g
let debounce = FlickSlidesConstants.gestureDebounceInterval      // 1.0s

// Service identifiers
let serviceType = FlickSlidesConstants.multipeerServiceType      // "flickslides-ctl"
```
