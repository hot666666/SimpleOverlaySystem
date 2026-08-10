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

// MARK: - Duplicate Action

/// A policy that defines how duplicate overlays with the same identifier are handled.
public enum DuplicateAction: Sendable {
  /// Ignores the new overlay if one with the same key already exists.
  case ignore
  /// Replaces the existing overlay with the new one.
  case replace
}

// MARK: - Overlay Identifier

/// An identifier for controlling overlay uniqueness and duplicate behavior.
///
/// Use this type to control whether an overlay can be presented multiple times
/// or should be unique within the overlay stack.
///
/// ## Usage
///
/// ```swift
/// // Auto-generated ID (allows duplicates)
/// manager.presentCentered { ToastView() }
///
/// // Named identifier that ignores duplicates
/// manager.presentCentered(id: .unique("settings")) { SettingsSheet() }
///
/// // Named identifier that replaces existing overlay
/// manager.presentCentered(id: .replacing("alert")) { AlertView() }
/// ```
///
/// You can also extend `OverlayIdentifier` in your app for convenience:
///
/// ```swift
/// extension OverlayIdentifier {
///   static var settings: Self { .unique("settings") }
///   static var todoSheet: Self { .unique("todoSheet") }
/// }
///
/// manager.presentCentered(id: .settings) { SettingsSheet() }
/// ```
public struct OverlayIdentifier: Hashable, Sendable {
  enum Kind: Hashable, Sendable {
    case auto
    case named(String, DuplicateAction)
  }

  let kind: Kind

  /// Automatically generates a unique identifier for every presentation (default behavior).
  public static var auto: Self { .init(kind: .auto) }

  /// Ignores the presentation if an overlay with the same key is already active.
  ///
  /// - Parameter key: A unique string key for the overlay.
  /// - Returns: An identifier configured to ignore duplicates.
  public static func unique(_ key: String) -> Self {
    .init(kind: .named(key, .ignore))
  }

  /// Replaces any existing overlay with the same key before presenting the new one.
  ///
  /// - Parameter key: A unique string key for the overlay.
  /// - Returns: An identifier configured to replace duplicates.
  public static func replacing(_ key: String) -> Self {
    .init(kind: .named(key, .replace))
  }

  /// Extracts the string key if this is a named identifier.
  var namedKey: String? {
    if case .named(let key, _) = kind { return key }
    return nil
  }
}

// MARK: - Dismissal Policy

/// A policy that defines how an overlay can be dismissed.
public enum DismissPolicy: Equatable, Sendable {
  /// The overlay can only be dismissed programmatically (e.g., by calling ``OverlayManager/dismiss(id:)``).
  /// It will not react to any user gestures outside of its content.
  case programmatic

  /// The overlay reacts to taps on the background scrim.
  case tap
}

// MARK: - Overlay Interaction Barrier

/// Governs whether touches are intercepted by the overlay layer.
///
/// - ``blockAll`` blocks interaction with underlying content (modal/sheet behavior).
/// - ``passthrough`` shows a scrim but lets touches pass (HUD/hint behavior).
public enum OverlayInteractionBarrier: Equatable, Sendable {
  /// Prevents touches from reaching content underneath the overlay.
  case blockAll
  /// Allows touches to pass through the overlay.
  case passthrough
}

// MARK: - Overlay Placement

/// Defines how an anchored overlay aligns relative to its source (anchor) view.
///
/// Used with ``OverlayManager/presentAnchored(id:anchorFrame:placement:dismissPolicy:barrier:backdropOpacity:content:)``
/// to specify vertical placement, horizontal alignment, and `spacing` from the anchor.
public enum OverlayPlacement: Equatable, Sendable {
  /// Horizontal alignment options.
  public enum HorizontalAlignment: Equatable, Sendable {
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

// MARK: - Semantic Surface Placement

/// A semantic container edge used by transient overlay surfaces.
///
/// `leading` and `trailing` follow the current SwiftUI layout direction.
public enum OverlayEdge: Hashable, Sendable {
  /// The safe-area-relative top edge.
  case top
  /// The safe-area-relative bottom edge.
  case bottom
  /// The logical leading edge, which follows layout direction.
  case leading
  /// The logical trailing edge, which follows layout direction.
  case trailing
}

/// Alignment along the edge that owns a transient overlay surface.
///
/// For top and bottom edges, `start` and `end` follow the current layout
/// direction. For leading and trailing edges they map to top and bottom.
public enum EdgeAlignment: Hashable, Sendable {
  /// The logical start of the owning edge.
  case start
  /// The center of the owning edge.
  case center
  /// The logical end of the owning edge.
  case end
}

/// Lifetime of a toast presentation.
public enum ToastDuration: Equatable, Sendable {
  /// Uses the library default of three seconds.
  case automatic
  /// Dismisses after the supplied number of seconds. Negative values behave
  /// as zero seconds.
  case seconds(TimeInterval)
  /// Remains visible until explicitly dismissed.
  case persistent

