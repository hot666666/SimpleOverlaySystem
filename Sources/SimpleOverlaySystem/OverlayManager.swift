//
//  OverlayManager.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - Overlay Manager

/// Observable store that drives overlay presentation and dismissal for a view hierarchy.
@Observable
public final class OverlayManager {
	/// Backing stack that preserves presentation order (last-in, first-out).
	private(set) var stack: [OverlayItem] = []

	public init() {}

	/// Convenience accessor for the visible overlay.
	var top: OverlayItem? { stack.last }

	/// Presents a centered overlay and returns the generated identifier so callers can update or dismiss it.
	@discardableResult
	public func presentCentered(
		dismissPolicy: OverlayDismissPolicy = .tapOutside,
		barrier: OverlayInteractionBarrier = .blockAll,
		backdropOpacity: Double = 0.35,
		@ViewBuilder content: @escaping () -> some View
	) -> OverlayID {
		let id = OverlayID()
		let builder = content
		let item = OverlayItem(
			id: id,
			presentation: .centered,
			dismissPolicy: dismissPolicy,
			barrier: barrier,
			backdropOpacity: backdropOpacity,
			content: { AnyView(builder()) },
			anchorFrame: nil,
			size: nil
		)
		push(item)
		return id
	}

	/// Presents an overlay relative to a captured anchor frame and placement.
	@discardableResult
	public func presentAnchored(
		anchorFrame: CGRect?,
		placement: OverlayPlacement,
		dismissPolicy: OverlayDismissPolicy = .tapOutside,
		barrier: OverlayInteractionBarrier = .blockAll,
		backdropOpacity: Double = 0.35,
		@ViewBuilder content: @escaping () -> some View
	) -> OverlayID {
		let id = OverlayID()
		let builder = content
		let item = OverlayItem(
			id: id,
			presentation: .anchored(placement: placement),
			dismissPolicy: dismissPolicy,
			barrier: barrier,
			backdropOpacity: backdropOpacity,
			content: { AnyView(builder()) },
			anchorFrame: anchorFrame,
			size: nil
		)
		push(item)
		return id
	}

	/// Removes only the most recently presented overlay.
	public func dismissTop() {
		_ = stack.popLast()
	}

	/// Removes every overlay to guarantee a clean slate.
	public func dismissAll() {
		guard !stack.isEmpty else { return }
		stack.removeAll(keepingCapacity: false)
	}

	/// Stores the latest anchor rect so anchored overlays can reposition when their source view moves.
	func updateAnchor(for id: OverlayID, frame: CGRect?) {
		updateItem(id) { $0.anchorFrame = frame }
	}

	/// Stores the rendered size so `OverlayLayout` can compute final positions.
	func updateSize(_ size: CGSize?, for id: OverlayID) {
		updateItem(id) { $0.size = size }
	}
}

// MARK: - Overlay Manager Helpers

extension OverlayManager {
	/// Adds an overlay to the stack while preserving ordering semantics.
	private func push(_ item: OverlayItem) {
		stack.append(item)
	}

	/// Performs in-place mutations on the overlay with the matching identifier.
	private func updateItem(_ id: OverlayID, perform: (inout OverlayItem) -> Void) {
		guard let index = stack.firstIndex(where: { $0.id == id }) else { return }
		perform(&stack[index])
	}
}
