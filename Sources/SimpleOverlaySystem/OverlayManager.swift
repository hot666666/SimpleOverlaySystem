//
//  OverlayManager.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - Overlay Manager

/// Observable store that drives overlay presentation and dismissal for a view hierarchy.
@MainActor
@Observable
public final class OverlayManager {
  /// Backing stack that preserves presentation order (last-in, first-out).
  private(set) var stack: [OverlayItem] = []

  public init() {}

  /// Convenience accessor for the visible overlay.
  var top: OverlayItem? { stack.last }

  /// Convenience accessor for the stack.isEmpty
  public var isEmpty: Bool { stack.isEmpty }

  /// Presents a centered overlay.
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
      anchorFrame: nil,
      size: nil
    )
    push(item)
    return resolvedId
  }

  /// Presents an overlay relative to a captured anchor frame and placement.
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
      anchorFrame: anchorFrame,
      size: nil
    )
    push(item)
    return resolvedId
  }

  /// Removes the most recently presented overlay.
  public func dismissTop() {
    _ = stack.popLast()
  }

  /// Removes the overlay with the specified identifier.
  /// - Parameter id: The ``OverlayID`` of the overlay to remove.
  public func dismiss(id: OverlayID) {
    stack.removeAll(where: { $0.id == id })
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
    stack.removeAll { $0.identifierKey == key }
  }
}
