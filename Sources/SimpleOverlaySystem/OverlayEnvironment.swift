//
//  OverlayEnvironment.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

/// An environment action that dismisses the overlay containing the caller.
///
/// This mirrors SwiftUI's `dismiss` action while targeting the package's own
/// presentation host. Read it from content presented by ``OverlayManager`` or
/// a Binding modifier. Calling it outside hosted overlay content has no effect.
public struct OverlayDismissAction: Sendable {
  private let action: @MainActor @Sendable () -> Void

  init(action: @escaping @MainActor @Sendable () -> Void = {}) {
    self.action = action
  }

  @MainActor
  public func callAsFunction() {
    action()
  }
}

// MARK: - Overlay EnvironmentValues

public extension EnvironmentValues {
  /// The manager injected by the nearest ``OverlayContainer``.
  ///
  /// The value is optional because views can exist outside a configured overlay
  /// hierarchy. Event-driven call sites should unwrap it before presenting.
  @Entry var overlayManager: OverlayManager?

  /// The unique identifier of the current overlay (if any).
  ///
  /// This value is automatically injected by the internal `OverlayHost` into each overlay's view hierarchy
  /// when it is rendered. It allows overlay views to identify themselves when registering custom
  /// dismiss handlers via ``View/onTapBackground(perform:)``.
  ///
  /// ## Availability
  /// This environment value is only available within views presented as overlays through
  /// ``OverlayManager``. Outside of an overlay context, this value is `nil`.
  ///
  /// ## Usage
  /// You typically don't need to access this value directly. It's used internally by the
  /// ``View/onTapBackground(perform:)`` modifier to associate dismiss handlers with their
  /// respective overlays.
  @Entry var overlayID: OverlayID?

  /// Dismisses the overlay that contains the current view.
  ///
  /// For Binding-owned presentations, dismissal also writes `false` or `nil`
  /// back to the source Binding.
  @Entry var dismissOverlay = OverlayDismissAction()
}
