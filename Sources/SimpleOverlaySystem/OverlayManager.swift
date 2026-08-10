//
//  OverlayManager.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - Overlay Manager

/// Observable store that drives overlay presentation and dismissal for a view hierarchy.
///
/// Most views read the manager through `@Environment(\.overlayManager)` after
/// installing ``OverlayContainer``. Manager methods are suited to event-driven
/// presentation; use the Binding modifiers when view state owns the lifecycle.
@MainActor
@Observable
public final class OverlayManager {
  /// Backing stack that preserves presentation order (last-in, first-out).
  private(set) var stack: [OverlayItem] = []
  private var automaticDismissTasks: [OverlayID: Task<Void, Never>] = [:]

  let configuration: OverlayConfiguration

  /// Creates a manager with one host-wide semantic surface policy.
  ///
  /// - Parameter configuration: Toast lane and Drawer backdrop configuration.
  public init(configuration: OverlayConfiguration = .default) {
    self.configuration = configuration
  }

  /// Convenience accessor for the visible overlay.
  var top: OverlayItem? { stack.last }

  /// Whether the manager currently contains no centered, anchored, Toast, or
  /// Drawer presentations.
  public var isEmpty: Bool { stack.isEmpty }

  /// Presents a centered overlay.
  ///
  /// Use this method for event-driven presentation. When SwiftUI state owns the
  /// lifecycle, prefer
  /// ``/SimpleOverlaySystem/SwiftUICore/View/overlayCentered(isPresented:dismissPolicy:barrier:backdropOpacity:offset:onDismiss:content:)``.
  ///
  /// - Parameters:
  ///   - id: The identifier controlling uniqueness. Defaults to `.auto`.
  ///   - dismissPolicy: The policy defining how the overlay can be dismissed. Defaults to `.tap`.
  ///   - barrier: Whether interactions should be blocked or pass through. Defaults to `.blockAll`.
  ///   - backdropOpacity: Scrim opacity behind the overlay. Defaults to `0.35`.
  ///   - offset: A custom offset from the center of the screen.
  ///   - content: The overlay view to render.
  /// - Returns: The identifier of the newly presented overlay, or `nil` if ignored due to duplicate.
  @discardableResult
  public func presentCentered(
    id: OverlayIdentifier = .auto,
    dismissPolicy: DismissPolicy = .tap,
    barrier: OverlayInteractionBarrier = .blockAll,
    backdropOpacity: Double = 0.35,
    offset: CGPoint = .zero,
    @ViewBuilder content: @escaping () -> some View
  ) -> OverlayID? {
    guard let resolvedId = resolveIdentifier(id) else { return nil }
    let builder = content
    let item = OverlayItem(
      id: resolvedId,
      identifierKey: id.namedKey,
      presentation: .centered(offset: offset),
      dismissPolicy: dismissPolicy,
      barrier: barrier,
      backdropOpacity: backdropOpacity,
      content: { AnyView(builder()) },
      onDismiss: nil,
      anchorFrame: nil,
      size: nil
    )
    push(item)
    return resolvedId
  }

  /// Presents an overlay relative to a captured anchor frame and placement.
  ///
  /// `anchorFrame` must use the coordinate space established by the nearest
  /// ``OverlayContainer``. ``AnchoredOverlayButton`` and the Binding-based
  /// anchored modifiers capture and update this geometry automatically.
  ///
  /// - Parameters:
  ///   - id: The identifier controlling uniqueness. Defaults to `.auto`.
  ///   - anchorFrame: The source view's frame in the container's coordinate space.
  ///   - placement: Whether to show above or below, and how to align horizontally.
  ///   - dismissPolicy: The policy defining how the overlay can be dismissed. Defaults to `.tap`.
  ///   - barrier: Whether interactions should be blocked or pass through. Defaults to `.blockAll`.
  ///   - backdropOpacity: Scrim opacity behind the overlay. Defaults to `0.35`.
  ///   - content: The overlay view to render.
  /// - Returns: The identifier of the newly presented overlay, or `nil` if ignored due to duplicate.
  @discardableResult
  public func presentAnchored(
    id: OverlayIdentifier = .auto,
    anchorFrame: CGRect?,
    placement: OverlayPlacement,
    dismissPolicy: DismissPolicy = .tap,
    barrier: OverlayInteractionBarrier = .blockAll,
    backdropOpacity: Double = 0.35,
    @ViewBuilder content: @escaping () -> some View
  ) -> OverlayID? {
    guard let resolvedId = resolveIdentifier(id) else { return nil }
    let builder = content
    let item = OverlayItem(
      id: resolvedId,
      identifierKey: id.namedKey,
      presentation: .anchored(placement: placement),
      dismissPolicy: dismissPolicy,
      barrier: barrier,
      backdropOpacity: backdropOpacity,
      content: { AnyView(builder()) },
      onDismiss: nil,
      anchorFrame: anchorFrame,
      size: nil
    )
    push(item)
    return resolvedId
  }

