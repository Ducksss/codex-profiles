import AppKit
import Foundation

@MainActor
@main
struct RenderPreview {
    static func main() {
        guard CommandLine.arguments.count >= 2 else {
            FileHandle.standardError.write(Data("Usage: RenderPreview <output.png> [--empty] [--dark]\n".utf8))
            exit(2)
        }

        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        application.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)

        let suite = "menu-preview-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspaceStore(client: CLIClient(executableURL: nil), defaults: defaults)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let bindings = CommandLine.arguments.contains("--empty")
            ? []
            : [
                workspace("\(home)/Dev/codex-profiles", profile: "work"),
                workspace("\(home)/Dev/personal-site", profile: "personal"),
            ]
        let profiles = CommandLine.arguments.contains("--empty") ? [] : ["default", "personal", "work"]
        // Deterministic sample quotas for layout review, never account data.
        let now = Date()
        func sample(_ primary: Double, _ secondary: Double) -> ProfileUsage {
            .available(CodexRateLimits(windows: [
                RateLimitWindow(usedPercent: primary, windowDurationMins: 300, resetsAt: now.addingTimeInterval(7200).timeIntervalSince1970),
                RateLimitWindow(usedPercent: secondary, windowDurationMins: 10080, resetsAt: now.addingTimeInterval(259200).timeIntervalSince1970),
            ]), checkedAt: now)
        }
        // One healthy, one low and one critical profile show every meter state.
        store.loadPreview(bindings, profiles: profiles, usage: [
            "default": sample(18, 36), "personal": sample(43, 78), "work": sample(93, 59),
        ])
        if let first = bindings.first { store.togglePin(first) }
        if CommandLine.arguments.contains("--no-results") { store.query = "does-not-exist" }

        let controller = WorkspaceMenuViewController(store: store, defaults: defaults)
        let previewView = controller.view
        let size = controller.preferredContentSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
        // Offscreen renders cannot sample the desktop. Use an opaque system
        // backdrop for layout previews; NSPopover owns the live material.
        let backdrop = NSBox(frame: NSRect(origin: .zero, size: size))
        backdrop.boxType = .custom
        backdrop.borderWidth = 0
        backdrop.titlePosition = .noTitle
        var background: NSColor?
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            background = NSColor.windowBackgroundColor.usingColorSpace(.sRGB)
        }
        guard let background else { fail("Could not resolve the system preview backdrop.") }
        backdrop.fillColor = background
        backdrop.contentViewMargins = .zero
        backdrop.contentView = previewView
        window.contentView = backdrop
        window.setContentSize(size)
        previewView.frame = NSRect(origin: .zero, size: size)
        previewView.needsLayout = true
        previewView.layoutSubtreeIfNeeded()

        let scale = window.backingScaleFactor
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            fail("Could not allocate preview bitmap.")
        }
        bitmap.size = size
        backdrop.cacheDisplay(in: backdrop.bounds, to: bitmap)
        // A missing or duplicated material must not silently tint the export.
        guard let actual = bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB),
            abs(actual.redComponent - background.redComponent) < 0.02,
            abs(actual.greenComponent - background.greenComponent) < 0.02,
            abs(actual.blueComponent - background.blueComponent) < 0.02,
            actual.alphaComponent > 0.99 else {
            fail("Preview backdrop does not match the system appearance.")
        }
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            fail("Could not encode preview PNG.")
        }

        do {
            try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
        } catch {
            fail("Could not write preview: \(error.localizedDescription)")
        }
    }

    private static func workspace(_ path: String, profile: String) -> WorkspaceBinding {
        WorkspaceBinding(
            path: path,
            profile: profile,
            pathExists: true,
            profileExists: true
        )
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
        exit(1)
    }
}
