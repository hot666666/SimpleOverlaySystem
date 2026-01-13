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
    case auto(UUID)
    case named(String, DuplicateAction)
  }

  let kind: Kind

  /// Creates an auto-generated unique identifier.
  ///
  /// Each call creates a new UUID, so multiple overlays with `.auto` identifiers
  /// will always be treated as distinct.
  public static var auto: Self { .init(kind: .auto(UUID())) }

  /// Creates a named identifier that ignores duplicate presentations.
  ///
  /// If an overlay with the same key is already presented, the new presentation
  /// request is ignored and the method returns `nil`.
  ///
  /// - Parameter name: A unique string key for the overlay.
  /// - Returns: An identifier configured to ignore duplicates.
  public static func unique(_ name: String) -> Self {
    .init(kind: .named(name, .ignore))
  }

  /// Creates a named identifier that replaces existing overlays.
  ///
  /// If an overlay with the same key is already presented, it is dismissed
  /// before the new overlay is presented.
  ///
  /// - Parameter name: A unique string key for the overlay.
  /// - Returns: An identifier configured to replace duplicates.
  public static func replacing(_ name: String) -> Self {
    .init(kind: .named(name, .replace))
  }

  /// Extracts the string key if this is a named identifier.
  var namedKey: String? {
    if case .named(let key, _) = kind { return key }
    return nil
  }

  /// Extracts the duplicate action if this is a named identifier.
  var duplicateAction: DuplicateAction? {
    if case .named(_, let action) = kind { return action }
    return nil
  }
}

// MARK: - Dismissal Policy

/// A policy that defines how an overlay can be dismissed.
public enum DismissPolicy {
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
  /// The string key from a named `OverlayIdentifier`, if provided.
  let identifierKey: String?
  let presentation: OverlayPresentation
  let dismissPolicy: DismissPolicy
  let barrier: OverlayInteractionBarrier
  let backdropOpacity: Double
  let content: () -> AnyView
  var anchorFrame: CGRect?
  var size: CGSize?
}

// MARK: - Preference Key

/// A wrapper for dismiss handler closures that provides value semantics.
///
/// This struct wraps a dismiss action closure along with a unique identifier,
/// enabling it to be used in SwiftUI's preference system which requires `Equatable` conformance.
/// Equality is based solely on the identifier, not the closure itself.
struct DismissHandler: Equatable, Sendable {
  let id: UUID
  let action: @Sendable () -> Void

  static func == (lhs: DismissHandler, rhs: DismissHandler) -> Bool {
    lhs.id == rhs.id
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
