#if os(macOS)
  import AppKit
  import Observation
  import SwiftUI
  import Testing

  @testable import SimpleOverlaySystem

  /// AppKit key-window behavior requires an interactive macOS login session.
  /// Keep these tests opt-in so headless CI still exercises the real SwiftUI
  /// Host geometry path without treating runner focus policy as product state.
  private let runsWindowInteractionTests =
    ProcessInfo.processInfo.environment["SIMPLE_OVERLAY_RUN_WINDOW_TESTS"] == "1"

  @Suite("SwiftUI OverlayHost geometry", .serialized)
  struct OverlayHostGeometryTests {
    @Test("measured large Toasts evict the oldest item without frame overlap")
    @MainActor func measuredLargeToastsDoNotOverlap() async throws {
      let probe = ToastHostProbe()
      let hostSize = CGSize(width: 360, height: 640)
      let root = OverlayContainer(
        configuration: OverlayConfiguration(
          toastEdgePadding: 16,
          toastSpacing: 8,
          maximumVisibleToastsPerEdge: 3
        )
      ) {
        LargeToastHostFixture(probe: probe)
      }
      .frame(width: hostSize.width, height: hostSize.height)
      let host = NSHostingView(rootView: root)
      host.sizingOptions = []
      host.frame = CGRect(origin: .zero, size: hostSize)
      host.layoutSubtreeIfNeeded()

      try await waitUntil {
        host.layoutSubtreeIfNeeded()
        return probe.manager?.stack.count == 2 && probe.frames.count >= 2
      }

      let firstID = try #require(probe.presentedIDs.first)
      #expect(probe.manager?.stack.contains(where: { $0.id == firstID }) == false)

      let activeIDs = Set(probe.manager?.stack.map(\.id) ?? [])
      let frames = probe.presentedIDs.enumerated().compactMap { offset, id in
        activeIDs.contains(id) ? probe.frames[offset + 1] : nil
      }
      #expect(frames.count == 2)
      #expect(!frames[0].intersects(frames[1]))
      for frame in frames {
        #expect(probe.containerFrame.contains(frame))
      }
    }

    @MainActor
    private func waitUntil(
      attempts: Int = 200,
      condition: @escaping @MainActor () -> Bool
    ) async throws {
      for _ in 0..<attempts {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
      }
      Issue.record("Timed out waiting for the SwiftUI Host to settle")
    }
  }

  @Suite(
    "SwiftUI OverlayHost window interaction",
    .serialized,
    .enabled(if: runsWindowInteractionTests)
  )
  struct OverlayHostWindowInteractionTests {
    @Test("Toast content receives hits while space outside passes through")
    @MainActor func toastHitTestingUsesNonModalBounds() async throws {
      let probe = HitTestingHostProbe(surface: .toast)
      let harness = makeHitTestHarness(probe: probe)

      try await waitUntil {
        harness.host.layoutSubtreeIfNeeded()
        return probe.overlayFrame.width > 0 && probe.manager?.stack.count == 1
      }

      let overlayPoint = pointInHost(frame: probe.overlayFrame, container: probe.containerFrame)
      let outsidePoint = CGPoint(x: 20, y: probe.containerFrame.height / 2)

      #expect(hitTarget(in: harness.host, at: overlayPoint) == .overlay)
      #expect(hitTarget(in: harness.host, at: outsidePoint) == .underlying)
    }

    @Test("Drawer backdrop blocks hits to underlying content")
    @MainActor func drawerBackdropBlocksUnderlyingHits() async throws {
      let probe = HitTestingHostProbe(surface: .drawer)
      let harness = makeHitTestHarness(probe: probe)

      try await waitUntil {
        harness.host.layoutSubtreeIfNeeded()
        return probe.overlayFrame.width > 0 && probe.manager?.stack.count == 1
      }

      let drawerPoint = pointInHost(frame: probe.overlayFrame, container: probe.containerFrame)
      let backdropPoint = CGPoint(x: 20, y: probe.containerFrame.height / 2)

      #expect(hitTarget(in: harness.host, at: drawerPoint) == .overlay)
      #expect(hitTarget(in: harness.host, at: backdropPoint) != .underlying)
    }

    @Test("focused Drawer handles Escape through the SwiftUI Host")
    @MainActor func drawerHandlesEscapeKey() async throws {
      let probe = HitTestingHostProbe(surface: .drawer)
      let harness = makeHitTestHarness(probe: probe)

      try await waitUntil {
        harness.host.layoutSubtreeIfNeeded()
        return probe.overlayFrame.width > 0 && probe.manager?.stack.count == 1
      }

      harness.window.makeKeyAndOrderFront(nil)
      try await Task.sleep(for: .milliseconds(50))
      #expect(sendEscape(to: harness.window))

      try await waitUntil {
        probe.manager?.stack.isEmpty == true
      }
      #expect(probe.manager?.stack.isEmpty == true)
    }

    @Test("mounted Drawer dismissal uses the latest validation closure")
    @MainActor func mountedDrawerUsesLatestDismissRule() async throws {
      let probe = DismissRuleHostProbe()
      let root = AnyView(
        OverlayContainer {
          DismissRuleHostFixture(probe: probe)
        }
        .frame(width: 360, height: 640)
      )
      let harness = makeHarness(root: root, size: CGSize(width: 360, height: 640))

      try await waitUntil {
        harness.host.layoutSubtreeIfNeeded()
        return probe.manager?.stack.count == 1
      }

      harness.window.makeKeyAndOrderFront(nil)
      try await Task.sleep(for: .milliseconds(50))
      #expect(sendEscape(to: harness.window))
      try await waitUntil { probe.interceptionCount == 1 }
      #expect(probe.manager?.stack.count == 1)

      probe.allowsDismissal = true
      harness.host.layoutSubtreeIfNeeded()
      try await Task.sleep(for: .milliseconds(50))
      #expect(sendEscape(to: harness.window))
      try await waitUntil { probe.manager?.stack.isEmpty == true }
    }

    @MainActor
    private func makeHitTestHarness(probe: HitTestingHostProbe) -> HitTestHarness {
      let size = CGSize(width: 360, height: 640)
      let root = AnyView(
        OverlayContainer {
          HitTestingHostFixture(probe: probe)
        }
        .frame(width: size.width, height: size.height)
      )
      return makeHarness(root: root, size: size)
    }

    @MainActor
    private func makeHarness(root: AnyView, size: CGSize) -> HitTestHarness {
      let host = NSHostingView(rootView: root)
      host.sizingOptions = []
      host.frame = CGRect(origin: .zero, size: size)
      let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
      )
      window.contentView = host
      window.orderFront(nil)
      host.layoutSubtreeIfNeeded()
      let harness = HitTestHarness(host: host, window: window)
      // Closing an AppKit window while SwiftUI transitions are still draining
      // can crash the SwiftPM test helper after the assertions have completed.
      // Keep these serialized-test harnesses alive until process exit instead.
      RetainedHitTestHarnesses.shared.retain(harness)
      return harness
    }

    private func pointInHost(frame: CGRect, container: CGRect) -> CGPoint {
      let swiftUIY = frame.midY - container.minY
      return CGPoint(
        x: frame.midX - container.minX,
        y: container.height - swiftUIY
      )
    }

    @MainActor
    private func hitTarget<Content: View>(
      in host: NSHostingView<Content>,
      at point: CGPoint
    ) -> HitTarget? {
      var candidate = host.hitTest(point)
      while let view = candidate {
        if let marker = view as? HitTargetView { return marker.target }
        candidate = view.superview
      }
      return nil
    }

    @MainActor
    private func sendEscape(to window: NSWindow) -> Bool {
      guard
        let event = NSEvent.keyEvent(
          with: .keyDown,
          location: .zero,
          modifierFlags: [],
          timestamp: ProcessInfo.processInfo.systemUptime,
          windowNumber: window.windowNumber,
          context: nil,
          characters: "\u{1B}",
          charactersIgnoringModifiers: "\u{1B}",
          isARepeat: false,
          keyCode: 53
        )
      else { return false }
      window.sendEvent(event)
      return true
    }

    @MainActor
    private func waitUntil(
      attempts: Int = 200,
      condition: @escaping @MainActor () -> Bool
    ) async throws {
      for _ in 0..<attempts {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
      }
      Issue.record("Timed out waiting for the SwiftUI Host to settle")
    }
  }

  @MainActor
  @Observable
  private final class ToastHostProbe {
    var manager: OverlayManager?
    var presentedIDs: [OverlayID] = []
    var frames: [Int: CGRect] = [:]
    var containerFrame: CGRect = .zero
  }

  private struct LargeToastHostFixture: View {
    @Environment(\.overlayManager) private var manager
    @State private var didPresent = false
    let probe: ToastHostProbe

    var body: some View {
      Color.clear
        .onGeometryChange(for: CGRect.self) { proxy in
          proxy.frame(in: .global)
        } action: { frame in
          probe.containerFrame = frame
        }
        .onAppear { presentToastsOnce() }
    }

    private func presentToastsOnce() {
      guard !didPresent, let manager else { return }
      didPresent = true
      probe.manager = manager

      for index in 1...3 {
        let id = manager.present(
          .toast(edge: .bottom, alignment: .end, duration: .persistent)
        ) {
          LargeToastProbeContent(index: index, probe: probe)
        }
        if let id {
          probe.presentedIDs.append(id)
        }
      }
    }
  }

  private struct LargeToastProbeContent: View {
    let index: Int
    let probe: ToastHostProbe

    var body: some View {
      Color.accentColor.opacity(0.2)
        .frame(width: 280, height: 300)
        .onGeometryChange(for: CGRect.self) { proxy in
          proxy.frame(in: .global)
        } action: { frame in
          probe.frames[index] = frame
        }
        .onDisappear {
          probe.frames[index] = nil
        }
    }
  }

  @MainActor
  @Observable
  private final class HitTestingHostProbe {
    enum Surface {
      case toast
      case drawer
    }

    let surface: Surface
    var manager: OverlayManager?
    var containerFrame: CGRect = .zero
    var overlayFrame: CGRect = .zero

    init(surface: Surface) {
      self.surface = surface
    }
  }

  private struct HitTestingHostFixture: View {
    @Environment(\.overlayManager) private var manager
    @State private var didPresent = false
    let probe: HitTestingHostProbe

    var body: some View {
      HitTargetRepresentable(target: .underlying)
        .onGeometryChange(for: CGRect.self) { proxy in
          proxy.frame(in: .global)
        } action: { frame in
          probe.containerFrame = frame
        }
        .onAppear { presentOnce() }
    }

    private func presentOnce() {
      guard !didPresent, let manager else { return }
      didPresent = true
      probe.manager = manager

      switch probe.surface {
      case .toast:
        manager.present(
          .toast(edge: .bottom, alignment: .end, duration: .persistent)
        ) {
          HitTargetRepresentable(target: .overlay)
            .frame(width: 100, height: 40)
            .reportFrame(to: probe)
        }
      case .drawer:
        manager.present(
          .drawer(edge: .trailing, extent: .fixed(120))
        ) {
          HitTargetRepresentable(target: .overlay)
            .reportFrame(to: probe)
        }
      }
    }
  }

  @MainActor
  @Observable
  private final class DismissRuleHostProbe {
    var manager: OverlayManager?
    var allowsDismissal = false
    var interceptionCount = 0
  }

  private struct DismissRuleHostFixture: View {
    @Environment(\.overlayManager) private var manager
    @State private var didPresent = false
    let probe: DismissRuleHostProbe

    var body: some View {
      Color.clear
        .onAppear { presentOnce() }
    }

    private func presentOnce() {
      guard !didPresent, let manager else { return }
      didPresent = true
      probe.manager = manager
      manager.present(.drawer(edge: .trailing, extent: .fixed(160))) {
        DismissRuleContent(probe: probe)
      }
    }
  }

  private struct DismissRuleContent: View {
    @Environment(\.dismissOverlay) private var dismissOverlay
    let probe: DismissRuleHostProbe

    var body: some View {
      let allowsDismissal = probe.allowsDismissal
      Color.clear
        .onOverlayDismissRequest {
          if allowsDismissal {
            dismissOverlay()
          } else {
            probe.interceptionCount += 1
          }
        }
    }
  }

  private extension View {
    func reportFrame(to probe: HitTestingHostProbe) -> some View {
      onGeometryChange(for: CGRect.self) { proxy in
        proxy.frame(in: .global)
      } action: { frame in
        probe.overlayFrame = frame
      }
    }
  }

  private enum HitTarget: Equatable {
    case underlying
    case overlay
  }

  private struct HitTargetRepresentable: NSViewRepresentable {
    let target: HitTarget

    func makeNSView(context: Context) -> HitTargetView {
      HitTargetView(target: target)
    }

    func updateNSView(_ nsView: HitTargetView, context: Context) {}
  }

  private final class HitTargetView: NSView {
    let target: HitTarget

    init(target: HitTarget) {
      self.target = target
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      bounds.contains(convert(point, from: superview)) ? self : nil
    }
  }

  @MainActor
  private final class HitTestHarness {
    let host: NSHostingView<AnyView>
    let window: NSWindow

    init(host: NSHostingView<AnyView>, window: NSWindow) {
      self.host = host
      self.window = window
    }
  }

  @MainActor
  private final class RetainedHitTestHarnesses {
    static let shared = RetainedHitTestHarnesses()
    private var harnesses: [HitTestHarness] = []

    func retain(_ harness: HitTestHarness) {
      harnesses.append(harness)
    }
  }
#endif
