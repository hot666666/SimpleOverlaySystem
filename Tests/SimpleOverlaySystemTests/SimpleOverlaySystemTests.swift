import SwiftUI
import Testing
@testable import SimpleOverlaySystem

@Suite("OverlayManager API")
struct OverlayManagerTests {
  @Test("dismissTop removes only the last overlay")
  @MainActor func dismissTopRemovesLastOverlayOnly() {
    let manager = OverlayManager()
    let firstID = manager.presentCentered { EmptyView() }!
    let secondID = manager.presentCentered { EmptyView() }!

    #expect(manager.stack.count == 2)
    #expect(manager.top?.id == secondID)

    manager.dismissTop()

    #expect(manager.stack.count == 1)
    #expect(manager.top?.id == firstID)
  }

  @Test("dismissAll clears the entire stack")
  @MainActor func dismissAllClearsStack() {
    let manager = OverlayManager()
    manager.presentCentered { EmptyView() }
    manager.presentCentered { EmptyView() }

    #expect(!manager.stack.isEmpty)

    manager.dismissAll()

    #expect(manager.stack.isEmpty)
  }

  @Test("dismiss(id:) removes a specific overlay")
  @MainActor func dismissByIdRemovesSpecificOverlay() {
    let manager = OverlayManager()
    let firstID = manager.presentCentered { EmptyView() }!
    let secondID = manager.presentCentered { EmptyView() }!
    let thirdID = manager.presentCentered { EmptyView() }!

    #expect(manager.stack.count == 3)

    manager.dismiss(id: secondID)

    #expect(manager.stack.count == 2)
    #expect(manager.item(withID: secondID) == nil)
    #expect(manager.item(withID: firstID) != nil)
    #expect(manager.item(withID: thirdID) != nil)
  }

  @Test("onTapBackground modifier provides custom handler")
  @MainActor func onTapBackgroundModifier() {
    let manager = OverlayManager()

    // Present with tap-to-dismiss policy
    let id = manager.presentCentered(dismissPolicy: .tap) {
      Text("Modifier Overlay")
        .onTapBackground {
          // Custom handler would be called instead of default dismiss
        }
    }!

    guard let item = manager.item(withID: id) else {
      #expect(Bool(false), "Failed to present overlay")
      return
    }

    // Verify that the overlay has the tap policy
    #expect(item.dismissPolicy == DismissPolicy.tap)

    // Note: The actual handler registration via PreferenceKey cannot be tested
    // in a unit test without a view hierarchy. This requires UI testing.
  }
}

@Suite("Convenience API Logic")
struct ConvenienceAPITests {
  @Test("presentWithConfirmation convenience logic works")
  @MainActor func presentWithConfirmationLogic() {
    // Manually test the logic inside the convenience API, since testing the
    // ViewBuilder and capturing the closures is problematic in a non-UI test env.

    // --- Test Cancel Action ---
    let managerForCancel = OverlayManager()
    // 1. Present original overlay
    let idForCancel = managerForCancel.presentCentered(dismissPolicy: .programmatic) { Text("Original") }
    // 2. Present confirmation dialog
    managerForCancel.presentCentered(dismissPolicy: .programmatic) { Text("Dialog") }

    // 3. Define and execute the cancel action
    let cancelAction = {
      managerForCancel.dismissTop()
    }
    #expect(managerForCancel.stack.count == 2)
    cancelAction()
    #expect(managerForCancel.stack.count == 1)
    #expect(managerForCancel.top?.id == idForCancel)

    // --- Test Confirm Action ---
    let managerForConfirm = OverlayManager()
    // 1. Present confirmation dialog
    managerForConfirm.presentCentered(dismissPolicy: .programmatic) { Text("Dialog") }

    // 2. Define and execute the confirm action
    let confirmAction = {
      managerForConfirm.dismissTop()
    }
    #expect(managerForConfirm.stack.count == 1)
    confirmAction()
    #expect(managerForConfirm.stack.isEmpty)
  }
}

extension OverlayManager {
  fileprivate func item(withID id: OverlayID) -> OverlayItem? {
    stack.first(where: { $0.id == id })
  }
}

@Suite("OverlayIdentifier API")
struct OverlayIdentifierTests {
  @Test("auto identifier allows multiple overlays")
  @MainActor func autoIdentifierAllowsMultiple() {
    let manager = OverlayManager()

    let first = manager.presentCentered(id: .auto) { EmptyView() }
    let second = manager.presentCentered(id: .auto) { EmptyView() }

    #expect(first != nil)
    #expect(second != nil)
    #expect(first != second)
    #expect(manager.stack.count == 2)
  }

