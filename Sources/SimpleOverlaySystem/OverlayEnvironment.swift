//
//  OverlayEnvironment.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - Overlay EnvironmentValues

public extension EnvironmentValues {
  /// Shared overlay manager reference (nil until a container injects one on the main actor).
  @Entry var overlayManager: OverlayManager?

  /// The unique identifier of the current overlay (if any).
  ///
  /// This value is automatically injected by ``OverlayHost`` into each overlay's view hierarchy
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
}
