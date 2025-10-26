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
}
