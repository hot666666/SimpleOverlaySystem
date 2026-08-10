//
//  OverlayHost.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - OverlayHost

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
  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// Map of overlay IDs to their custom dismiss handlers.
  @State private var dismissHandlers: [OverlayID: DismissHandler] = [:]
  @State private var dismissRequestHandlers: [OverlayID: DismissHandler] = [:]

  func body(content: Content) -> some View {
    content
      .coordinateSpace(name: OverlaySpace.name)
      .overlay {
        GeometryReader { proxy in
          overlays(proxy: proxy)
        }
      }
      .onPreferenceChange(OverlayDismissHandlerPreferenceKey.self) { handlers in
        self.dismissHandlers = handlers
      }
      .onPreferenceChange(OverlayDismissRequestHandlerPreferenceKey.self) { handlers in
        self.dismissRequestHandlers = handlers
      }
  }

  @ViewBuilder
  private func overlays(proxy: GeometryProxy) -> some View {
    // Render overlays only when the manager has items to avoid extra layout work.
    if let manager, !manager.stack.isEmpty {
      let containerFrame = proxy.frame(in: .named(OverlaySpace.name))
      let topInteractive = manager.stack.last(where: { !$0.isToast })
      let toastPlan = toastLayoutPlan(manager: manager, proxy: proxy)
      ZStack(alignment: .top) {
        if let topInteractive {
          backgroundBarrier(for: topInteractive, manager: manager)
        }
        ForEach(manager.stack) { item in
          let isTopInteractive = item.id == topInteractive?.id
          OverlayElement(
            item: item,
            proxy: proxy,
            containerFrame: containerFrame,
            isTopInteractive: isTopInteractive,
            isVisibleInToastLane: toastPlan.visibleIDs.contains(item.id),
            layoutDirection: layoutDirection,
            configuration: manager.configuration,
            toastStack: toastPlan.visibleEntries,
            onDismissRequest: {
              handleDismissRequest(for: item, manager: manager, source: .escape)
            }
          )
          .environment(\.overlayID, item.id)
          .environment(
            \.dismissOverlay,
            OverlayDismissAction { manager.dismiss(id: item.id) }
          )
          .transition(transition(for: item))
          .zIndex(zIndex(for: item, manager: manager))
        }
      }
      .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.22), value: manager.stack.map(\.id))
      .task(id: toastPlan.overflowIDs) {
        manager.removeOverflowingToasts(ids: toastPlan.overflowIDs)
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
          handleDismissRequest(for: top, manager: manager, source: .backdrop)
        }
    case .passthrough:
      Rectangle()
        .fill(Color.black.opacity(top.backdropOpacity))
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .allowsHitTesting(false)
    }
  }

  /// Routes every user dismissal path through the semantic request handler.
  private func handleDismissRequest(
    for item: OverlayItem,
    manager: OverlayManager,
    source: DismissRequestSource
  ) {
    if let requestHandler = dismissRequestHandlers[item.id] {
      requestHandler.perform()
      return
    }

    if source == .backdrop, let legacyHandler = dismissHandlers[item.id] {
      legacyHandler.perform()
      return
    }

    switch item.dismissPolicy {
    case .tap: manager.dismiss(id: item.id)
    case .programmatic: break
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
    let layer = item.isToast ? 10_000 : 0
    return Double(layer + index + 1)
  }

  private func toastLayoutPlan(
    manager: OverlayManager,
    proxy: GeometryProxy
  ) -> ToastStackPlan {
    let entries: [ToastLayoutEntry] = manager.stack.compactMap { item in
      guard case .toast(let edge, _, _) = item.surface,
        let intrinsicSize = item.size
      else { return nil }
      let renderedSize = OverlayLayout.renderedSize(
        presentation: item.presentation,
        containerSize: proxy.size,
        intrinsicSize: intrinsicSize,
        safeAreaInsets: proxy.safeAreaInsets,
        layoutDirection: layoutDirection,
        configuration: manager.configuration
      )
      return ToastLayoutEntry(id: item.id, edge: edge, size: renderedSize)
    }
    return OverlayLayout.toastStackPlan(
      entries: entries,
      containerSize: proxy.size,
      safeAreaInsets: proxy.safeAreaInsets,
      layoutDirection: layoutDirection,
      configuration: manager.configuration
    )
  }

  private func transition(for item: OverlayItem) -> AnyTransition {
    guard !reduceMotion else { return .opacity }
    switch item.surface {
    case .toast(let edge, _, _):
      return .move(edge: swiftUIEdge(for: edge)).combined(with: .opacity)
    case .drawer(let edge, _):
      return .move(edge: swiftUIEdge(for: edge)).combined(with: .opacity)
    case nil:
      return .opacity.combined(with: .scale(scale: 0.98))
    }
  }

  private func swiftUIEdge(for edge: OverlayEdge) -> Edge {
    switch edge {
    case .top: .top
    case .bottom: .bottom
    case .leading: .leading
    case .trailing: .trailing
    }
  }

  private func swiftUIEdge(for edge: DrawerEdge) -> Edge {
    switch edge {
    case .bottom: .bottom
    case .leading: .leading
    case .trailing: .trailing
    }
  }

  private enum DismissRequestSource {
    case backdrop
    case escape
  }
}

