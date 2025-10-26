# SimpleOverlaySystem

A lightweight overlay presenter for SwiftUI. It keeps a consistent overlay stack across your view tree using an Observation-powered `EnvironmentValues` entry and supports both centered overlays and anchored overlays attached to controls.

- Platforms: iOS 17+, macOS 14+, Mac Catalyst 17+, tvOS 17+

## Features

- Centered overlays and anchored overlays (shown above/below a source view)
- Flexible dismissal policies: tap outside, action only, or none
- Background interaction barrier: block all or passthrough, with optional scrim
- Simple environment integration via `@Environment(\.overlayManager)`
- One-time host mounting with `OverlayContainer`

## Installation (Swift Package Manager)

1. Open Xcode, select File > Add Packages.
2. Add the repository URL:
   ```plain
   https://github.com/hot666666/SimpleOverlaySystem.git
   ```

## Quick Start

Wrap your root with `OverlayContainer`. Inside your views, use `@Environment(\.overlayManager)` to present and dismiss overlays. Both centered and anchored overlays are driven by the same manager.

```swift
import SwiftUI
import SimpleOverlaySystem

@main
struct OverlayExampleApp: App {
    var body: some Scene {
        WindowGroup {
            OverlayContainer {
                ContentView()
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.overlayManager) private var overlay

    var body: some View {
        VStack {
            Button("Show Centered Overlay") {
                overlay.presentCentered {
                    CenterOverlayView()
                }
            }
        }
    }
}

struct CenterOverlayView: View {
    @Environment(\.overlayManager) private var overlay

    var body: some View {
        VStack(spacing: 24) {
            Text("Show Anchored Overlay")
                .font(.title2.weight(.semibold))

            HStack {
                // Above the button, horizontally aligned to the leading edge
                AnchoredOverlayButton(
                    placement: .top(alignment: .leading),
                    dismissPolicy: .actionOnly,
                    barrier: .blockAll
                ) {
                    Text("Above")
                } content: {
                    AnchoredOverlayView()
                }

                // Below the button, horizontally aligned to the trailing edge
                AnchoredOverlayButton(
                    placement: .bottom(alignment: .trailing),
                    dismissPolicy: .actionOnly,
                    barrier: .blockAll
                ) {
                    Text("Below")
                } content: {
                    AnchoredOverlayView()
                }
            }

            Button("Dismiss") {
                overlay.dismissAll()
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(width: 300, height: 200)
    }
}
```

## Usage

### Centered overlays

<img src="resource/centered.png" alt="Centered Overlay Example" width="300" height="300">

- Present a modal-like overlay in the center with `presentCentered`.
- Dismiss with `overlay.dismissTop()` or `overlay.dismissAll()`.

```swift
overlay.presentCentered(
    dismissPolicy: .tapOutside,   // .tapOutside, .actionOnly, .none
    barrier: .blockAll            // .blockAll or .passthrough
) {
    MyCenteredOverlay()
}
```

### Anchored overlays (button-based)

<img src="resource/anchored.png" alt="Anchored Overlay Example" width="300" height="300">

- `AnchoredOverlayButton` anchors the overlay above or below its own frame.
- Horizontal alignment supports `.leading`, `.center`, `.trailing`.

```swift
AnchoredOverlayButton(
    placement: .top(alignment: .center)   // or .leading / .trailing
) {
    Label("Help", systemImage: "questionmark.circle")
} content: {
    DirectionalTipView(title: "Tip", message: "Centered above the button.")
}
```

### Placement options

- `.top(spacing: CGFloat = 0, alignment: .leading | .center | .trailing)`
- `.bottom(spacing: CGFloat = 0, alignment: .leading | .center | .trailing)`

`spacing` sets the vertical gap from the anchor; `alignment` keeps the overlay horizontally aligned to the button’s leading/center/trailing edge. The container clamps the final position to stay within bounds when possible.

## API Summary

- `OverlayContainer`: Owns an `OverlayManager` and mounts the host automatically
- `@Environment(\.overlayManager)`: Access the manager anywhere in the subtree
- `presentCentered(...)`: Show a centered overlay
- `AnchoredOverlayButton(...)`: Show an overlay anchored to the triggering button
- `dismissTop()`, `dismissAll()`: Remove the top-most or all overlays
- `OverlayDismissPolicy`: `.tapOutside`, `.actionOnly`, `.none`
- `OverlayInteractionBarrier`: `.blockAll`, `.passthrough`

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
