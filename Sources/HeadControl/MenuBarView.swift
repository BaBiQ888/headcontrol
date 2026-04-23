import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(HeadController.self) private var controller
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var controller = controller

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "face.dashed")
                Text("HeadControl").font(.headline)
                Spacer()
                statusBadge
            }

            lastGestureBlock

            Divider()

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
                .frame(maxWidth: 160)
            }

            Toggle("Inject system keys", isOn: $controller.injectKeys)
                .toggleStyle(.switch)
            Toggle("Camera preview", isOn: $controller.previewEnabled)
                .toggleStyle(.switch)

            if controller.injectKeys && !controller.accessibilityTrusted {
                Text("Grant Accessibility for keys to fire")
                    .font(.caption).foregroundStyle(.orange)
            }

            Divider()

            HStack {
                Button("Open Window") { openWindow(id: "main") }
                Button("Reset") { controller.resetBaseline() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(statusColor).frame(width: 7, height: 7)
            Text(statusText)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch controller.status {
        case .running: .green
        case .requestingPermission, .idle: .gray
        case .permissionDenied, .error: .red
        }
    }

    private var statusText: String {
        switch controller.status {
        case .running: "running"
        case .requestingPermission: "starting"
        case .idle: "idle"
        case .permissionDenied: "no camera"
        case .error: "error"
        }
    }

    @ViewBuilder
    private var lastGestureBlock: some View {
        if let last = controller.recentGestures.first {
            HStack {
                Text(symbol(for: last.gesture)).font(.title)
                VStack(alignment: .leading, spacing: 0) {
                    Text(last.gesture.rawValue).font(.body.monospaced())
                    if let action = controller.mappings[last.gesture] {
                        Text(action.label)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(timeString(last.timestamp))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("No gesture yet — try a quick head turn")
                .font(.callout).foregroundStyle(.secondary)
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