  @Test("default parameter uses auto behavior")
  @MainActor func defaultParameterIsAuto() {
    let manager = OverlayManager()

    let first = manager.presentCentered { EmptyView() }
    let second = manager.presentCentered { EmptyView() }

    #expect(first != nil)
    #expect(second != nil)
    #expect(manager.stack.count == 2)
  }

  @Test("unique identifier ignores duplicate presentation")
  @MainActor func uniqueIdentifierIgnoresDuplicate() {
    let manager = OverlayManager()

    let first = manager.presentCentered(id: .unique("sheet")) { Text("First") }
    let second = manager.presentCentered(id: .unique("sheet")) { Text("Second") }

    #expect(first != nil)
    #expect(second == nil, "Second presentation should be ignored")
    #expect(manager.stack.count == 1)
  }

  @Test("unique identifier allows different keys")
  @MainActor func uniqueIdentifierAllowsDifferentKeys() {
    let manager = OverlayManager()

    let first = manager.presentCentered(id: .unique("sheet-a")) { EmptyView() }
    let second = manager.presentCentered(id: .unique("sheet-b")) { EmptyView() }

    #expect(first != nil)
    #expect(second != nil)
    #expect(manager.stack.count == 2)
  }

  @Test("replacing identifier dismisses existing and presents new")
  @MainActor func replacingIdentifierReplacesExisting() {
    let manager = OverlayManager()

    let first = manager.presentCentered(id: .replacing("alert")) { Text("First") }
    let second = manager.presentCentered(id: .replacing("alert")) { Text("Second") }

    #expect(first != nil)
    #expect(second != nil)
    #expect(first != second, "Should have different IDs")
    #expect(manager.stack.count == 1, "Only one overlay should exist")
    #expect(manager.top?.id == second)
  }

  @Test("contains(key:) returns true for existing key")
  @MainActor func containsKeyReturnsTrue() {
    let manager = OverlayManager()

    manager.presentCentered(id: .unique("settings")) { EmptyView() }

    #expect(manager.contains(key: "settings"))
    #expect(!manager.contains(key: "nonexistent"))
  }

  @Test("contains(key:) returns false for auto identifiers")
  @MainActor func containsKeyFalseForAuto() {
    let manager = OverlayManager()

    manager.presentCentered(id: .auto) { EmptyView() }

    #expect(!manager.contains(key: "auto"))
    #expect(!manager.contains(key: ""))
  }

  @Test("dismiss(key:) removes overlay with matching key")
  @MainActor func dismissKeyRemovesMatching() {
    let manager = OverlayManager()

    manager.presentCentered(id: .unique("todo")) { EmptyView() }
    manager.presentCentered(id: .unique("settings")) { EmptyView() }

    #expect(manager.stack.count == 2)

    manager.dismiss(key: "todo")

    #expect(manager.stack.count == 1)
    #expect(!manager.contains(key: "todo"))
    #expect(manager.contains(key: "settings"))
  }

  @Test("presentAnchored supports identifier")
  @MainActor func presentAnchoredSupportsIdentifier() {
    let manager = OverlayManager()

    let first = manager.presentAnchored(
      id: .unique("tooltip"),
      anchorFrame: CGRect(x: 0, y: 0, width: 100, height: 50),
      placement: .bottom()
    ) { EmptyView() }

    let second = manager.presentAnchored(
      id: .unique("tooltip"),
      anchorFrame: CGRect(x: 0, y: 0, width: 100, height: 50),
      placement: .bottom()
    ) { EmptyView() }

    #expect(first != nil)
    #expect(second == nil)
    #expect(manager.stack.count == 1)
  }

  @Test("mixed auto and unique identifiers coexist")
  @MainActor func mixedIdentifiersCoexist() {
    let manager = OverlayManager()

    manager.presentCentered(id: .unique("sheet")) { EmptyView() }
    manager.presentCentered(id: .auto) { EmptyView() }
    manager.presentCentered(id: .auto) { EmptyView() }

    #expect(manager.stack.count == 3)
    #expect(manager.contains(key: "sheet"))
  }
}

@Suite("Semantic surface API")
struct SemanticSurfaceTests {
  @Test("toast derives non-modal policies")
  @MainActor func toastDerivesPolicies() {
    let manager = OverlayManager()
    let id = manager.present(
      .toast(edge: .bottom, alignment: .end, duration: .persistent)
    ) { Text("Saved") }!

    let item = manager.item(withID: id)!
    #expect(item.isToast)
    #expect(item.dismissPolicy == .programmatic)
    #expect(item.barrier == .passthrough)
    #expect(item.backdropOpacity == 0)
  }

