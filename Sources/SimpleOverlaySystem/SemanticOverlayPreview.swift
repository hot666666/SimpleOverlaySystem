#if DEBUG
  import SwiftUI

  /// Interactive Xcode Preview that exercises every public presentation family.
  ///
  /// Use the Manager section for event-driven surfaces and the Binding section
  /// for SwiftUI-owned lifecycle behavior. The playground intentionally keeps
  /// all examples in the package so API changes fail to compile here as well as
  /// in tests.
  private struct SemanticOverlayPlayground: View {
    @Environment(\.overlayManager) private var overlay

    @State private var showsCentered = false
    @State private var centeredItem: PreviewItem?
    @State private var showsAnchored = false
    @State private var anchoredItem: PreviewItem?
    @State private var showsToast = false
    @State private var toastItem: PreviewItem?
    @State private var showsDrawer = false
    @State private var drawerItem: PreviewItem?
    @State private var showsGuardedDrawer = false
    @State private var nextItemID = 1
    @State private var lastEvent = "Ready"

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          header
          managerExamples
          bindingExamples
          dismissalExamples
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(Color.secondary.opacity(0.08))
      .overlayCentered(
        isPresented: $showsCentered,
        onDismiss: { lastEvent = "Centered Bool dismissed" }
      ) {
        PreviewCard(title: "Centered · isPresented", detail: "Binding writes false on dismissal")
      }
      .overlayCentered(
        item: $centeredItem,
        onDismiss: { lastEvent = "Centered item dismissed" }
      ) { item in
        PreviewCard(title: item.title, detail: "Centered · item")
      }
      .overlayToast(
        isPresented: $showsToast,
        edge: .top,
        alignment: .center,
        onDismiss: { lastEvent = "Toast Bool dismissed automatically" }
      ) {
        PreviewToast(text: "Binding Bool · top center")
      }
      .overlayToast(
        item: $toastItem,
        edge: .bottom,
        alignment: .end,
        onDismiss: { lastEvent = "Toast item dismissed automatically" }
      ) { item in
        PreviewToast(text: "\(item.title) · bottom end")
      }
      .overlayDrawer(
        isPresented: $showsDrawer,
        edge: .leading,
        extent: .fixed(300),
        onDismiss: { lastEvent = "Leading Drawer dismissed" }
      ) {
        PreviewDrawer(title: "Leading · isPresented", detail: "fixed(300)")
      }
      .overlayDrawer(
        item: $drawerItem,
        edge: .trailing,
        extent: .inspector,
        onDismiss: { lastEvent = "Inspector item dismissed" }
      ) { item in
        PreviewDrawer(title: item.title, detail: "trailing · inspector")
      }
      .overlayDrawer(
        isPresented: $showsGuardedDrawer,
        edge: .bottom,
        extent: .fraction(0.42),
        onDismiss: { lastEvent = "Guarded Drawer dismissed" }
      ) {
        DismissGuardDrawer()
      }
    }

    private var header: some View {
      VStack(alignment: .leading, spacing: 6) {
        Text("SimpleOverlaySystem Playground")
          .font(.largeTitle.bold())
        Text("Last event: \(lastEvent)")
          .font(.callout.monospaced())
          .foregroundStyle(.secondary)
      }
    }

    private var managerExamples: some View {
      PlaygroundSection(
        title: "Manager · present(_ surface:)",
        detail: "Event-driven APIs. Toasts use persistent duration here so placement is easy to inspect."
      ) {
        Button("Top · start") { presentToast(edge: .top, alignment: .start) }
        Button("Bottom · end") { presentToast(edge: .bottom, alignment: .end) }
        Button("Leading · center") { presentToast(edge: .leading, alignment: .center) }
        Button("Trailing · center") { presentToast(edge: .trailing, alignment: .center) }
        Button("Stack 4 bottom") { presentToastOverflow() }
        Button("Leading Drawer") { presentDrawer(edge: .leading, extent: .fixed(280)) }
        Button("Trailing Inspector") { presentDrawer(edge: .trailing, extent: .inspector) }
        Button("Bottom Drawer") { presentDrawer(edge: .bottom, extent: .fraction(0.4)) }
        Button("Dismiss top") { overlay?.dismissTop() }
        Button("Dismiss all") { overlay?.dismissAll() }
      }
    }

    private var bindingExamples: some View {
      PlaygroundSection(
        title: "Binding · isPresented / item",
        detail: "Dismiss from the backdrop or content and watch the source state synchronize."
      ) {
        Button("Centered Bool") { showsCentered = true }
        Button("Centered item") { centeredItem = makeItem("Centered item") }

        Button("Anchored Bool") { showsAnchored = true }
          .overlayAnchored(
            isPresented: $showsAnchored,
            placement: .bottom(spacing: 8, alignment: .center),
            onDismiss: { lastEvent = "Anchored Bool dismissed" }
          ) {
            PreviewCard(title: "Anchored · isPresented", detail: "bottom · center")
          }

        Button("Anchored item") { anchoredItem = makeItem("Anchored item") }
          .overlayAnchored(
            item: $anchoredItem,
            placement: .top(spacing: 8, alignment: .trailing),
            onDismiss: { lastEvent = "Anchored item dismissed" }
          ) { item in
            PreviewCard(title: item.title, detail: "top · trailing")
          }

        Button("Toast Bool") { showsToast = true }
        Button("Toast item") { toastItem = makeItem("Toast item") }
        Button("Leading Drawer Bool") { showsDrawer = true }
        Button("Inspector item A") { drawerItem = makeItem("Inspector A") }
        Button("Replace with item B") { drawerItem = makeItem("Inspector B") }
      }
    }

    private var dismissalExamples: some View {
      PlaygroundSection(
        title: "Dismissal interception",
        detail: "The first backdrop/Escape request is blocked. Enable dismissal inside the drawer, then try again."
      ) {
        Button("Bottom guarded Drawer") { showsGuardedDrawer = true }
      }
    }

    private func presentToast(edge: OverlayEdge, alignment: EdgeAlignment) {
      let item = makeItem("Toast \(nextItemID)")
      overlay?.present(
        .toast(edge: edge, alignment: alignment, duration: .persistent)
      ) {
        PreviewToast(text: item.title)
      }
    }

    private func presentToastOverflow() {
      for index in 1...4 {
        overlay?.present(
          .toast(edge: .bottom, alignment: .end, duration: .persistent)
        ) {
          PreviewToast(text: "Bottom stack \(index)")
        }
      }
    }

    private func presentDrawer(edge: DrawerEdge, extent: DrawerExtent) {
      overlay?.present(.drawer(edge: edge, extent: extent)) {
        PreviewDrawer(title: "Manager Drawer", detail: "\(String(describing: edge)) · \(extent.label)")
      }
    }

    private func makeItem(_ title: String) -> PreviewItem {
      defer { nextItemID += 1 }
      return PreviewItem(id: nextItemID, title: title)
    }
  }

  private struct PlaygroundSection<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: () -> Content

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text(title).font(.headline)
        Text(detail)
          .font(.callout)
          .foregroundStyle(.secondary)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], alignment: .leading) {
          content()
            .buttonStyle(.bordered)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }
  }

  private struct PreviewItem: Identifiable {
    let id: Int
    let title: String
  }

  private struct PreviewCard: View {
    @Environment(\.dismissOverlay) private var dismissOverlay
    let title: String
    let detail: String

    var body: some View {
      VStack(spacing: 12) {
        Text(title).font(.headline)
        Text(detail).foregroundStyle(.secondary)
        Button("Dismiss") { dismissOverlay() }
      }
      .padding(24)
      .background(.regularMaterial, in: .rect(cornerRadius: 16))
      .shadow(radius: 12)
    }
  }

  private struct PreviewToast: View {
    @Environment(\.dismissOverlay) private var dismissOverlay
    let text: String

    var body: some View {
      HStack(spacing: 12) {
        Text(text)
        Button("Close") { dismissOverlay() }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(.regularMaterial, in: .capsule)
      .shadow(radius: 8)
    }
  }

  private struct PreviewDrawer: View {
    @Environment(\.dismissOverlay) private var dismissOverlay
    let title: String
    let detail: String

    var body: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text(title).font(.title2.bold())
        Text(detail).foregroundStyle(.secondary)
        Text("The surface stays inside OverlayContainer and never resizes the platform window.")
        Spacer()
        Button("Dismiss") { dismissOverlay() }
          .buttonStyle(.borderedProminent)
      }
      .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(.regularMaterial)
    }
  }

  private struct DismissGuardDrawer: View {
    @Environment(\.dismissOverlay) private var dismissOverlay
    @State private var allowsDismissal = false
    @State private var intercepted = false

    var body: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text("Dismiss request interception").font(.title2.bold())
        Toggle("Allow dismissal", isOn: $allowsDismissal)
        if intercepted {
          Text("Dismissal was intercepted. Enable the toggle and request dismissal again.")
            .foregroundStyle(.orange)
        }
        Spacer()
        Button("Request from content") { handleDismissRequest() }
          .buttonStyle(.borderedProminent)
      }
      .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(.regularMaterial)
      .onOverlayDismissRequest { handleDismissRequest() }
    }

    private func handleDismissRequest() {
      if allowsDismissal {
        dismissOverlay()
      } else {
        intercepted = true
      }
    }
  }

  private extension DrawerExtent {
    var label: String {
      switch self {
      case .content(let maximum): "content(max: \(maximum))"
      case .fixed(let value): "fixed(\(value))"
      case .fraction(let value): "fraction(\(value))"
      }
    }
  }

  #Preview("Overlay API Playground") {
    OverlayContainer(
      configuration: OverlayConfiguration(
        toastEdgePadding: 16,
        toastSpacing: 8,
        maximumVisibleToastsPerEdge: 3,
        drawerBackdropOpacity: 0.35
      )
    ) {
      SemanticOverlayPlayground()
    }
    .frame(width: 900, height: 720)
  }
#endif
