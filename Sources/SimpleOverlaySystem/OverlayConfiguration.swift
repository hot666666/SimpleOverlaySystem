import Foundation

/// Host-wide defaults shared by semantic overlay surfaces.
///
/// Layout constants live at the host boundary so individual call sites do not
/// reintroduce magic coordinates or conflicting stacking policies.
public struct OverlayConfiguration: Equatable, Sendable {
  /// Padding between toast content and the host's safe-area edges. Negative
  /// values passed to the initializer become `0`.
  public var toastEdgePadding: CGFloat
  /// Spacing between toasts stacked on the same edge. Negative values passed
  /// to the initializer become `0`.
  public var toastSpacing: CGFloat
  /// Maximum number of visible toasts on each semantic edge. When a lane
  /// overflows, the host removes its oldest toast. The minimum value is `1`.
  public var maximumVisibleToastsPerEdge: Int
  /// Backdrop opacity used by semantic drawers, clamped to `0 ... 1`.
  public var drawerBackdropOpacity: Double

  /// Creates the shared policy used by one ``OverlayContainer``.
  ///
  /// Configuration belongs at the host boundary so every call site uses the
  /// same safe-area padding, toast capacity, and drawer backdrop.
  ///
  /// - Parameters:
  ///   - toastEdgePadding: Safe-area-relative padding for toast lanes.
  ///   - toastSpacing: Distance between toasts on the same edge.
  ///   - maximumVisibleToastsPerEdge: Maximum visible toast count per edge.
  ///   - drawerBackdropOpacity: Black backdrop opacity for semantic drawers.
  public init(
    toastEdgePadding: CGFloat = 16,
    toastSpacing: CGFloat = 8,
    maximumVisibleToastsPerEdge: Int = 3,
    drawerBackdropOpacity: Double = 0.35
  ) {
    self.toastEdgePadding = max(0, toastEdgePadding)
    self.toastSpacing = max(0, toastSpacing)
    self.maximumVisibleToastsPerEdge = max(1, maximumVisibleToastsPerEdge)
    self.drawerBackdropOpacity = min(max(0, drawerBackdropOpacity), 1)
  }

  /// The standard host policy: 16-point edge padding, 8-point toast spacing,
  /// three visible toasts per edge, and a `0.35` drawer backdrop.
  public static let `default` = Self()
}
