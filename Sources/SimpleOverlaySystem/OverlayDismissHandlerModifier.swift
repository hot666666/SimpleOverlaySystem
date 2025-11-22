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
  /// When applied within an overlay view, this modifier overrides the default tap-to-dismiss behavior
  /// specified by ``DismissPolicy/tap``. The custom handler is invoked instead of the default dismissal,
  /// giving you full control over the dismissal flow.
  ///
  /// ## Usage
  /// ```swift
  /// struct MyOverlay: View {
  ///     @Environment(\.overlayManager) var manager
  ///     @State private var hasUnsavedChanges = false
  ///
  ///     var body: some View {
  ///         VStack {
  ///             Toggle("Unsaved Changes", isOn: $hasUnsavedChanges)
  ///         }
  ///         .onTapBackground {
  ///             if hasUnsavedChanges {
  ///                 // Show confirmation dialog
  ///                 manager?.presentCentered {
  ///                     Text("Discard changes?")
  ///                 }
  ///             } else {
  ///                 manager?.dismissTop()
  ///             }
  ///         }
  ///     }
  /// }
  /// ```
  ///
  /// - Important: This modifier must be used within a view that is presented as an overlay
  ///   via ``OverlayManager``. It has no effect when used outside of an overlay context.
  ///
  /// - Parameter action: A closure executed when the overlay's background is tapped.
  ///   This action is only invoked if the overlay's ``DismissPolicy`` is set to ``DismissPolicy/tap``.
  ///
  /// - Returns: A view that registers a custom background tap handler for overlay dismissal.
  func onTapBackground(perform action: @escaping @Sendable () -> Void) -> some View {
    modifier(OverlayDismissHandlerModifier(action: action))
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
  let action: @Sendable () -> Void

  func body(content: Content) -> some View {
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
    return [overlayID: DismissHandler(id: overlayID, action: action)]
  }
}