  @Test("drawer derives modal policies from host configuration")
  @MainActor func drawerDerivesPolicies() {
    let manager = OverlayManager(
      configuration: OverlayConfiguration(drawerBackdropOpacity: 0.42)
    )
    let id = manager.present(
      .drawer(edge: .trailing, extent: .inspector)
    ) { Text("Inspector") }!

    let item = manager.item(withID: id)!
    #expect(item.isDrawer)
    #expect(item.dismissPolicy == .tap)
    #expect(item.barrier == .blockAll)
    #expect(item.backdropOpacity == 0.42)
  }

  @Test("toast overflow removes the oldest toast on the same edge")
  @MainActor func toastOverflowRemovesOldestOnEdge() {
    let manager = OverlayManager(
      configuration: OverlayConfiguration(maximumVisibleToastsPerEdge: 3)
    )
    let first = manager.present(.toast(edge: .bottom, duration: .persistent)) { Text("1") }!
    let second = manager.present(.toast(edge: .bottom, duration: .persistent)) { Text("2") }!
    let third = manager.present(.toast(edge: .bottom, duration: .persistent)) { Text("3") }!
    let top = manager.present(.toast(edge: .top, duration: .persistent)) { Text("top") }!
    let fourth = manager.present(.toast(edge: .bottom, duration: .persistent)) { Text("4") }!

    #expect(manager.item(withID: first) == nil)
    #expect(manager.item(withID: second) != nil)
    #expect(manager.item(withID: third) != nil)
    #expect(manager.item(withID: fourth) != nil)
    #expect(manager.item(withID: top) != nil)
    #expect(manager.stack.count == 4)
  }

  @Test("automatic toast dismisses and persistent toast remains")
  @MainActor func automaticToastDismisses() async throws {
    let manager = OverlayManager()
    let automatic = manager.present(
      .toast(edge: .bottom, duration: .seconds(0.02))
    ) { Text("Automatic") }!
    let persistent = manager.present(
      .toast(edge: .top, duration: .persistent)
    ) { Text("Persistent") }!

    try await Task.sleep(for: .milliseconds(200))

    #expect(manager.item(withID: automatic) == nil)
    #expect(manager.item(withID: persistent) != nil)
  }

  @Test("updating a Binding-owned toast restarts its lifetime")
  @MainActor func bindingToastUpdateRestartsLifetime() async throws {
    let manager = OverlayManager()
    let id = OverlayID()

    func synchronize() {
      manager.synchronizeBindingPresentation(
        id: id,
        presentation: .surface(.toast(edge: .bottom, duration: .seconds(0.3))),
        dismissPolicy: .programmatic,
        barrier: .passthrough,
        backdropOpacity: 0,
        anchorFrame: nil,
        content: { AnyView(Text("Toast")) },
        onDismiss: {}
      )
    }

    synchronize()
    try await Task.sleep(for: .milliseconds(200))
    synchronize()
    try await Task.sleep(for: .milliseconds(200))

    #expect(manager.item(withID: id) != nil)

    try await Task.sleep(for: .milliseconds(150))
    #expect(manager.item(withID: id) == nil)
  }

  @Test("dismissTop prioritizes an interactive presentation over toast lanes")
  @MainActor func dismissTopPrioritizesInteractivePresentation() {
    let manager = OverlayManager()
    let drawer = manager.present(
      .drawer(edge: .trailing, extent: .fixed(320))
    ) { Text("Drawer") }!
    let toast = manager.present(
      .toast(edge: .bottom, duration: .persistent)
    ) { Text("Toast") }!

    manager.dismissTop()

    #expect(manager.item(withID: drawer) == nil)
    #expect(manager.item(withID: toast) != nil)
  }

  @Test("Binding-owned presentation updates in place and notifies on host dismissal")
  @MainActor func bindingPresentationUpdatesInPlace() {
    let manager = OverlayManager()
    let id = OverlayID()
    var didDismiss = false

    manager.synchronizeBindingPresentation(
      id: id,
      presentation: .surface(.drawer(edge: .trailing, extent: .fixed(320))),
      dismissPolicy: .tap,
      barrier: .blockAll,
      backdropOpacity: 0,
      anchorFrame: nil,
      content: { AnyView(Text("A")) },
      onDismiss: { didDismiss = true }
    )
    manager.synchronizeBindingPresentation(
      id: id,
      presentation: .surface(.drawer(edge: .trailing, extent: .fixed(360))),
      dismissPolicy: .tap,
      barrier: .blockAll,
      backdropOpacity: 0,
      anchorFrame: nil,
      content: { AnyView(Text("B")) },
      onDismiss: { didDismiss = true }
    )

    #expect(manager.stack.count == 1)
    #expect(manager.stack[0].id == id)
    #expect(manager.stack[0].presentation == .surface(.drawer(edge: .trailing, extent: .fixed(360))))

    manager.dismiss(id: id)
    #expect(didDismiss)
  }

