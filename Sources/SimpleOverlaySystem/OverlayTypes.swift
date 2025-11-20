//
//  OverlayTypes.swift
//  SimpleOverlaySystem
//
//  Created by hs on 10/26/25.
//

import SwiftUI

/// A unique identifier for an overlay instance.
///
/// Created by ``OverlayManager`` whenever a new overlay is presented. Keep the
/// returned identifier if you need to track a specific overlay or assert in tests.
///
/// ```swift
/// let id: OverlayID = manager.presentCentered {
///   ToastView(text: "Saved!")
/// }
/// ```
public typealias OverlayID = UUID

// MARK: - Overlay Types

/// Controls how (or if) an overlay can dismiss.
///
/// Choose whether the overlay should close on background tap, require an explicit
/// in-overlay action (like a button), or only be dismissible programmatically.
public enum OverlayDismissPolicy {
  /// Tapping outside the overlay dismisses it automatically.
  case tapOutside
  /// Only explicit actions inside the overlay (e.g., a button) can dismiss it.
  case actionOnly
  /// The overlay will not dismiss until removed programmatically.
  /// Note: provide an accessible escape path for long‑lived modals.
  case none
}

// MARK: - Overlay Interaction Barrier

/// Governs whether touches are intercepted by the overlay layer.
///
/// - ``blockAll`` blocks interaction with underlying content (modal/sheet behavior).
/// - ``passthrough`` shows a scrim but lets touches pass (HUD/hint behavior).
public enum OverlayInteractionBarrier {
  /// Prevents touches from reaching content underneath the overlay.
  case blockAll
  /// Allows touches to pass through the overlay.
  case passthrough
}

// MARK: - Overlay Placement

/// Defines how an anchored overlay aligns relative to its source (anchor) view.
///
/// Used with ``OverlayManager/presentAnchored(anchorFrame:placement:dismissPolicy:barrier:backdropOpacity:content:)``
/// to specify vertical placement, horizontal alignment, and `spacing` from the anchor.
public enum OverlayPlacement: Equatable {
  /// Horizontal alignment options.
  public enum HorizontalAlignment: Equatable {
    /// Align to the anchor’s leading edge.
    case leading
    /// Align to the anchor’s center.
    case center
    /// Align to the anchor’s trailing edge.
    case trailing
  }

  /// Place above the anchor.
  ///
  /// - Parameters:
  ///   - spacing: Gap in points between the anchor and overlay. Default `0`.
  ///   - alignment: Horizontal alignment. Default ``HorizontalAlignment/center``.
  case top(spacing: CGFloat = 0, alignment: HorizontalAlignment = .center)
  /// Place below the anchor.
  ///
  /// - Parameters:
  ///   - spacing: Gap in points between the anchor and overlay. Default `0`.
  ///   - alignment: Horizontal alignment. Default ``HorizontalAlignment/center``.
  case bottom(spacing: CGFloat = 0, alignment: HorizontalAlignment = .center)
}

// MARK: - Overlay Presentation

/// Internal presentation styles used by the manager.
///
/// Indirectly configured through the public APIs: ``OverlayManager/presentCentered`` and
/// ``OverlayManager/presentAnchored(anchorFrame:placement:dismissPolicy:barrier:backdropOpacity:content:)``.
enum OverlayPresentation: Equatable {
	case centered(offset: CGPoint = .zero)
  case anchored(placement: OverlayPlacement)
}

// MARK: - Overlay Item

/// Internal model holding frame, content, and policy for a single overlay.
///
/// Not exposed publicly; used for rendering and layout calculations.
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