// MARK: - OverlayElement

/// Renders a single overlay, reads its measured size, and computes its final position.
///
/// Interactive overlays are restricted to the top modal item, while toast
/// content remains independently hit-testable in its non-modal lane.
private struct OverlayElement: View {
  @FocusState private var isFocused: Bool
  @AccessibilityFocusState private var isAccessibilityFocused: Bool
  let item: OverlayItem
  let proxy: GeometryProxy
  let containerFrame: CGRect
  let isTopInteractive: Bool
  let isVisibleInToastLane: Bool
  let layoutDirection: LayoutDirection
  let configuration: OverlayConfiguration
  let toastStack: [ToastLayoutEntry]
  let onDismissRequest: () -> Void

  // MARK: - Body
  var body: some View {
    OverlayContentLayout(
      presentation: item.presentation,
      containerSize: containerSize,
      safeAreaInsets: proxy.safeAreaInsets,
      layoutDirection: layoutDirection,
      configuration: configuration
    ) {
      item.content()
    }
    .background(OverlaySizeReader(id: item.id))
    .modifier(OverlayClippingModifier(isEnabled: item.isDrawer))
    .position(position)
    .opacity(isRendered ? 1 : 0)
    .accessibilityAddTraits(item.isToast ? [] : .isModal)
    .allowsHitTesting((item.isToast && isVisibleInToastLane) || isTopInteractive)
    .accessibilityHidden(
      (item.isToast && !isVisibleInToastLane) || (!item.isToast && !isTopInteractive)
    )
    .accessibilityFocused($isAccessibilityFocused)
    .focusable(item.isDrawer)
    .focusEffectDisabled()
    .focused($isFocused)
    .onAppear {
      if item.isDrawer, isTopInteractive {
        isFocused = true
        isAccessibilityFocused = true
      }
    }
    .onChange(of: isTopInteractive) { _, newValue in
      if newValue, item.isDrawer {
        isFocused = true
        isAccessibilityFocused = true
      } else if !newValue {
        isFocused = false
        isAccessibilityFocused = false
      }
    }
    .onKeyPress(.escape) {
      guard item.isDrawer, isTopInteractive else { return .ignored }
      onDismissRequest()
      return .handled
    }
    .accessibilityAction(.escape) {
      guard item.isDrawer, isTopInteractive else { return }
      onDismissRequest()
    }
  }

  // MARK: - Computed
  private var containerSize: CGSize { proxy.size }

  private var center: CGPoint {
    CGPoint(x: containerSize.width * 0.5, y: containerSize.height * 0.5)
  }

  private var measuredSize: CGSize? { item.size }

  private var isMeasured: Bool { measuredSize != nil }

  private var isRendered: Bool {
    isMeasured && (!item.isToast || isVisibleInToastLane)
  }

  private var renderedSize: CGSize {
    guard let measuredSize else { return .zero }
    return OverlayLayout.renderedSize(
      presentation: item.presentation,
      containerSize: containerSize,
      intrinsicSize: measuredSize,
      safeAreaInsets: proxy.safeAreaInsets,
      layoutDirection: layoutDirection,
      configuration: configuration
    )
  }

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
    guard isMeasured else { return center }
    return OverlayLayout.position(
      id: item.id,
      presentation: item.presentation,
      containerSize: containerSize,
      contentSize: renderedSize,
      anchorRect: anchorRect,
      safeAreaInsets: proxy.safeAreaInsets,
      layoutDirection: layoutDirection,
      configuration: configuration,
      toastStack: toastStack
    )
  }
}

/// Drawers are host-constrained surfaces, but legacy and toast content may
/// intentionally render effects such as shadows beyond their measured bounds.
private struct OverlayClippingModifier: ViewModifier {
  let isEnabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if isEnabled {
      content.clipped()
    } else {
      content
    }
  }
}

// MARK: - OverlayContentLayout

/// Measures intrinsic content, resolves the semantic surface size, then gives
/// flexible drawer content the final host-constrained proposal.
private struct OverlayContentLayout: Layout {
  let presentation: OverlayPresentation
  let containerSize: CGSize
  let safeAreaInsets: EdgeInsets
  let layoutDirection: LayoutDirection
  let configuration: OverlayConfiguration

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    guard let subview = subviews.first else { return .zero }
    let intrinsicSize = subview.sizeThatFits(.unspecified)
    return OverlayLayout.renderedSize(
      presentation: presentation,
      containerSize: containerSize,
      intrinsicSize: intrinsicSize,
      safeAreaInsets: safeAreaInsets,
      layoutDirection: layoutDirection,
      configuration: configuration
    )
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    guard let subview = subviews.first else { return }
    subview.place(
      at: bounds.origin,
      anchor: .topLeading,
      proposal: ProposedViewSize(bounds.size)
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
