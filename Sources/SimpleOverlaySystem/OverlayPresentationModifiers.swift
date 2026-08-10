import SwiftUI

// MARK: - Binding Presentation API

public extension View {
  /// Presents centered content while `isPresented` is true.
  ///
  /// Apply this modifier to a descendant of ``OverlayContainer``. Setting the
  /// Binding to `true` presents one overlay with a stable identity. A backdrop
  /// dismissal or ``OverlayDismissAction`` writes `false` back to the Binding.
  ///
  /// - Parameters:
  ///   - isPresented: The source of truth for presentation.
  ///   - dismissPolicy: Whether a backdrop tap dismisses the overlay.
  ///   - barrier: Whether the overlay blocks interaction with content below it.
  ///   - backdropOpacity: The black backdrop opacity, typically from `0` to `1`.
  ///   - offset: An offset from the center of the overlay container.
  ///   - onDismiss: Called after the presentation becomes inactive.
  ///   - content: The content presented by the shared overlay host.
  func overlayCentered<OverlayContent: View>(
    isPresented: Binding<Bool>,
    dismissPolicy: DismissPolicy = .tap,
    barrier: OverlayInteractionBarrier = .blockAll,
    backdropOpacity: Double = 0.35,
    offset: CGPoint = .zero,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> OverlayContent
  ) -> some View {
    modifier(
      BooleanOverlayPresentationModifier(
        isPresented: isPresented,
        style: .centered(
          dismissPolicy: dismissPolicy,
          barrier: barrier,
          backdropOpacity: backdropOpacity,
          offset: offset
        ),
        onDismiss: onDismiss,
        overlayContent: content
      )
    )
  }

