//
//  OverlayContainer.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - Overlay Container

/// Wraps content with a private `OverlayManager` and mounts the overlay host in one place.
/// The manager is injected into the environment as an optional to avoid creating it
/// outside the main actor (important for Swift 6's stricter concurrency checks).
///
/// Install one container above every view that presents overlays. The container
/// fills its proposed bounds; drawers use those bounds and never resize the
/// platform window.
public struct OverlayContainer<Content: View>: View {
  @State private var manager: OverlayManager
  private let content: () -> Content

  /// Creates a container and injects its manager into descendant views.
  ///
  /// - Parameters:
  ///   - configuration: Host-wide Toast and Drawer policy.
  ///   - content: The view hierarchy that can present overlays.
  public init(
    configuration: OverlayConfiguration = .default,
    @ViewBuilder content: @escaping () -> Content
  ) {
    _manager = State(initialValue: OverlayManager(configuration: configuration))
    self.content = content
  }

  public var body: some View {
    content()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .modifier(OverlayHost())
      .environment(\.overlayManager, manager)
  }
}
