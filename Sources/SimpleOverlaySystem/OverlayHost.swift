//
//  OverlayHost.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - OverlayHost View Modifier

/// Captures layout information for the container view and renders every overlay on top.
struct OverlayHost: ViewModifier {
	@Environment(\.overlayManager) private var manager

	func body(content: Content) -> some View {
		content
			.coordinateSpace(name: OverlaySpace.name)
			.overlay {
				GeometryReader { proxy in
					overlays(proxy: proxy)
				}
			}
	}

	@ViewBuilder
	private func overlays(proxy: GeometryProxy) -> some View {
		// Render overlays only when the manager has items to avoid extra layout work.
		if let lastItem = manager.top {
			let containerFrame = proxy.frame(in: .named(OverlaySpace.name))
			ZStack {
				backgroundBarrier(for: lastItem)
				ForEach(manager.stack) { item in
					let isTop = item.id == lastItem.id
					OverlayElement(
						item: item,
						proxy: proxy,
						containerFrame: containerFrame,
						isTop: isTop
					)
					.zIndex(zIndex(for: item))
				}
			}
		} else {
			EmptyView()
		}
	}

	/// Draws the semantic background (tap-blocking barrier or passthrough scrim) behind overlays.
	@ViewBuilder
	private func backgroundBarrier(for top: OverlayItem) -> some View {
		switch top.barrier {
		case .blockAll:
			Rectangle()
				.fill(Color.black.opacity(top.backdropOpacity))
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.allowsHitTesting(true)
				.onTapGesture {
					if top.dismissPolicy == .tapOutside {
						manager.dismissTop()
					}
				}
		case .passthrough:
			Rectangle()
				.fill(Color.black.opacity(top.backdropOpacity))
				.ignoresSafeArea()
				.contentShape(Rectangle())
				.allowsHitTesting(false)
		}
	}

	/// Ensures overlays later in the stack render above earlier entries.
	private func zIndex(for item: OverlayItem) -> Double {
		guard let index = manager.stack.firstIndex(where: { $0.id == item.id }) else { return 0 }
		return Double(index + 1)
	}
}

// MARK: - OverlayElement

/// Single overlay entry that reads its measured size and decides its position.
private struct OverlayElement: View {
	let item: OverlayItem
	let proxy: GeometryProxy
	let containerFrame: CGRect
	let isTop: Bool

	// MARK: - Body
	var body: some View {
		item.content()
			.background(OverlaySizeReader(id: item.id))
			.fixedSize()
			.position(position)
			.opacity(isMeasured ? 1 : 0)
			.accessibilityAddTraits(.isModal)
			.allowsHitTesting(isTop)
			.accessibilityHidden(!isTop)
	}

	// MARK: - Computed
	private var containerSize: CGSize { proxy.size }

	private var center: CGPoint {
		CGPoint(x: containerSize.width * 0.5, y: containerSize.height * 0.5)
	}

	private var measuredSize: CGSize? { item.size }

	private var isMeasured: Bool { measuredSize != nil }

	/// Anchor rect in *container-local* coordinates (nil if free-floating presentation).
	private var anchorRect: CGRect? {
		guard case .anchored = item.presentation,
			let anchor = item.anchorFrame
		else { return nil }

		return anchor.offsetBy(
			dx: -containerFrame.origin.x,
			dy: -containerFrame.origin.y)
	}

	private var position: CGPoint {
		guard let contentSize = measuredSize else { return center }
		return OverlayLayout.position(
			presentation: item.presentation,
			containerSize: containerSize,
			contentSize: contentSize,
			anchorRect: anchorRect
		)
	}
}

// MARK: - OverlaySizeReader

/// Reports the child view's dimensions back to the manager without disrupting layout.
private struct OverlaySizeReader: View {
	@Environment(\.overlayManager) private var store

	let id: OverlayID

	var body: some View {
		GeometryReader { proxy in
			let size = proxy.size
			Color.clear
				.onAppear { store.updateSize(size, for: id) }
				.onChange(of: size) { _, newSize in
					store.updateSize(newSize, for: id)
				}
				.onDisappear { store.updateSize(nil, for: id) }
		}
		.allowsHitTesting(false)
		.accessibilityHidden(true)
	}
}

// MARK: - OverlayLayout

/// Pure helper for computing where overlays should sit within the container.
private enum OverlayLayout {
	/// Returns a final anchor point for the overlay's center.
	static func position(
		presentation: OverlayPresentation,
		containerSize: CGSize,
		contentSize: CGSize,
		anchorRect: CGRect?
	) -> CGPoint {
		switch presentation {
		case .centered:
			return CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
		case .anchored(let placement):
			guard let anchorRect else {
				return CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
			}
			return anchoredPosition(
				placement: placement,
				anchorRect: anchorRect,
				containerSize: containerSize,
				contentSize: contentSize
			)
		}
	}

	/// Calculates the overlay center for anchored presentations while respecting spacing and bounds.
	private static func anchoredPosition(
		placement: OverlayPlacement,
		anchorRect: CGRect,
		containerSize: CGSize,
		contentSize: CGSize
	) -> CGPoint {
		switch placement {
		case .top(let spacing, let alignment):
			let x = horizontalCoordinate(
				for: alignment,
				anchorRect: anchorRect,
				contentSize: contentSize,
				containerWidth: containerSize.width
			)
			let y = anchorRect.minY - spacing - contentSize.height / 2
			return CGPoint(
				x: clamp(
					x, min: contentSize.width / 2, max: containerSize.width - contentSize.width / 2),
				y: max(contentSize.height / 2, y)
			)
		case .bottom(let spacing, let alignment):
			let x = horizontalCoordinate(
				for: alignment,
				anchorRect: anchorRect,
				contentSize: contentSize,
				containerWidth: containerSize.width
			)
			let y = anchorRect.maxY + spacing + contentSize.height / 2
			return CGPoint(
				x: clamp(
					x, min: contentSize.width / 2, max: containerSize.width - contentSize.width / 2),
				y: min(containerSize.height - contentSize.height / 2, y)
			)
		}
	}

	/// Keeps the overlay horizontally aligned relative to the anchor rect.
	private static func horizontalCoordinate(
		for alignment: OverlayPlacement.HorizontalAlignment,
		anchorRect: CGRect,
		contentSize: CGSize,
		containerWidth: CGFloat
	) -> CGFloat {
		switch alignment {
		case .leading:
			return anchorRect.minX + contentSize.width / 2
		case .center:
			return anchorRect.midX
		case .trailing:
			return anchorRect.maxX - contentSize.width / 2
		}
	}

	private static func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
		guard min < max else { return value }
		return Swift.min(Swift.max(value, min), max)
	}
}