  /// Presents centered content for the current non-nil item.
  ///
  /// The Binding owns the lifecycle: a non-nil value presents or updates the
  /// content, and host-initiated dismissal writes `nil` back. Replacing one
  /// non-nil item with another updates the existing presentation in place.
  ///
  /// - Parameters:
  ///   - item: The optional identifiable value that owns presentation.
  ///   - dismissPolicy: Whether a backdrop tap dismisses the overlay.
  ///   - barrier: Whether the overlay blocks interaction with content below it.
  ///   - backdropOpacity: The black backdrop opacity, typically from `0` to `1`.
  ///   - offset: An offset from the center of the overlay container.
  ///   - onDismiss: Called after the item becomes `nil` and the presentation closes.
  ///   - content: Builds overlay content from the current item.
  func overlayCentered<Item: Identifiable, OverlayContent: View>(
    item: Binding<Item?>,
    dismissPolicy: DismissPolicy = .tap,
    barrier: OverlayInteractionBarrier = .blockAll,
    backdropOpacity: Double = 0.35,
    offset: CGPoint = .zero,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Item) -> OverlayContent
  ) -> some View {
    modifier(
      ItemOverlayPresentationModifier(
        item: item,
        style: .centered(
          dismissPolicy: dismissPolicy,
          barrier: barrier,
          backdropOpacity: backdropOpacity,
          offset: offset
        ),
        onDismiss: onDismiss,
        overlayContent: content
      )
    )
  }

  /// Presents content relative to this view while `isPresented` is true.
  ///
  /// The modified view is the anchor. Its frame is observed in the nearest
  /// ``OverlayContainer`` coordinate space, so the overlay follows layout and
  /// window-size changes without exposing coordinates to the caller.
  ///
  /// - Parameters:
  ///   - isPresented: The source of truth for presentation.
  ///   - placement: The vertical side and horizontal alignment around the anchor.
  ///   - dismissPolicy: Whether a backdrop tap dismisses the overlay.
  ///   - barrier: Whether the overlay blocks interaction with content below it.
  ///   - backdropOpacity: The black backdrop opacity, typically from `0` to `1`.
  ///   - onDismiss: Called after the presentation becomes inactive.
  ///   - content: The content presented relative to the modified view.
  func overlayAnchored<OverlayContent: View>(
    isPresented: Binding<Bool>,
    placement: OverlayPlacement,
    dismissPolicy: DismissPolicy = .tap,
    barrier: OverlayInteractionBarrier = .blockAll,
    backdropOpacity: Double = 0.35,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> OverlayContent
  ) -> some View {
    modifier(
      BooleanOverlayPresentationModifier(
        isPresented: isPresented,
        style: .anchored(
          placement: placement,
          dismissPolicy: dismissPolicy,
          barrier: barrier,
          backdropOpacity: backdropOpacity
        ),
        onDismiss: onDismiss,
        overlayContent: content
      )
    )
  }

  /// Presents item content relative to this view while the item is non-nil.
  ///
  /// The modified view supplies the anchor and the Binding supplies the
  /// lifecycle. Host-initiated dismissal writes `nil` back to `item`.
  ///
  /// - Parameters:
  ///   - item: The optional identifiable value that owns presentation.
  ///   - placement: The vertical side and horizontal alignment around the anchor.
  ///   - dismissPolicy: Whether a backdrop tap dismisses the overlay.
  ///   - barrier: Whether the overlay blocks interaction with content below it.
  ///   - backdropOpacity: The black backdrop opacity, typically from `0` to `1`.
  ///   - onDismiss: Called after the item becomes `nil` and the presentation closes.
  ///   - content: Builds overlay content from the current item.
  func overlayAnchored<Item: Identifiable, OverlayContent: View>(
    item: Binding<Item?>,
    placement: OverlayPlacement,
    dismissPolicy: DismissPolicy = .tap,
    barrier: OverlayInteractionBarrier = .blockAll,
    backdropOpacity: Double = 0.35,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Item) -> OverlayContent
  ) -> some View {
    modifier(
      ItemOverlayPresentationModifier(
        item: item,
        style: .anchored(
          placement: placement,
          dismissPolicy: dismissPolicy,
          barrier: barrier,
          backdropOpacity: backdropOpacity
        ),
        onDismiss: onDismiss,
        overlayContent: content
      )
    )
  }

  /// Presents a semantic toast while `isPresented` is true.
  ///
  /// Toasts are non-modal: their content remains interactive, while space
  /// outside the toast passes through to underlying content. Automatic expiry
  /// writes `false` back to the Binding. Lane padding, spacing, and capacity
  /// come from ``OverlayConfiguration``.
  ///
  /// - Parameters:
  ///   - isPresented: The source of truth for presentation.
  ///   - edge: The container edge from which the toast stacks inward.
  ///   - alignment: Alignment along that edge. The default is ``EdgeAlignment/end``.
  ///   - duration: The toast lifetime. The default is ``ToastDuration/automatic``.
  ///   - onDismiss: Called after manual or automatic dismissal.
  ///   - content: The toast content.
  func overlayToast<OverlayContent: View>(
    isPresented: Binding<Bool>,
    edge: OverlayEdge,
    alignment: EdgeAlignment = .end,
    duration: ToastDuration = .automatic,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> OverlayContent
  ) -> some View {
    modifier(
      BooleanOverlayPresentationModifier(
        isPresented: isPresented,
        style: .surface(.toast(edge: edge, alignment: alignment, duration: duration)),
        onDismiss: onDismiss,
        overlayContent: content
      )
    )
  }

  /// Presents a semantic toast for the current non-nil item.
  ///
  /// Automatic expiry writes `nil` back to `item`. Replacing the current item
  /// represents a new notification and restarts the toast lifetime, while the
  /// host keeps the Binding-owned presentation identity stable.
  ///
  /// - Parameters:
  ///   - item: The optional identifiable notification value.
  ///   - edge: The container edge from which the toast stacks inward.
  ///   - alignment: Alignment along that edge. The default is ``EdgeAlignment/end``.
  ///   - duration: The toast lifetime. The default is ``ToastDuration/automatic``.
  ///   - onDismiss: Called after the item becomes `nil` and the toast closes.
  ///   - content: Builds toast content from the current item.
  func overlayToast<Item: Identifiable, OverlayContent: View>(
    item: Binding<Item?>,
    edge: OverlayEdge,
    alignment: EdgeAlignment = .end,
    duration: ToastDuration = .automatic,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Item) -> OverlayContent
  ) -> some View {
    modifier(
      ItemOverlayPresentationModifier(
        item: item,
        style: .surface(.toast(edge: edge, alignment: alignment, duration: duration)),
        onDismiss: onDismiss,
        overlayContent: content
      )
    )
  }

  /// Presents a semantic drawer while `isPresented` is true.
  ///
  /// A drawer is modal within the existing ``OverlayContainer`` bounds. It
  /// derives its backdrop, transition, focus, hit testing, Escape handling, and
  /// accessibility dismissal behavior from its semantic edge. Use
  /// ``/SimpleOverlaySystem/SwiftUICore/View/onOverlayDismissRequest(perform:)``
  /// to validate a user dismissal.
  ///
  /// - Parameters:
  ///   - isPresented: The source of truth for presentation.
  ///   - edge: The edge from which the drawer enters.
  ///   - extent: Its width for horizontal edges or height for the bottom edge.
  ///   - onDismiss: Called after the presentation becomes inactive.
  ///   - content: The drawer content.
  func overlayDrawer<OverlayContent: View>(
    isPresented: Binding<Bool>,
    edge: DrawerEdge,
    extent: DrawerExtent = .inspector,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> OverlayContent
  ) -> some View {
    modifier(
      BooleanOverlayPresentationModifier(
        isPresented: isPresented,
        style: .surface(.drawer(edge: edge, extent: extent)),
        onDismiss: onDismiss,
        overlayContent: content
      )
    )
  }

  /// Presents a semantic drawer for the current non-nil item.
  ///
  /// Changing from one non-nil item to another updates the content in place;
  /// the drawer does not dismiss and re-enter. Backdrop, Escape, and
  /// accessibility dismissal write `nil` back to `item`.
  ///
  /// - Parameters:
  ///   - item: The optional identifiable value displayed by the drawer.
  ///   - edge: The edge from which the drawer enters.
  ///   - extent: Its width for horizontal edges or height for the bottom edge.
  ///   - onDismiss: Called after the item becomes `nil` and the drawer closes.
  ///   - content: Builds drawer content from the current item.
  func overlayDrawer<Item: Identifiable, OverlayContent: View>(
    item: Binding<Item?>,
    edge: DrawerEdge,
    extent: DrawerExtent = .inspector,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Item) -> OverlayContent
  ) -> some View {
    modifier(
      ItemOverlayPresentationModifier(
        item: item,
        style: .surface(.drawer(edge: edge, extent: extent)),
        onDismiss: onDismiss,
        overlayContent: content
      )
    )
  }
}