  var timeInterval: TimeInterval? {
    switch self {
    case .automatic:
      return 3
    case .seconds(let seconds):
      return max(0, seconds)
    case .persistent:
      return nil
    }
  }
}

/// Edges supported by an interactive drawer.
///
/// A top drawer is intentionally not part of the contract. It can be added
/// source-compatibly if a concrete consumer requires it later.
public enum DrawerEdge: Hashable, Sendable {
  /// The logical leading edge, which follows layout direction.
  case leading
  /// The logical trailing edge, which follows layout direction.
  case trailing
  /// The safe-area-relative bottom edge.
  case bottom
}

/// The drawer's size on the axis perpendicular to its presentation edge.
///
/// For leading and trailing drawers this is the width. For a bottom drawer it
/// is the height.
public enum DrawerExtent: Equatable, Sendable {
  /// Uses the content's ideal width or height, capped at `max` and the host's
  /// available extent.
  case content(max: CGFloat)
  /// Uses a fixed point width or height, clamped to the host's available extent.
  case fixed(CGFloat)
  /// Uses a fraction of the host's available width or height. Values outside
  /// `0 ... 1` are clamped.
  case fraction(CGFloat)

  /// A conventional inspector extent capped at 360 points.
  public static var inspector: Self { .content(max: 360) }
}

/// A semantic overlay surface whose interaction policy is owned by the host.
///
/// Callers choose the product meaning and placement. The host derives focus,
/// backdrop, hit-testing, transition, and accessibility behavior.
public enum OverlaySurface: Equatable, Sendable {
  /// A non-modal notification that stacks inward from a container edge.
  ///
  /// Toast content can receive interaction without installing a backdrop or
  /// capturing focus. Capacity and spacing come from ``OverlayConfiguration``.
  case toast(
    edge: OverlayEdge,
    alignment: EdgeAlignment = .end,
    duration: ToastDuration = .automatic
  )

  /// An interactive modal surface that slides in from a supported edge.
  ///
  /// The host owns its backdrop, input barrier, focus, Escape handling,
  /// accessibility dismissal, transition, and safe-area-constrained layout.
  case drawer(
    edge: DrawerEdge,
    extent: DrawerExtent = .inspector
  )
}

// MARK: - Overlay Presentation

/// Internal presentation styles used by the manager.
///
/// Indirectly configured through the public APIs: ``OverlayManager/presentCentered`` and
/// ``OverlayManager/presentAnchored(id:anchorFrame:placement:dismissPolicy:barrier:backdropOpacity:content:)``.
enum OverlayPresentation: Equatable {
  case centered(offset: CGPoint = .zero)
  case anchored(placement: OverlayPlacement)
  case surface(OverlaySurface)
}

// MARK: - Overlay Item

/// Internal model holding frame, content, and policy for a single overlay.
///
/// Not exposed publicly; used for rendering and layout calculations.
struct OverlayItem: Identifiable {
  let id: OverlayID
  /// The string key from a named `OverlayIdentifier`, if provided.
  let identifierKey: String?
  let presentation: OverlayPresentation
  let dismissPolicy: DismissPolicy
  let barrier: OverlayInteractionBarrier
  let backdropOpacity: Double
  let content: () -> AnyView
  let onDismiss: (@MainActor () -> Void)?
  var anchorFrame: CGRect?
  var size: CGSize?

  var surface: OverlaySurface? {
    guard case .surface(let surface) = presentation else { return nil }
    return surface
  }

  var isToast: Bool {
    guard case .toast = surface else { return false }
    return true
  }

  var isDrawer: Bool {
    guard case .drawer = surface else { return false }
    return true
  }
}

// MARK: - Preference Key

/// Stable indirection retained by the Host even when SwiftUI considers the
/// surrounding preference value unchanged. The modifier refreshes `action` on
/// every body evaluation, so a mounted overlay never calls stale validation.
@MainActor
final class DismissHandlerActionBox {
  private var action: @MainActor @Sendable () -> Void = {}

  func update(_ action: @escaping @MainActor @Sendable () -> Void) {
    self.action = action
  }

  func perform() {
    action()
  }
}

/// Value-semantic preference payload backed by a stable, refreshable action.
struct DismissHandler: Equatable {
  let id: UUID
  let actionBox: DismissHandlerActionBox

  @MainActor
  func perform() {
    actionBox.perform()
  }

  static func == (lhs: DismissHandler, rhs: DismissHandler) -> Bool {
    lhs.id == rhs.id && lhs.actionBox === rhs.actionBox
  }
}

/// A preference key for collecting dismiss handlers from overlay views.
///
/// This preference key is used by ``View/onTapBackground(perform:)`` to bubble up custom
/// dismiss handlers from overlay content views to ``OverlayHost``. The host collects all
/// handlers and maintains a mapping of overlay IDs to their respective actions.
///
/// ## Reduction Strategy
/// When multiple overlays are stacked, the preference values from all overlay views are
/// merged into a single dictionary. In case of conflicts (same overlay ID), newer values
/// replace older ones.
struct OverlayDismissHandlerPreferenceKey: PreferenceKey {
  static let defaultValue: [OverlayID: DismissHandler] = [:]

  static func reduce(value: inout [OverlayID: DismissHandler], nextValue: () -> [OverlayID: DismissHandler]) {
    value.merge(nextValue()) { _, new in new }
  }
}
