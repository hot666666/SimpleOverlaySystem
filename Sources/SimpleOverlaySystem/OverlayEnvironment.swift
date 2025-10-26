//
//  OverlayEnvironment.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - Overlay EnvironmentValues

extension EnvironmentValues {
	/// Shared overlay manager that drives presentation state across the tree.
	@Entry public var overlayManager = OverlayManager()
}