// MARK: - Internal Binding Adapters

private enum BindingOverlayStyle: Equatable {
  case centered(
    dismissPolicy: DismissPolicy,
    barrier: OverlayInteractionBarrier,
    backdropOpacity: Double,
    offset: CGPoint
  )
  case anchored(
    placement: OverlayPlacement,
    dismissPolicy: DismissPolicy,
    barrier: OverlayInteractionBarrier,
    backdropOpacity: Double
  )
  case surface(OverlaySurface)

  var isAnchored: Bool {
    guard case .anchored = self else { return false }
    return true
  }

  /// Converts the public modifier flavor into the manager's internal request.
  /// Anchor geometry remains separate because it changes independently of style.
  var presentation: OverlayPresentation {
    switch self {
    case .centered(_, _, _, let offset):
      return .centered(offset: offset)
    case .anchored(let placement, _, _, _):
      return .anchored(placement: placement)
    case .surface(let surface):
      return .surface(surface)
    }
  }

  var dismissPolicy: DismissPolicy {
    switch self {
    case .centered(let policy, _, _, _), .anchored(_, let policy, _, _):
      return policy
    case .surface(.toast):
      return .programmatic
    case .surface(.drawer):
      return .tap
    }
  }

  var barrier: OverlayInteractionBarrier {
    switch self {
    case .centered(_, let barrier, _, _), .anchored(_, _, let barrier, _):
      return barrier
    case .surface(.toast):
      return .passthrough
    case .surface(.drawer):
      return .blockAll
    }
  }

