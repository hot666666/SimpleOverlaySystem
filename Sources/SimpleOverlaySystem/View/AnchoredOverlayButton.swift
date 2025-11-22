//
//  AnchoredOverlayButton.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

// MARK: - Anchored Overlay Button

/// A convenience control that captures its own geometry and presents an anchored overlay when tapped.
public struct AnchoredOverlayButton<Label: View, OverlayContent: View>: View {
  // Overlay manager is optional because it depends on an ancestor `OverlayContainer`.
  @Environment(\.overlayManager) private var overlay

  let placement: OverlayPlacement
  let dismissPolicy: DismissPolicy
  let barrier: OverlayInteractionBarrier
  let backdropOpacity: Double
  let label: () -> Label
  let content: () -> OverlayContent

  @State private var overlayID: OverlayID?
  @State private var anchorFrame: CGRect?

  /// Creates an anchored button with optional overrides for dismissal, interaction, and visuals.
  ///
  /// - Parameters:
  ///   - placement: Position relative to the button (top/bottom) and horizontal alignment.
  ///   - dismissPolicy: The policy defining how the overlay can be dismissed. Defaults to `.tap()`.
  ///   - barrier: Whether interactions should be blocked or pass through. Defaults to `.blockAll`.
  ///   - backdropOpacity: Scrim opacity behind the overlay. Defaults to `0.35`.
  ///   - label: The button label.
  ///   - content: The overlay content to present.
  public init(
    placement: OverlayPlacement,
    dismissPolicy: DismissPolicy = .tap,
    barrier: OverlayInteractionBarrier = .blockAll,
    backdropOpacity: Double = 0.35,
    @ViewBuilder label: @escaping () -> Label,
    @ViewBuilder content: @escaping () -> OverlayContent
  ) {
    self.placement = placement
    self.dismissPolicy = dismissPolicy
    self.barrier = barrier
    self.backdropOpacity = backdropOpacity
    self.label = label
    self.content = content
  }

  public var body: some View {
    Button(action: presentOverlay) {
      label()
    }
    .background(anchorReader())
  }

  /// Tracks the button's frame so the overlay can follow layout changes in real time.
  private func anchorReader() -> some View {
    GeometryReader { proxy in
      let frame = proxy.frame(in: .named(OverlaySpace.name))
      Color.clear
        .onAppear { updateAnchor(frame) }
        .onDisappear { clearAnchor() }
        .onChange(of: frame) { _, newFrame in
          updateAnchor(newFrame)
        }
    }
  }

  /// Requests the manager to show the overlay using the last known anchor frame.
  private func presentOverlay() {
    guard let overlay else { return }
    let id = overlay.presentAnchored(
      anchorFrame: anchorFrame,
      placement: placement,
      dismissPolicy: dismissPolicy,
      barrier: barrier,
      backdropOpacity: backdropOpacity
    ) {
      content()
    }
    overlayID = id
  }

  /// Keeps the manager's anchor reference fresh, enabling smooth repositioning.
  private func updateAnchor(_ frame: CGRect) {
    anchorFrame = frame
    if let overlayID {
      overlay?.updateAnchor(for: overlayID, frame: frame)
    }
  }

  /// Clears anchor information when the link disappears to avoid stale geometry.
  private func clearAnchor() {
    if let overlayID {
      overlay?.updateAnchor(for: overlayID, frame: nil)
    }
    anchorFrame = nil
  }
}
