import SwiftUI

/// The measured input needed to place one toast relative to newer toasts on
/// the same edge. Kept independent from view content so layout stays pure.
struct ToastLayoutEntry: Equatable {
  let id: OverlayID
  let edge: OverlayEdge
  let size: CGSize
}

/// Pure layout calculations shared by legacy and semantic presentations.
enum OverlayLayout {
  static func renderedSize(
    presentation: OverlayPresentation,
    containerSize: CGSize,
    intrinsicSize: CGSize,
    safeAreaInsets: EdgeInsets,
    layoutDirection: LayoutDirection,
    configuration: OverlayConfiguration
  ) -> CGSize {
    switch presentation {
    case .centered, .anchored:
      return intrinsicSize

    case .surface(.toast):
      let bounds = safeRect(
        containerSize: containerSize,
        safeAreaInsets: safeAreaInsets,
        layoutDirection: layoutDirection,
        additionalInset: configuration.toastEdgePadding
      )
      return CGSize(
        width: min(max(0, intrinsicSize.width), bounds.width),
        height: min(max(0, intrinsicSize.height), bounds.height)
      )

    case .surface(.drawer(let edge, let extent)):
      let bounds = safeRect(
        containerSize: containerSize,
        safeAreaInsets: safeAreaInsets,
        layoutDirection: layoutDirection
      )
      switch edge {
      case .leading, .trailing:
        return CGSize(
          width: resolvedExtent(
            extent,
            available: bounds.width,
            intrinsic: intrinsicSize.width
          ),
          height: bounds.height
        )
      case .bottom:
        return CGSize(
          width: bounds.width,
          height: resolvedExtent(
            extent,
            available: bounds.height,
            intrinsic: intrinsicSize.height
          )
        )
      }
    }
  }

  static func position(
    id: OverlayID,
    presentation: OverlayPresentation,
    containerSize: CGSize,
    contentSize: CGSize,
    anchorRect: CGRect?,
    safeAreaInsets: EdgeInsets = EdgeInsets(),
    layoutDirection: LayoutDirection = .leftToRight,
    configuration: OverlayConfiguration = .default,
    toastStack: [ToastLayoutEntry] = []
  ) -> CGPoint {
    switch presentation {
    case .centered(let offset):
      return CGPoint(
        x: containerSize.width / 2 + offset.x,
        y: containerSize.height / 2 + offset.y
      )

    case .anchored(let placement):
      guard let anchorRect else {
        return CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
      }
      return anchoredPosition(
        placement: placement,
        anchorRect: anchorRect,
        containerSize: containerSize,
        contentSize: contentSize
      )

    case .surface(.toast(let edge, let alignment, _)):
      return toastPosition(
        id: id,
        edge: edge,
        alignment: alignment,
        containerSize: containerSize,
        contentSize: contentSize,
        safeAreaInsets: safeAreaInsets,
        layoutDirection: layoutDirection,
        configuration: configuration,
        toastStack: toastStack
      )

    case .surface(.drawer(let edge, _)):
      return drawerPosition(
        edge: edge,
        containerSize: containerSize,
        contentSize: contentSize,
        safeAreaInsets: safeAreaInsets,
        layoutDirection: layoutDirection
      )
    }
  }

  static func safeRect(
    containerSize: CGSize,
    safeAreaInsets: EdgeInsets,
    layoutDirection: LayoutDirection,
    additionalInset: CGFloat = 0
  ) -> CGRect {
    let leftInset =
      layoutDirection == .leftToRight
      ? safeAreaInsets.leading
      : safeAreaInsets.trailing
    let rightInset =
      layoutDirection == .leftToRight
      ? safeAreaInsets.trailing
      : safeAreaInsets.leading
    let minX = leftInset + additionalInset
    let minY = safeAreaInsets.top + additionalInset
    let width = max(0, containerSize.width - minX - rightInset - additionalInset)
    let height = max(0, containerSize.height - minY - safeAreaInsets.bottom - additionalInset)
    return CGRect(x: minX, y: minY, width: width, height: height)
  }

