import SwiftUI
import Testing

@testable import SimpleOverlaySystem

@Suite("OverlayManager stack behavior")
struct OverlayManagerTests {
	@Test("dismissTop removes only the last overlay")
	func dismissTopRemovesLastOverlayOnly() {
		let manager = OverlayManager()
		let firstID = manager.presentCentered { EmptyView() }
		manager.updateSize(CGSize(width: 120, height: 120), for: firstID)
		let anchor = CGRect(x: 0, y: 0, width: 44, height: 24)
		let secondID = manager.presentAnchored(anchorFrame: anchor, placement: .bottom()) {
			EmptyView()
		}
		manager.updateSize(CGSize(width: 60, height: 60), for: secondID)

		#expect(manager.stack.count == 2)
		#expect(manager.top?.id == secondID)

		manager.dismissTop()

		#expect(manager.stack.count == 1)
		#expect(manager.top?.id == firstID)
		#expect(manager.item(withID: secondID)?.size == nil)
		#expect(manager.item(withID: firstID)?.size == CGSize(width: 120, height: 120))
	}

	@Test("dismissAll clears stack, sizes, and anchors")
	func dismissAllClearsStackAndCaches() {
		let manager = OverlayManager()
		let anchor = CGRect(x: 10, y: 10, width: 30, height: 20)
		let overlayID = manager.presentAnchored(anchorFrame: anchor, placement: .top()) {
			EmptyView()
		}
		manager.updateSize(CGSize(width: 80, height: 40), for: overlayID)

		#expect(!manager.stack.isEmpty)
		#expect(manager.item(withID: overlayID)?.size != nil)
		#expect(manager.item(withID: overlayID)?.anchorFrame != nil)

		manager.dismissAll()

		#expect(manager.stack.isEmpty)
		#expect(manager.item(withID: overlayID) == nil)
	}
}

extension OverlayManager {
	fileprivate func item(withID id: OverlayID) -> OverlayItem? {
		stack.first(where: { $0.id == id })
	}
}