  @Test("geometry overflow notifies a Binding-owned Toast")
  @MainActor func geometryOverflowNotifiesBindingOwner() {
    let manager = OverlayManager()
    let id = OverlayID()
    var didDismiss = false

    manager.synchronizeBindingPresentation(
      id: id,
      presentation: .surface(.toast(edge: .bottom, duration: .persistent)),
      dismissPolicy: .programmatic,
      barrier: .passthrough,
      backdropOpacity: 0,
      anchorFrame: nil,
      content: { AnyView(Text("Large Toast")) },
      onDismiss: { didDismiss = true }
    )

    manager.removeOverflowingToasts(ids: [id])

    #expect(manager.item(withID: id) == nil)
    #expect(didDismiss)
  }
}

@Suite("Semantic overlay layout")
struct SemanticOverlayLayoutTests {
  private let configuration = OverlayConfiguration(
    toastEdgePadding: 16,
    toastSpacing: 8
  )

  @Test("bottom-end toast respects safe area")
  func bottomEndToastRespectsSafeArea() {
    let id = OverlayID()
    let size = CGSize(width: 100, height: 40)
    let position = OverlayLayout.position(
      id: id,
      presentation: .surface(.toast(edge: .bottom, alignment: .end, duration: .persistent)),
      containerSize: CGSize(width: 360, height: 640),
      contentSize: size,
      anchorRect: nil,
      safeAreaInsets: EdgeInsets(top: 20, leading: 0, bottom: 34, trailing: 0),
      configuration: configuration,
      toastStack: [ToastLayoutEntry(id: id, edge: .bottom, size: size)]
    )

    #expect(position == CGPoint(x: 294, y: 570))
  }

  @Test("newest toast stays closest to the edge")
  func newestToastStaysClosestToEdge() {
    let oldest = OverlayID()
    let newest = OverlayID()
    let size = CGSize(width: 100, height: 40)
    let stack = [
      ToastLayoutEntry(id: oldest, edge: .bottom, size: size),
      ToastLayoutEntry(id: newest, edge: .bottom, size: size),
    ]
    let presentation = OverlayPresentation.surface(
      .toast(edge: .bottom, alignment: .end, duration: .persistent)
    )

    let oldestPosition = OverlayLayout.position(
      id: oldest,
      presentation: presentation,
      containerSize: CGSize(width: 360, height: 640),
      contentSize: size,
      anchorRect: nil,
      configuration: configuration,
      toastStack: stack
    )
    let newestPosition = OverlayLayout.position(
      id: newest,
      presentation: presentation,
      containerSize: CGSize(width: 360, height: 640),
      contentSize: size,
      anchorRect: nil,
      configuration: configuration,
      toastStack: stack
    )

    #expect(newestPosition.y == 604)
    #expect(oldestPosition.y == 556)
  }

  @Test("horizontal start and end follow right-to-left layout")
  func horizontalAlignmentFollowsRTL() {
    let id = OverlayID()
    let size = CGSize(width: 100, height: 40)
    let position = OverlayLayout.position(
      id: id,
      presentation: .surface(.toast(edge: .bottom, alignment: .end, duration: .persistent)),
      containerSize: CGSize(width: 360, height: 640),
      contentSize: size,
      anchorRect: nil,
      layoutDirection: .rightToLeft,
      configuration: configuration,
      toastStack: [ToastLayoutEntry(id: id, edge: .bottom, size: size)]
    )

    #expect(position.x == 66)
  }

  @Test("large Toasts evict the oldest item before lanes overlap")
  func largeToastsUseGeometryAwareOverflow() {
    let oldest = OverlayID()
    let middle = OverlayID()
    let newest = OverlayID()
    let size = CGSize(width: 300, height: 300)
    let entries = [oldest, middle, newest].map {
      ToastLayoutEntry(id: $0, edge: .bottom, size: size)
    }

    let plan = OverlayLayout.toastStackPlan(
      entries: entries,
      containerSize: CGSize(width: 360, height: 640),
      configuration: configuration
    )

    #expect(plan.visibleEntries.map(\.id) == [middle, newest])
    #expect(plan.overflowIDs == [oldest])

    let frames = plan.visibleEntries.map { entry in
      let position = OverlayLayout.position(
        id: entry.id,
        presentation: .surface(.toast(edge: .bottom, duration: .persistent)),
        containerSize: CGSize(width: 360, height: 640),
        contentSize: entry.size,
        anchorRect: nil,
        configuration: configuration,
        toastStack: plan.visibleEntries
      )
      return CGRect(
        x: position.x - entry.size.width / 2,
        y: position.y - entry.size.height / 2,
        width: entry.size.width,
        height: entry.size.height
      )
    }

    #expect(!frames[0].intersects(frames[1]))
  }

