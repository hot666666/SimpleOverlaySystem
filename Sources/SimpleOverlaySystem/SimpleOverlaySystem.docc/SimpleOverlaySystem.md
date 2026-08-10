# `SimpleOverlaySystem`

Lightweight overlay presentation for SwiftUI with centered, anchored, toast, and drawer surfaces.

## Overview

SimpleOverlaySystem provides a single overlay stack for your view hierarchy. Mount the host once near the root, then present overlays from anywhere using the environment manager.

```swift
import SwiftUI
import SimpleOverlaySystem

struct ContentView: View {
  @Environment(\.overlayManager) private var overlay

  var body: some View {
    Button("Show Centered Overlay") {
      overlay?.presentCentered {
        Text("Hello Overlay")
          .padding()
          .background(.background, in: .rect(cornerRadius: 18))
      }
    }
  }
}


#Preview {
  OverlayContainer {
    ContentView()
  }
}
```

Event-driven surfaces use the manager:

```swift
overlay?.present(
  .toast(edge: .bottom, alignment: .end),
  id: .replacing("saved")
) {
  Text("Saved")
    .padding()
    .background(.regularMaterial, in: .capsule)
}
```

State-driven surfaces use a Binding:

```swift
ContentView()
  .overlayDrawer(
    isPresented: $showInspector,
    edge: .trailing,
    extent: .inspector
  ) {
    InspectorView()
  }
```

See <doc:SemanticSurfaces> for lifecycle, stacking, dismissal, and migration guidance.

## Topics

### Essentials

- ``OverlayContainer``
- ``OverlayManager``

### Presenting Overlays

- ``OverlayManager/presentCentered(id:dismissPolicy:barrier:backdropOpacity:offset:content:)``
- ``OverlayManager/presentAnchored(id:anchorFrame:placement:dismissPolicy:barrier:backdropOpacity:content:)``
- ``OverlayManager/present(_:id:content:)``
- ``OverlayPlacement``
- ``OverlaySurface``
- ``OverlayEdge``
- ``EdgeAlignment``
- ``ToastDuration``
- ``DrawerEdge``
- ``DrawerExtent``
- ``AnchoredOverlayButton``

### Binding Presentations

- ``/SimpleOverlaySystem/SwiftUICore/View/overlayCentered(isPresented:dismissPolicy:barrier:backdropOpacity:offset:onDismiss:content:)``
- ``/SimpleOverlaySystem/SwiftUICore/View/overlayCentered(item:dismissPolicy:barrier:backdropOpacity:offset:onDismiss:content:)``
- ``/SimpleOverlaySystem/SwiftUICore/View/overlayAnchored(isPresented:placement:dismissPolicy:barrier:backdropOpacity:onDismiss:content:)``
- ``/SimpleOverlaySystem/SwiftUICore/View/overlayAnchored(item:placement:dismissPolicy:barrier:backdropOpacity:onDismiss:content:)``
- ``/SimpleOverlaySystem/SwiftUICore/View/overlayToast(isPresented:edge:alignment:duration:onDismiss:content:)``
- ``/SimpleOverlaySystem/SwiftUICore/View/overlayToast(item:edge:alignment:duration:onDismiss:content:)``
- ``/SimpleOverlaySystem/SwiftUICore/View/overlayDrawer(isPresented:edge:extent:onDismiss:content:)``
- ``/SimpleOverlaySystem/SwiftUICore/View/overlayDrawer(item:edge:extent:onDismiss:content:)``

### Dismissal and Interaction

- ``OverlayManager/dismissTop()``
- ``OverlayManager/dismissAll()``
- ``OverlayDismissAction``
- ``DismissPolicy``
- ``OverlayInteractionBarrier``
- ``/SimpleOverlaySystem/SwiftUICore/View/onTapBackground(perform:)``
- ``/SimpleOverlaySystem/SwiftUICore/View/onOverlayDismissRequest(perform:)``

### Host Configuration

- ``OverlayConfiguration``
- ``/SimpleOverlaySystem/SwiftUICore/EnvironmentValues/overlayManager``
- ``/SimpleOverlaySystem/SwiftUICore/EnvironmentValues/dismissOverlay``

### Design and Migration

- <doc:SemanticSurfaces>
