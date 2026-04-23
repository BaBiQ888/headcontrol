import AppKit
import SwiftUI

@main
struct HeadControlApp: App {
    @State private var controller = HeadController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(controller)
                .task { await controller.start() }
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Window("HeadControl", id: "main") {
            ContentView()
                .environment(controller)
        }
        .windowResizability(.contentSize)
    }

    /// Loads `MenuBarIcon.png` from the .app's Resources, falling back to an
    /// SF Symbol when running outside the bundle (e.g. `swift run`).
    private static var menuBarIcon: NSImage {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            return img
        }
        let fallback = NSImage(systemSymbolName: "face.dashed",
                               accessibilityDescription: "HeadControl")
        return fallback ?? NSImage()
    }
}