  /// Presents a semantic toast or drawer surface.
  ///
  /// Unlike the legacy centered and anchored APIs, a semantic surface owns its
  /// interaction policy. Callers do not provide raw barriers, backdrop values,
  /// offsets, focus rules, or transitions. Use this API for event-driven
  /// presentation; use the Binding modifiers when SwiftUI state owns the
  /// lifecycle.
  ///
  /// - Parameters:
  ///   - surface: The semantic surface and its caller-selectable options.
  ///   - id: Duplicate and replacement behavior. The default allows duplicates.
  ///   - content: The view rendered by the shared overlay host.
  /// - Returns: The concrete ID used for dismissal, or `nil` when a `.unique`
  ///   presentation is already active.
  @discardableResult
  public func present(
    _ surface: OverlaySurface,
    id: OverlayIdentifier = .auto,
    @ViewBuilder content: @escaping () -> some View
  ) -> OverlayID? {
    guard let resolvedID = resolveIdentifier(id) else { return nil }
    let builder = content
    let item = makeSurfaceItem(
      id: resolvedID,
      identifierKey: id.namedKey,
      surface: surface,
      content: { AnyView(builder()) },
      onDismiss: nil
    )
    push(item)
    return resolvedID
  }

  /// Removes the most recently presented interactive overlay.
  ///
  /// Toasts use independent non-modal lanes, so a toast presented above a
  /// drawer does not prevent this method from dismissing the drawer. If only
  /// toasts remain, the newest toast is removed.
  public func dismissTop() {
    guard let id = stack.last(where: { !$0.isToast })?.id ?? stack.last?.id else { return }
    dismiss(id: id)
  }

  /// Removes the overlay with the specified identifier.
  /// - Parameter id: The ``OverlayID`` of the overlay to remove.
  public func dismiss(id: OverlayID) {
    remove(where: { $0.id == id }, notifyOwner: true)
  }

  /// Removes every overlay to guarantee a clean slate.
  public func dismissAll() {
    guard !stack.isEmpty else { return }
    remove(where: { _ in true }, notifyOwner: true)
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
    enforceToastLimitIfNeeded(for: item)
    scheduleAutomaticDismissIfNeeded(for: item)
  }

  /// Inserts or updates a Binding-owned presentation without changing its
  /// stable identity or presentation order.
  func synchronizeBindingPresentation(
    id: OverlayID,
    presentation: OverlayPresentation,
    dismissPolicy: DismissPolicy,
    barrier: OverlayInteractionBarrier,
    backdropOpacity: Double,
    anchorFrame: CGRect?,
    content: @escaping () -> AnyView,
    onDismiss: @escaping @MainActor () -> Void
  ) {
    let item: OverlayItem
    if case .surface(let surface) = presentation {
      item = makeSurfaceItem(
        id: id,
        identifierKey: nil,
        surface: surface,
        content: content,
        onDismiss: onDismiss
      )
    } else {
      item = OverlayItem(
        id: id,
        identifierKey: nil,
        presentation: presentation,
        dismissPolicy: dismissPolicy,
        barrier: barrier,
        backdropOpacity: backdropOpacity,
        content: content,
        onDismiss: onDismiss,
        anchorFrame: anchorFrame,
        size: nil
      )
    }

    if let index = stack.firstIndex(where: { $0.id == id }) {
      let previousSize = stack[index].size
      stack[index] = item
      stack[index].size = previousSize
      automaticDismissTasks[id]?.cancel()
      automaticDismissTasks[id] = nil
      scheduleAutomaticDismissIfNeeded(for: item)
    } else {
      push(item)
    }
  }

  /// Removes a Binding-owned presentation because its source state became
  /// false or nil. The owner is already up to date, so no callback is emitted.
  func removeBindingPresentation(id: OverlayID) {
    remove(where: { $0.id == id }, notifyOwner: false)
  }

