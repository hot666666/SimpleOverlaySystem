# Semantic Surfaces

Present edge-aware notifications and interactive drawers without exposing host coordinates or interaction-policy combinations.

## Public boundary

SimpleOverlaySystem has two public presentation façades backed by one internal request and layout core:

- `OverlayManager` handles event- and command-driven presentation, explicit identifiers, replacement, and toast stacking.
- View modifiers handle SwiftUI Binding ownership and keep presentation state synchronized in both directions.

The host keeps coordinates, measured sizes, safe-area projection, stacking lanes, focus, hit testing, accessibility, and transitions internal.

### Surface policy ownership

| Surface | Caller chooses | Host owns |
| --- | --- | --- |
| Toast | edge, alignment, duration, identifier, content | passthrough interaction, no backdrop, no focus capture, timer, measured per-edge capacity, inward stacking |
| Drawer | leading/trailing/bottom edge, extent, identifier, content | blocking backdrop, focus, Escape and accessibility dismissal, edge transition, safe-area-constrained layout |
| Centered / Anchored | placement plus the existing dismissal and barrier options | measurement, stack order, host-relative positioning |

Semantic surfaces intentionally do not expose raw offsets, barriers, focus switches, or transition directions. Adding those switches to each call site would allow invalid combinations such as a modal Toast or a passthrough Drawer.

### Internal ownership and request flow

Both public façades converge before rendering:

1. A View modifier or `OverlayManager.present` creates an internal `OverlayPresentation` request.
2. `OverlayManager` owns stable identities, presentation order, duplicate handling, Binding callbacks, the configured Toast count limit, and automatic-dismiss tasks.
3. `OverlayHost` derives the active backdrop, hit testing, transitions, focus, accessibility state, and `dismissOverlay` environment action. It also applies measured Toast overflow back to the manager so Binding owners are notified.
4. `OverlayLayout` performs pure host-relative geometry for safe areas, layout direction, measured Toast lane capacity, and Drawer extents.
5. Measured size changes produce a new layout plan without exposing geometry publicly or storing host geometry in the manager.

This split keeps the public API semantic and small while leaving reusable layout machinery package-internal. Binding-owned requests keep one stable overlay identity: changing a Drawer item updates content in place, while changing a Toast item deliberately restarts its lifetime.

## Present a toast

```swift
@Environment(\.overlayManager) private var overlay

func showSavedToast() {
  overlay?.present(
    .toast(
      edge: .bottom,
      alignment: .end,
      duration: .automatic
    ),
    id: .replacing("saved")
  ) {
    SavedToast()
  }
}
```

A toast does not create a backdrop or take focus when presented. Its own content remains interactive, and all space outside its bounds passes through to underlying content. Toasts group by edge, and the newest stays closest to the edge. The configured per-edge count is an upper bound: if measured content exceeds the safe-area lane, the host keeps the newest items that fit without overlap and removes older overflow deterministically.

## Present a drawer

```swift
overlay?.present(
  .drawer(edge: .trailing, extent: .inspector),
  id: .replacing("inspector")
) {
  InspectorView()
}
```

A drawer derives its transition from `DrawerEdge`, captures interaction and accessibility modal semantics, handles Escape and accessibility dismissal, and stays inside the current host bounds. It never changes the platform window frame.

## Bind presentation to state

```swift
WorkspaceView()
  .overlayDrawer(
    item: $selectedTodo,
    edge: .trailing,
    extent: .inspector,
    onDismiss: { selectionDidClose() }
  ) { todo in
    TodoInspector(todo: todo)
  }
```

Host dismissal writes `nil` back to the item Binding. Setting the Binding to `nil` dismisses the host presentation. Replacing one non-nil drawer item with another keeps the same surface identity and updates content without replaying its entry transition.

The centered, anchored, and toast families provide matching `isPresented` and `item` overloads.

## Validate dismissal

```swift
struct InspectorView: View {
  @Environment(\.dismissOverlay) private var dismissOverlay

  var body: some View {
    Editor()
      .onOverlayDismissRequest {
        if hasUnsavedChanges {
          showConfirmation = true
        } else {
          dismissOverlay()
        }
      }
  }
}
```

Installing `onOverlayDismissRequest` intercepts the automatic user dismissal. Call `dismissOverlay()` after validation or confirmation. Drawers route backdrop, Escape, and the accessibility escape action through this callback.

## Configure the host

```swift
OverlayContainer(
  configuration: OverlayConfiguration(
    toastEdgePadding: 16,
    toastSpacing: 8,
    maximumVisibleToastsPerEdge: 3,
    drawerBackdropOpacity: 0.35
  )
) {
  ContentView()
}
```

Keep shared lane geometry at the host boundary. Per-presentation APIs intentionally do not accept raw positions, offsets, transition directions, focus rules, or interaction barriers for semantic surfaces.

`maximumVisibleToastsPerEdge` limits the count, but does not force that many items to fit. Dynamic content size, the host size, and safe-area insets can reduce the visible count so Toasts never overlap within one lane.

## Explore in Xcode

Open `SemanticOverlayPreview.swift` and run the **Overlay API Playground** Preview. It exercises Manager and Binding presentation, every Toast edge, all supported Drawer edges and extents, Centered and Anchored overloads, overflow behavior, in-place item replacement, and dismissal interception.

## Migrate incrementally

Existing `presentCentered`, `presentAnchored`, `AnchoredOverlayButton`, `dismissTop`, and `onTapBackground` calls remain source-compatible.

Adopt the semantic APIs when the surface meaning is known:

- Replace a coordinate-shifted notification with `present(.toast(...))`.
- Replace an inspector-like centered overlay with `present(.drawer(...))` or `overlayDrawer(item:...)`.
- Keep app domain identifiers and state outside the package. Pass them through the Binding item or capture them in manager-presented content.
- Use `dismissOverlay` inside new content instead of assuming that `dismissTop` identifies the containing surface.
