import SwiftUI

struct ContentView: View {
    @Environment(HeadController.self) private var controller

    var body: some View {
        HStack(spacing: 0) {
            previewPane
            Divider()
            sidebar
        }
        .frame(minWidth: 880, minHeight: 640)
    }

    // MARK: - Preview pane

    private var previewPane: some View {
        ZStack {
            Color.black

            ZStack {
                if controller.previewEnabled {
                    CameraPreview(session: controller.cameraSession.session)
                } else {
                    Color(white: 0.08)
                }

                BaselineOverlay(
                    snapshot: controller.detectorSnapshot,
                    triggerRadius: controller.triggerRadius,
                    restRadius: controller.restRadius
                )
                TrajectoryOverlay(path: controller.nosePath.map(\.p))
                NoseOverlay(position: controller.nosePosition,
                            phase: controller.detectorSnapshot.phase)

                if !controller.previewEnabled {
                    VStack {
                        Spacer()
                        Text("Preview off — detection still running")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                }
            }
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .padding(8)

            statusOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch controller.status {
        case .running: EmptyView()
        case .idle, .requestingPermission:
            Text("Starting camera…").foregroundStyle(.white)
        case .permissionDenied:
            VStack(spacing: 8) {
                Text("Camera permission denied").font(.headline)
                Text("System Settings → Privacy & Security → Camera")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
        case .error(let message):
            Text(message).padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        @Bindable var controller = controller

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                viewSection(controller: $controller)
                Divider()
                detectorSection
                Divider()
                bindingsSection
                Divider()
                injectionSection(controller: $controller)
                Divider()
                gesturesSection
            }
            .padding(16)
        }
        .frame(width: 300)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func viewSection(controller: Bindable<HeadController>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("View").font(.headline)
            Toggle("Camera preview", isOn: controller.previewEnabled)
                .toggleStyle(.switch)
        }
    }

    private var detectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Detector").font(.headline)
                Spacer()
                Button("Reset baseline") { controller.resetBaseline() }
                    .controlSize(.small)
            }

            slider(label: "Trigger radius",
                   value: controller.triggerRadius,
                   range: 0.02...0.18, step: 0.005, format: "%.3f",
                   set: controller.setTriggerRadius)

            slider(label: "Rest radius",
                   value: controller.restRadius,
                   range: 0.005...0.06, step: 0.002, format: "%.3f",
                   set: controller.setRestRadius)

            slider(label: "Min velocity",
                   value: controller.velocityThreshold,
                   range: 0.05...1.0, step: 0.02, format: "%.2f /s",
                   set: controller.setVelocityThreshold)

            slider(label: "Cooldown",
                   value: controller.cooldown,
                   range: 0.1...1.5, step: 0.05, format: "%.2fs",
                   set: controller.setCooldown)

            slider(label: "Smoothing α",
                   value: controller.smoothingAlpha,
                   range: 0.1...1.0, step: 0.05, format: "%.2f",
                   set: controller.setSmoothingAlpha)

            HStack(spacing: 6) {
                Circle().fill(phaseColor).frame(width: 7, height: 7)
                Text("phase: \(controller.detectorSnapshot.phase.rawValue)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var phaseColor: Color {
        switch controller.detectorSnapshot.phase {
        case .warmup:  .gray
        case .rest:    .green
        case .cooling: .orange
        }
    }

    private func slider(label: String,
                        value: Double,
                        range: ClosedRange<Double>,
                        step: Double,
                        format: String,
                        set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.callout)
                Spacer()
                Text(String(format: format, value))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { value }, set: set), in: range, step: step)
        }
    }

    private var bindingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bindings").font(.headline)

            HStack {
                Text("Preset").font(.callout)
                Spacer()
                Picker("", selection: Binding(
                    get: { controller.preset },
                    set: { controller.setPreset($0) }
                )) {
                    ForEach(BindingPreset.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 170)
            }

            VStack(spacing: 4) {
                mappingRow(.left)
                mappingRow(.right)
                mappingRow(.up)
                mappingRow(.down)
            }
        }
    }

    private func mappingRow(_ gesture: HeadGesture) -> some View {
        HStack {
            Text(symbol(for: gesture))
                .font(.title3).frame(width: 22)
            Picker("", selection: Binding(
                get: { controller.mappings[gesture] ?? .none },
                set: { controller.setMapping($0, for: gesture) }
            )) {
                ForEach(KeyAction.allCases) { a in
                    Text(a.label).tag(a)
                }
            }
            .labelsHidden()
        }
    }

    private func injectionSection(controller: Bindable<HeadController>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System Keys").font(.headline)

            Toggle("Inject on gesture", isOn: controller.injectKeys)
                .toggleStyle(.switch)

            HStack(spacing: 6) {
                Circle()
                    .fill(controller.wrappedValue.accessibilityTrusted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(controller.wrappedValue.accessibilityTrusted ? "Accessibility granted" : "Accessibility needed")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !controller.wrappedValue.accessibilityTrusted {
                Button("Open Accessibility Settings") {
                    KeyInjector.openAccessibilitySettings()
                }
                .controlSize(.small)
            }

            HStack {
                Button("Test inject (→)") { controller.wrappedValue.testInject() }
                    .controlSize(.small)
                Spacer()
            }

            Text("Last: \(controller.wrappedValue.lastInjectStatus)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var gesturesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Gestures").font(.headline)

            if controller.recentGestures.isEmpty {
                Text("Move your head left / right / up / down (quick).")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(controller.recentGestures) { event in
                        HStack {
                            Text(symbol(for: event.gesture))
                                .font(.title3).frame(width: 22)
                            Text(event.gesture.rawValue)
                                .font(.body.monospaced())
                            Spacer()
                            Text(timeString(event.timestamp))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func symbol(for gesture: HeadGesture) -> String {
        switch gesture {
        case .left:  "←"
        case .right: "→"
        case .up:    "↑"
        case .down:  "↓"
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

// MARK: - Overlays

private struct NoseOverlay: View {
    let position: CGPoint?
    let phase: GestureDetector.Phase

    var body: some View {
        GeometryReader { geo in
            if let p = position {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .position(x: p.x * geo.size.width,
                              y: (1 - p.y) * geo.size.height)
            }
        }
        .allowsHitTesting(false)
    }

    private var color: Color {
        switch phase {
        case .warmup:  .gray
        case .rest:    .green
        case .cooling: .orange
        }
    }
}

private struct TrajectoryOverlay: View {
    let path: [CGPoint]

    var body: some View {
        GeometryReader { geo in
            Path { p in
                guard let first = path.first else { return }
                p.move(to: convert(first, in: geo.size))
                for pt in path.dropFirst() {
                    p.addLine(to: convert(pt, in: geo.size))
                }
            }
            .stroke(Color.green.opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }

    private func convert(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
    }
}

/// Inner ring = rest zone (baseline tracking is active here).
/// Outer ring = trigger zone (head leaving here while moving fast = fire).
/// Cross at center marks the current baseline.
private struct BaselineOverlay: View {
    let snapshot: GestureDetector.Snapshot
    let triggerRadius: Double
    let restRadius: Double

    var body: some View {
        GeometryReader { geo in
            if let bl = snapshot.baseline {
                let cx = bl.x * geo.size.width
                let cy = (1 - bl.y) * geo.size.height
                // Use width for both axes so circles stay round (positions
                // are normalized 0...1 on both axes anyway).
                let dim = min(geo.size.width, geo.size.height)

                ZStack {
                    Circle()
                        .stroke(Color.yellow.opacity(0.7),
                                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .frame(width: triggerRadius * dim * 2,
                               height: triggerRadius * dim * 2)
                    Circle()
                        .stroke(Color.green.opacity(0.55),
                                style: StrokeStyle(lineWidth: 1))
                        .frame(width: restRadius * dim * 2,
                               height: restRadius * dim * 2)
                    Path { p in
                        p.move(to: CGPoint(x: -5, y: 0))
                        p.addLine(to: CGPoint(x: 5, y: 0))
                        p.move(to: CGPoint(x: 0, y: -5))
                        p.addLine(to: CGPoint(x: 0, y: 5))
                    }
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                    .frame(width: 10, height: 10)
                }
                .position(x: cx, y: cy)
            }
        }
        .allowsHitTesting(false)
    }
}