  /// Removes measured Toasts that cannot fit their current host lane without
  /// overlap. Host geometry is intentionally not stored in the manager.
  func removeOverflowingToasts(ids: [OverlayID]) {
    guard !ids.isEmpty else { return }
    let overflowIDs = Set(ids)
    remove(
      where: { $0.isToast && overflowIDs.contains($0.id) },
      notifyOwner: true
    )
  }

  /// Performs in-place mutations on the overlay with the matching identifier.
  private func updateItem(_ id: OverlayID, perform: (inout OverlayItem) -> Void) {
    guard let index = stack.firstIndex(where: { $0.id == id }) else { return }
    perform(&stack[index])
  }

  /// Resolves an `OverlayIdentifier` to a concrete `OverlayID`, handling duplicate logic.
  ///
  /// - Parameter identifier: The identifier to resolve.
  /// - Returns: A valid `OverlayID` to use, or `nil` if the overlay should be ignored.
  private func resolveIdentifier(_ identifier: OverlayIdentifier) -> OverlayID? {
    switch identifier.kind {
    case .auto:
      return OverlayID()

    case .named(let key, let action):
      if contains(key: key) {
        switch action {
        case .ignore:
          return nil
        case .replace:
          dismiss(key: key)
        }
      }
      return OverlayID()
    }
  }

  private func makeSurfaceItem(
    id: OverlayID,
    identifierKey: String?,
    surface: OverlaySurface,
    content: @escaping () -> AnyView,
    onDismiss: (@MainActor () -> Void)?
  ) -> OverlayItem {
    let dismissPolicy: DismissPolicy
    let barrier: OverlayInteractionBarrier
    let backdropOpacity: Double

    switch surface {
    case .toast:
      dismissPolicy = .programmatic
      barrier = .passthrough
      backdropOpacity = 0
    case .drawer:
      dismissPolicy = .tap
      barrier = .blockAll
      backdropOpacity = configuration.drawerBackdropOpacity
    }

    return OverlayItem(
      id: id,
      identifierKey: identifierKey,
      presentation: .surface(surface),
      dismissPolicy: dismissPolicy,
      barrier: barrier,
      backdropOpacity: backdropOpacity,
      content: content,
      onDismiss: onDismiss,
      anchorFrame: nil,
      size: nil
    )
  }

  private func enforceToastLimitIfNeeded(for item: OverlayItem) {
    guard case .toast(let edge, _, _) = item.surface else { return }
    let toastIDs = stack.compactMap { candidate -> OverlayID? in
      guard case .toast(let candidateEdge, _, _) = candidate.surface,
        candidateEdge == edge
      else { return nil }
      return candidate.id
    }
    let overflowCount = toastIDs.count - configuration.maximumVisibleToastsPerEdge
    guard overflowCount > 0 else { return }
    let overflowIDs = Set(toastIDs.prefix(overflowCount))
    remove(where: { overflowIDs.contains($0.id) }, notifyOwner: true)
  }

  private func scheduleAutomaticDismissIfNeeded(for item: OverlayItem) {
    guard case .toast(_, _, let duration) = item.surface,
      let interval = duration.timeInterval
    else { return }

    let id = item.id
    automaticDismissTasks[id]?.cancel()
    automaticDismissTasks[id] = Task { [weak self] in
      try? await Task.sleep(for: .seconds(interval))
      guard !Task.isCancelled else { return }
      self?.dismiss(id: id)
    }
  }

  private func remove(
    where shouldRemove: (OverlayItem) -> Bool,
    notifyOwner: Bool
  ) {
    let removedItems = stack.filter(shouldRemove)
    guard !removedItems.isEmpty else { return }
    let removedIDs = Set(removedItems.map(\.id))
    stack.removeAll { removedIDs.contains($0.id) }
    for item in removedItems {
      automaticDismissTasks[item.id]?.cancel()
      automaticDismissTasks[item.id] = nil
      if notifyOwner {
        item.onDismiss?()
      }
    }
  }
}

// MARK: - Public Query API

extension OverlayManager {
  /// Returns whether an overlay with the specified key is currently presented.
  ///
  /// - Parameter key: The string key from a named `OverlayIdentifier`.
  /// - Returns: `true` if an overlay with that key exists in the stack.
  public func contains(key: String) -> Bool {
    stack.contains { $0.identifierKey == key }
  }

  /// Dismisses all overlays with the specified key.
  ///
  /// - Parameter key: The string key from a named `OverlayIdentifier`.
  public func dismiss(key: String) {
    remove(where: { $0.identifierKey == key }, notifyOwner: true)
  }
}
