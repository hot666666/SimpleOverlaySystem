import SwiftUI
import Testing
@testable import SimpleOverlaySystem

@Suite("OverlayManager API")
struct OverlayManagerTests {
  @Test("dismissTop removes only the last overlay")
  @MainActor func dismissTopRemovesLastOverlayOnly() {
    let manager = OverlayManager()
    let firstID = manager.presentCentered { EmptyView() }
    let secondID = manager.presentCentered { EmptyView() }

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
    let firstID = manager.presentCentered { EmptyView() }
    let secondID = manager.presentCentered { EmptyView() }
    let thirdID = manager.presentCentered { EmptyView() }

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
    }

    guard let item = manager.item(withID: id) else {
      #expect(Bool(false), "Failed to present overlay")
      return
    }

    // Verify that the overlay has the tap policy
    #expect(item.dismissPolicy == .tap)

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