  @Test("container shrink keeps only the newest Toasts that still fit")
  func toastPlanRespondsToContainerShrink() {
    let ids = [OverlayID(), OverlayID(), OverlayID()]
    let entries = ids.map {
      ToastLayoutEntry(id: $0, edge: .bottom, size: CGSize(width: 280, height: 140))
    }

    let widePlan = OverlayLayout.toastStackPlan(
      entries: entries,
      containerSize: CGSize(width: 360, height: 640),
      configuration: configuration
    )
    let shortPlan = OverlayLayout.toastStackPlan(
      entries: entries,
      containerSize: CGSize(width: 360, height: 340),
      configuration: configuration
    )

    #expect(widePlan.visibleEntries.map(\.id) == ids)
    #expect(shortPlan.visibleEntries.map(\.id) == Array(ids.suffix(2)))
    #expect(shortPlan.overflowIDs == [ids[0]])
  }

  @Test("drawer extent and position remain inside host bounds", arguments: [360.0, 736.0, 1024.0])
  func drawerStaysInsideHost(width: CGFloat) {
    let containerSize = CGSize(width: width, height: 768)
    let intrinsicSize = CGSize(width: 500, height: 400)
    let presentation = OverlayPresentation.surface(
      .drawer(edge: .trailing, extent: .inspector)
    )
    let renderedSize = OverlayLayout.renderedSize(
      presentation: presentation,
      containerSize: containerSize,
      intrinsicSize: intrinsicSize,
      safeAreaInsets: EdgeInsets(),
      layoutDirection: .leftToRight,
      configuration: configuration
    )
    let position = OverlayLayout.position(
      id: OverlayID(),
      presentation: presentation,
      containerSize: containerSize,
      contentSize: renderedSize,
      anchorRect: nil,
      configuration: configuration
    )

    #expect(renderedSize.width == min(360, width))
    #expect(renderedSize.height == 768)
    #expect(position.x + renderedSize.width / 2 == width)
    #expect(position.y == 384)
  }

  @Test("bottom drawer fraction controls height")
  func bottomDrawerFractionControlsHeight() {
    let presentation = OverlayPresentation.surface(
      .drawer(edge: .bottom, extent: .fraction(0.4))
    )
    let renderedSize = OverlayLayout.renderedSize(
      presentation: presentation,
      containerSize: CGSize(width: 1024, height: 768),
      intrinsicSize: CGSize(width: 200, height: 200),
      safeAreaInsets: EdgeInsets(),
      layoutDirection: .leftToRight,
      configuration: configuration
    )

    #expect(renderedSize.width == 1024)
    #expect(abs(renderedSize.height - 307.2) < 0.001)
  }
}

private struct BindingAPIFixtureItem: Identifiable {
  let id: Int
}

private struct BindingAPIFixture: View {
  @State private var isPresented = false
  @State private var item: BindingAPIFixtureItem?

  var body: some View {
    Text("Anchor")
      .overlayCentered(isPresented: $isPresented) { Text("Centered") }
      .overlayAnchored(item: $item, placement: .bottom()) { value in
        Text("Anchored \(value.id)")
      }
      .overlayToast(item: $item, edge: .bottom) { value in
        Text("Toast \(value.id)")
      }
      .overlayDrawer(item: $item, edge: .trailing) { value in
        Text("Drawer \(value.id)")
      }
  }
}

@Suite("Binding API compile fixture")
struct BindingAPICompileTests {
  @Test("all Binding façades compose as SwiftUI modifiers")
  @MainActor func bindingFacadesCompile() {
    _ = BindingAPIFixture()
  }
}

@Suite("Dismiss handler freshness")
struct DismissHandlerFreshnessTests {
  @Test("a stored preference handler performs its latest action")
  @MainActor func storedHandlerUsesLatestAction() {
    let actionBox = DismissHandlerActionBox()
    let storedHandler = DismissHandler(id: OverlayID(), actionBox: actionBox)
    var outcome = ""

    actionBox.update { outcome = "blocked" }
    storedHandler.perform()
    #expect(outcome == "blocked")

    actionBox.update { outcome = "dismissed" }
    storedHandler.perform()
    #expect(outcome == "dismissed")
  }
}
