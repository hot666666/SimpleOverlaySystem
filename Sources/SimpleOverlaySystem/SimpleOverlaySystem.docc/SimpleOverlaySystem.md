# `SimpleOverlaySystem`

Lightweight overlay presentation for SwiftUI with centered and anchored surfaces, driven by a shared environment manager.

## Overview

SimpleOverlaySystem provides a single overlay stack for your view hierarchy. Mount the host once near the root, then present overlays from anywhere using the environment manager.

```swift
import SimpleOverlaySystem

OverlayContainer {
  ContentView()
}

struct ContentView: View {
  @Environment(\.overlayManager) private var overlay

  var body: some View {
    Button("Show Centered Overlay") {
      guard let overlay else { return }
      overlay.presentCentered {
        Text("Hello Overlay")
          .padding()
          .background(.background, in: .rect(cornerRadius: 12))
      }
    }
  }
}
```

## Topics

### Essentials

- `OverlayContainer`
- `OverlayManager`

### Presenting Overlays

- `OverlayManager/presentCentered(dismissPolicy:barrier:backdropOpacity:content:)`
- `OverlayManager/presentAnchored(anchorFrame:placement:dismissPolicy:barrier:backdropOpacity:content:)`
- `OverlayPlacement`
- `AnchoredOverlayButton`

### Dismissal and Interaction

- `OverlayManager/dismissTop()`
- `OverlayManager/dismissAll()`
- `OverlayDismissPolicy`
- `OverlayInteractionBarrier`
