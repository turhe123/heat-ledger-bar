import AppKit
import SwiftUI

/// App entry point: a window-style menu bar extra, a history window, and a Settings scene.
@main
struct HeatLedgerBarApp: App {
    @StateObject private var ledger = ThermalLedger()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(ledger)
        } label: {
            Image(nsImage: StatusIcon.image(for: ledger.currentLevel))
                .accessibilityLabel("Thermal state: \(ledger.currentLevel.name)")
        }
        .menuBarExtraStyle(.window)

        Window("Heat History", id: "history") {
            HistoryView()
                .environmentObject(ledger)
        }
        .defaultSize(width: 720, height: 560)

        Settings {
            SettingsView()
                .environmentObject(ledger)
        }
    }
}

/// Builds the tinted (non-template) thermometer glyph shown in the menu bar.
enum StatusIcon {
    static func image(for level: ThermalLevel) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [level.nsColor]))
        let base = NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: level.name)
        let image = base?.withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = false
        return image
    }
}

/// Shared helper for the donation link.
enum Support {
    static func openDonation() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }
}
