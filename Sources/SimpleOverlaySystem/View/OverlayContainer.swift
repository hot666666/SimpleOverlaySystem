//
//  OverlayContainer.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - Overlay Container

/// Wraps content with a private `OverlayManager` and mounts the overlay host in one place.
public struct OverlayContainer<Content: View>: View {
	@State private var manager = OverlayManager()
	private let content: () -> Content

	/// Creates a container that injects its own manager so descendants can read `overlayManager`.
	public init(@ViewBuilder content: @escaping () -> Content) {
		self.content = content
	}

	public var body: some View {
		content()
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.modifier(OverlayHost())
			.environment(\.overlayManager, manager)
	}
}
