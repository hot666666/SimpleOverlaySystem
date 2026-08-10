//
//  OverlayDismissHandlerModifier.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - OverlayDismissHandlerModifier

public extension View {
  /// Registers a custom action to perform when the overlay's background is tapped.
  ///
  /// Use this modifier within an overlay view to intercept background tap gestures and provide
  /// custom handling logic. This is particularly useful when you need to show confirmation dialogs,
  /// validate state, or perform cleanup before dismissing an overlay.
  ///
  /// ## Overview
  /// When applied within an overlay view, this modifier overrides the default
  /// backdrop action. The overlay must use ``OverlayInteractionBarrier/blockAll``
  /// so the backdrop can receive the tap. The custom handler takes precedence
  /// over the overlay's static ``DismissPolicy``.
  ///
  /// ## Usage
  /// ```swift
  /// struct MyOverlay: View {
  ///     @Environment(\.dismissOverlay) private var dismissOverlay
  ///     @State private var hasUnsavedChanges = false
  ///
  ///     var body: some View {
  ///         VStack {
  ///             Toggle("Unsaved Changes", isOn: $hasUnsavedChanges)
  ///         }
  ///         .onTapBackground {
  ///             if hasUnsavedChanges {
  ///                 // Show confirmation dialog
  ///                 // Present app-specific confirmation UI.
  ///             } else {
  ///                 dismissOverlay()
  ///             }
  ///         }
  ///     }
  /// }
  /// ```
  ///
  /// - Important: This modifier must be used within a view that is presented as an overlay
  ///   via ``OverlayManager``. It has no effect when used outside of an overlay context.
  ///
  /// - Parameter action: A closure executed when the blocking backdrop is tapped.
  ///
  /// - Returns: A view that registers a custom background tap handler for overlay dismissal.
  func onTapBackground(
    perform action: @escaping @MainActor @Sendable () -> Void
  ) -> some View {
    modifier(OverlayDismissHandlerModifier(action: action))
  }

  /// Intercepts a user-initiated request to dismiss the current overlay.
  ///
  /// Drawers route backdrop taps, Escape, and the accessibility escape action
  /// through this single callback. When a callback is installed, automatic
  /// dismissal is suppressed; call ``OverlayDismissAction`` from the
  /// `dismissOverlay` environment value after validation or confirmation to
  /// complete the dismissal. The modifier has no effect outside hosted overlay
  /// content.
  ///
  /// - Parameter action: The validation or interception action for a user
  ///   dismissal request.
  func onOverlayDismissRequest(
    perform action: @escaping @MainActor @Sendable () -> Void
  ) -> some View {
    modifier(OverlayDismissRequestHandlerModifier(action: action))
  }
}

/// A view modifier that registers a custom dismiss handler via SwiftUI's preference system.
///
/// This modifier uses ``OverlayDismissHandlerPreferenceKey`` to bubble up the dismiss handler
/// from the overlay view to the ``OverlayHost``, which collects all handlers and invokes the
/// appropriate one when a background tap occurs.
///
/// The modifier reads the current ``EnvironmentValues/overlayID`` to associate the handler
/// with the specific overlay it belongs to, ensuring correct handler execution even when
/// multiple overlays are stacked.
private struct OverlayDismissHandlerModifier: ViewModifier {
  @Environment(\.overlayID) private var overlayID
  @State private var actionBox = DismissHandlerActionBox()
  let action: @MainActor @Sendable () -> Void

  func body(content: Content) -> some View {
    actionBox.update(action)
    return
      content
      .preference(
        key: OverlayDismissHandlerPreferenceKey.self,
        value: preferenceValue
      )
  }

  /// Computes the preference value to emit.
  ///
  /// Returns a dictionary mapping the current overlay's ID to its dismiss handler.
  /// If no overlay ID is available (e.g., not in an overlay context), returns an empty dictionary.
  private var preferenceValue: [OverlayID: DismissHandler] {
    guard let overlayID else { return [:] }
    return [overlayID: DismissHandler(id: overlayID, actionBox: actionBox)]
  }
}

/// A separate preference channel for semantic dismissal requests. The legacy
/// backdrop-only callback remains source-compatible and keeps its old meaning.
struct OverlayDismissRequestHandlerPreferenceKey: PreferenceKey {
  static let defaultValue: [OverlayID: DismissHandler] = [:]

  static func reduce(
    value: inout [OverlayID: DismissHandler],
    nextValue: () -> [OverlayID: DismissHandler]
  ) {
    value.merge(nextValue()) { _, new in new }
  }
}

private struct OverlayDismissRequestHandlerModifier: ViewModifier {
  @Environment(\.overlayID) private var overlayID
  @State private var actionBox = DismissHandlerActionBox()
  let action: @MainActor @Sendable () -> Void

  func body(content: Content) -> some View {
    actionBox.update(action)
    return content.preference(
      key: OverlayDismissRequestHandlerPreferenceKey.self,
      value: preferenceValue
    )
  }

  private var preferenceValue: [OverlayID: DismissHandler] {
    guard let overlayID else { return [:] }
    return [overlayID: DismissHandler(id: overlayID, actionBox: actionBox)]
  }
}