  var backdropOpacity: Double {
    switch self {
    case .centered(_, _, let opacity, _), .anchored(_, _, _, let opacity):
      return opacity
    case .surface(.toast):
      return 0
    case .surface(.drawer):
      // The manager replaces this value with its configured semantic default.
      return 0
    }
  }
}

private struct BooleanOverlayPresentationModifier<OverlayContent: View>: ViewModifier {
  @Environment(\.overlayManager) private var manager
  // The modifier can be recreated as its source view updates. State keeps the
  // manager request stable so content changes do not replay its transition.
  @State private var overlayID = OverlayID()
  @State private var anchorFrame: CGRect?

  let isPresented: Binding<Bool>
  let style: BindingOverlayStyle
  let onDismiss: (() -> Void)?
  let overlayContent: () -> OverlayContent

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: CGRect.self) { proxy in
        proxy.frame(in: .named(OverlaySpace.name))
      } action: { newFrame in
        guard style.isAnchored else { return }
        anchorFrame = newFrame
        synchronizeIfPresented()
      }
      .onAppear { synchronizeIfPresented() }
      .onChange(of: isPresented.wrappedValue) { oldValue, newValue in
        if newValue {
          synchronizeIfPresented()
        } else {
          manager?.removeBindingPresentation(id: overlayID)
          if oldValue { onDismiss?() }
        }
      }
      .onChange(of: style) { _, _ in synchronizeIfPresented() }
      .onDisappear {
        manager?.removeBindingPresentation(id: overlayID)
        if isPresented.wrappedValue {
          isPresented.wrappedValue = false
          onDismiss?()
        }
      }
  }

  private func synchronizeIfPresented() {
    guard isPresented.wrappedValue, let manager else { return }
    manager.synchronizeBindingPresentation(
      id: overlayID,
      presentation: style.presentation,
      dismissPolicy: style.dismissPolicy,
      barrier: style.barrier,
      backdropOpacity: style.backdropOpacity,
      anchorFrame: style.isAnchored ? anchorFrame : nil,
      content: { AnyView(overlayContent()) },
      onDismiss: { isPresented.wrappedValue = false }
    )
  }
}

private struct ItemOverlayPresentationModifier<Item: Identifiable, OverlayContent: View>: ViewModifier {
  @Environment(\.overlayManager) private var manager
  // Surface identity belongs to the modifier, not the current domain item.
  // This is what lets drawers update A -> B without a slide-out/slide-in cycle.
  @State private var overlayID = OverlayID()
  @State private var anchorFrame: CGRect?

  let item: Binding<Item?>
  let style: BindingOverlayStyle
  let onDismiss: (() -> Void)?
  let overlayContent: (Item) -> OverlayContent

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: CGRect.self) { proxy in
        proxy.frame(in: .named(OverlaySpace.name))
      } action: { newFrame in
        guard style.isAnchored else { return }
        anchorFrame = newFrame
        synchronizeIfPresented()
      }
      .onAppear { synchronizeIfPresented() }
      .onChange(of: item.wrappedValue?.id) { oldID, newID in
        if newID != nil {
          synchronizeIfPresented()
        } else {
          manager?.removeBindingPresentation(id: overlayID)
          if oldID != nil { onDismiss?() }
        }
      }
      .onChange(of: style) { _, _ in synchronizeIfPresented() }
      .onDisappear {
        manager?.removeBindingPresentation(id: overlayID)
        if item.wrappedValue != nil {
          item.wrappedValue = nil
          onDismiss?()
        }
      }
  }

  private func synchronizeIfPresented() {
    guard item.wrappedValue != nil, let manager else { return }
    manager.synchronizeBindingPresentation(
      id: overlayID,
      presentation: style.presentation,
      dismissPolicy: style.dismissPolicy,
      barrier: style.barrier,
      backdropOpacity: style.backdropOpacity,
      anchorFrame: style.isAnchored ? anchorFrame : nil,
      content: {
        guard let currentItem = item.wrappedValue else { return AnyView(EmptyView()) }
        return AnyView(overlayContent(currentItem))
      },
      onDismiss: { item.wrappedValue = nil }
    )
  }
}