  private static func anchoredPosition(
    placement: OverlayPlacement,
    anchorRect: CGRect,
    containerSize: CGSize,
    contentSize: CGSize
  ) -> CGPoint {
    switch placement {
    case .top(let spacing, let alignment):
      let x = horizontalCoordinate(
        for: alignment,
        anchorRect: anchorRect,
        contentSize: contentSize
      )
      let y = anchorRect.minY - spacing - contentSize.height / 2
      return CGPoint(
        x: clampedCoordinate(
          x,
          contentExtent: contentSize.width,
          lowerBound: 0,
          upperBound: containerSize.width
        ),
        y: clampedCoordinate(
          y,
          contentExtent: contentSize.height,
          lowerBound: 0,
          upperBound: containerSize.height
        )
      )

    case .bottom(let spacing, let alignment):
      let x = horizontalCoordinate(
        for: alignment,
        anchorRect: anchorRect,
        contentSize: contentSize
      )
      let y = anchorRect.maxY + spacing + contentSize.height / 2
      return CGPoint(
        x: clampedCoordinate(
          x,
          contentExtent: contentSize.width,
          lowerBound: 0,
          upperBound: containerSize.width
        ),
        y: clampedCoordinate(
          y,
          contentExtent: contentSize.height,
          lowerBound: 0,
          upperBound: containerSize.height
        )
      )
    }
  }

  private static func toastPosition(
    id: OverlayID,
    edge: OverlayEdge,
    alignment: EdgeAlignment,
    containerSize: CGSize,
    contentSize: CGSize,
    safeAreaInsets: EdgeInsets,
    layoutDirection: LayoutDirection,
    configuration: OverlayConfiguration,
    toastStack: [ToastLayoutEntry]
  ) -> CGPoint {
    let bounds = safeRect(
      containerSize: containerSize,
      safeAreaInsets: safeAreaInsets,
      layoutDirection: layoutDirection,
      additionalInset: configuration.toastEdgePadding
    )
    let physicalEdge = physicalEdge(for: edge, layoutDirection: layoutDirection)
    let newerEntries: ArraySlice<ToastLayoutEntry>
    if let index = toastStack.firstIndex(where: { $0.id == id }) {
      newerEntries = toastStack.suffix(from: toastStack.index(after: index))
    } else {
      newerEntries = []
    }
    let newerOnEdge = newerEntries.filter { $0.edge == edge }
    let inwardOffset = newerOnEdge.reduce(CGFloat.zero) { result, entry in
      let extent: CGFloat
      switch physicalEdge {
      case .top, .bottom:
        extent = entry.size.height
      case .left, .right:
        extent = entry.size.width
      }
      return result + extent + configuration.toastSpacing
    }

    let x: CGFloat
    let y: CGFloat
    switch physicalEdge {
    case .top:
      x = horizontalEdgeCoordinate(
        alignment: alignment,
        bounds: bounds,
        contentWidth: contentSize.width,
        layoutDirection: layoutDirection
      )
      y = bounds.minY + contentSize.height / 2 + inwardOffset
    case .bottom:
      x = horizontalEdgeCoordinate(
        alignment: alignment,
        bounds: bounds,
        contentWidth: contentSize.width,
        layoutDirection: layoutDirection
      )
      y = bounds.maxY - contentSize.height / 2 - inwardOffset
    case .left:
      x = bounds.minX + contentSize.width / 2 + inwardOffset
      y = verticalEdgeCoordinate(
        alignment: alignment,
        bounds: bounds,
        contentHeight: contentSize.height
      )
    case .right:
      x = bounds.maxX - contentSize.width / 2 - inwardOffset
      y = verticalEdgeCoordinate(
        alignment: alignment,
        bounds: bounds,
        contentHeight: contentSize.height
      )
    }

    return CGPoint(
      x: clampedCoordinate(
        x,
        contentExtent: contentSize.width,
        lowerBound: bounds.minX,
        upperBound: bounds.maxX
      ),
      y: clampedCoordinate(
        y,
        contentExtent: contentSize.height,
        lowerBound: bounds.minY,
        upperBound: bounds.maxY
      )
    )
  }

