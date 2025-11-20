//
//  OverlayHost.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - OverlayHost View Modifier

/// Captures the container view’s layout and renders the overlay stack on top.
///
/// You typically use ``OverlayContainer`` which applies this modifier for you:
///
/// ```swift
/// OverlayContainer {
///   ContentView()
/// }
/// ```
///
/// Responsibilities:
/// - Establish a dedicated coordinate space for overlays
/// - Render all active overlays
/// - Handle the background scrim (tap‑blocking or passthrough) for the top overlay
struct OverlayHost: ViewModifier {
  // Optional because the environment entry starts out nil until the container injects.
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
    if let manager, let lastItem = manager.top {
      let containerFrame = proxy.frame(in: .named(OverlaySpace.name))
      ZStack {
        backgroundBarrier(for: lastItem, manager: manager)
        ForEach(manager.stack) { item in
          let isTop = item.id == lastItem.id
          OverlayElement(
            item: item,
            proxy: proxy,
            containerFrame: containerFrame,
            isTop: isTop
          )
          .zIndex(zIndex(for: item, manager: manager))
        }
      }
    } else {
      EmptyView()
    }
  }

  /// Draws the background behind overlays (blocking scrim or passthrough).
  ///
  /// - Parameters:
  ///   - top: The topmost overlay item in the stack.
  ///   - manager: Manager used to forward dismissal actions.
  @ViewBuilder
  private func backgroundBarrier(for top: OverlayItem, manager: OverlayManager) -> some View {
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

  /// Computes z-index so later items render above earlier ones.
  ///
  /// - Parameters:
  ///   - item: The overlay to compute for.
  ///   - manager: The manager holding the stack order.
  /// - Returns: A z-index higher than previously added items.
  private func zIndex(for item: OverlayItem, manager: OverlayManager) -> Double {
    guard let index = manager.stack.firstIndex(where: { $0.id == item.id }) else { return 0 }
    return Double(index + 1)
  }
}

// MARK: - OverlayElement

/// Renders a single overlay, reads its measured size, and computes its final position.
///
/// Note: Accessibility and hit-testing are restricted to the top item to keep
/// focus and interactions correct.
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

  /// Anchor rect in container-local coordinates (nil for free-floating overlays).
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

/// Reports the child view’s rendered size to the manager without disrupting layout.
///
/// The overlay’s position depends on the real content size. This view uses
/// `GeometryReader` to observe size changes and keeps the manager up to date.
private struct OverlaySizeReader: View {
  @Environment(\.overlayManager) private var store

  let id: OverlayID

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      Color.clear
        .onAppear { store?.updateSize(size, for: id) }
        .onChange(of: size) { _, newSize in
          store?.updateSize(newSize, for: id)
        }
        .onDisappear { store?.updateSize(nil, for: id) }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

// MARK: - OverlayLayout

/// Pure helper for computing final overlay positions.
///
/// Given the presentation style, container/content sizes, and optional anchor
/// rect, returns the overlay’s center point. Side‑effect free and easy to test.
private enum OverlayLayout {
  /// Returns the final center position for an overlay.
  ///
  /// - Parameters:
  ///   - presentation: Centered or anchored placement.
  ///   - containerSize: Size of the container view.
  ///   - contentSize: Rendered size of the overlay content.
  ///   - anchorRect: Anchor rect when anchored, otherwise `nil`.
  /// - Returns: The center point in the container’s coordinate space.
  static func position(
    presentation: OverlayPresentation,
    containerSize: CGSize,
    contentSize: CGSize,
    anchorRect: CGRect?
  ) -> CGPoint {
		switch presentation {
		case .centered(let offset):
			return CGPoint(
				x: containerSize.width / 2 + offset.x,
				y: containerSize.height / 2 + offset.y
			)
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

  /// Computes the center for anchored overlays, respecting spacing and bounds.
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

  /// Keeps the overlay horizontally aligned relative to the anchor.
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
