//
//  OverlayTypes.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

/// Unique identifier assigned to a particular overlay instance.
public typealias OverlayID = UUID

// MARK: - Overlay Types

/// Controls how (or if) an overlay is allowed to dismiss itself.
public enum OverlayDismissPolicy {
  /// Tap gestures outside of the overlay should dismiss it automatically.
  case tapOutside
  /// Only explicit actions inside the overlay (e.g. buttons) can dismiss it.
  case actionOnly
  /// Overlay cannot be dismissed until the owner removes it programmatically.
  case none
}

// MARK: - Overlay Interaction Barrier

/// Governs whether touches are intercepted by the overlay system.
public enum OverlayInteractionBarrier {
  /// Prevents touches from reaching content underneath the overlay.
  case blockAll
  /// Allows touches to pass through (useful for hints or HUDs).
  case passthrough
}

// MARK: - Overlay Placement

/// Defines how an anchored overlay should align relative to its source view.
public enum OverlayPlacement: Equatable {
  public enum HorizontalAlignment: Equatable {
    case leading
    case center
    case trailing
  }

  case top(spacing: CGFloat = 0, alignment: HorizontalAlignment = .center)
  case bottom(spacing: CGFloat = 0, alignment: HorizontalAlignment = .center)
}

// MARK: - Overlay Presentation

/// Internal presentation styles supported by the manager.
enum OverlayPresentation: Equatable {
  case centered
  case anchored(placement: OverlayPlacement)
}

// MARK: - Overlay Item

/// Frame, content, and policy information for a single overlay entry.
struct OverlayItem: Identifiable {
  let id: OverlayID
  let presentation: OverlayPresentation
  let dismissPolicy: OverlayDismissPolicy
  let barrier: OverlayInteractionBarrier
  let backdropOpacity: Double
  let content: () -> AnyView
  var anchorFrame: CGRect?
  var size: CGSize?
}