  private static func drawerPosition(
    edge: DrawerEdge,
    containerSize: CGSize,
    contentSize: CGSize,
    safeAreaInsets: EdgeInsets,
    layoutDirection: LayoutDirection
  ) -> CGPoint {
    let bounds = safeRect(
      containerSize: containerSize,
      safeAreaInsets: safeAreaInsets,
      layoutDirection: layoutDirection
    )
    switch physicalEdge(for: edge, layoutDirection: layoutDirection) {
    case .left:
      return CGPoint(x: bounds.minX + contentSize.width / 2, y: bounds.midY)
    case .right:
      return CGPoint(x: bounds.maxX - contentSize.width / 2, y: bounds.midY)
    case .bottom:
      return CGPoint(x: bounds.midX, y: bounds.maxY - contentSize.height / 2)
    case .top:
      preconditionFailure("DrawerEdge does not expose a top drawer")
    }
  }

  private static func horizontalCoordinate(
    for alignment: OverlayPlacement.HorizontalAlignment,
    anchorRect: CGRect,
    contentSize: CGSize
  ) -> CGFloat {
    switch alignment {
    case .leading:
      return anchorRect.minX + contentSize.width / 2
    case .center:
      return anchorRect.midX
    case .trailing:
      return anchorRect.maxX - contentSize.width / 2
    }
  }

  private static func horizontalEdgeCoordinate(
    alignment: EdgeAlignment,
    bounds: CGRect,
    contentWidth: CGFloat,
    layoutDirection: LayoutDirection
  ) -> CGFloat {
    switch alignment {
    case .center:
      return bounds.midX
    case .start:
      return layoutDirection == .leftToRight
        ? bounds.minX + contentWidth / 2
        : bounds.maxX - contentWidth / 2
    case .end:
      return layoutDirection == .leftToRight
        ? bounds.maxX - contentWidth / 2
        : bounds.minX + contentWidth / 2
    }
  }

  private static func verticalEdgeCoordinate(
    alignment: EdgeAlignment,
    bounds: CGRect,
    contentHeight: CGFloat
  ) -> CGFloat {
    switch alignment {
    case .start:
      return bounds.minY + contentHeight / 2
    case .center:
      return bounds.midY
    case .end:
      return bounds.maxY - contentHeight / 2
    }
  }

  private static func resolvedExtent(
    _ extent: DrawerExtent,
    available: CGFloat,
    intrinsic: CGFloat
  ) -> CGFloat {
    switch extent {
    case .content(let maximum):
      return min(max(0, maximum), max(0, intrinsic), available)
    case .fixed(let value):
      return min(max(0, value), available)
    case .fraction(let fraction):
      return available * min(max(0, fraction), 1)
    }
  }

  private static func clampedCoordinate(
    _ value: CGFloat,
    contentExtent: CGFloat,
    lowerBound: CGFloat,
    upperBound: CGFloat
  ) -> CGFloat {
    let minimum = lowerBound + contentExtent / 2
    let maximum = upperBound - contentExtent / 2
    guard minimum <= maximum else { return (lowerBound + upperBound) / 2 }
    return min(max(value, minimum), maximum)
  }

  private static func physicalEdge(
    for edge: OverlayEdge,
    layoutDirection: LayoutDirection
  ) -> PhysicalEdge {
    switch edge {
    case .top: return .top
    case .bottom: return .bottom
    case .leading: return layoutDirection == .leftToRight ? .left : .right
    case .trailing: return layoutDirection == .leftToRight ? .right : .left
    }
  }

  private static func physicalEdge(
    for edge: DrawerEdge,
    layoutDirection: LayoutDirection
  ) -> PhysicalEdge {
    switch edge {
    case .bottom: return .bottom
    case .leading: return layoutDirection == .leftToRight ? .left : .right
    case .trailing: return layoutDirection == .leftToRight ? .right : .left
    }
  }

  private enum PhysicalEdge {
    case top
    case bottom
    case left
    case right
  }
}
