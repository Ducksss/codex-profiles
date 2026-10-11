// Renders the Raycast extension icon: three stacked profile windows with a
// shell prompt on a blue tile. Drawn from plain shapes, with no symbol fonts
// or third-party marks.
//
//   swiftc -parse-as-library -framework AppKit \
//     scripts/raycast/render-extension-icon.swift -o /tmp/render-extension-icon
//   /tmp/render-extension-icon raycast/assets/extension-icon.png
import AppKit

@MainActor
@main
struct RenderExtensionIcon {
    static func main() {
        guard CommandLine.arguments.count == 2, CommandLine.arguments[1].hasSuffix(".png") else {
            fail("Usage: render-extension-icon <output.png>")
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        do {
            try render(pixels: 512).write(to: output, options: .atomic)
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func render(pixels: Int) -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fail("Could not create the icon bitmap.")
        }

        let scale = CGFloat(pixels) / 512
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: scale, y: scale)

        let blue = NSColor(srgbRed: 0.16, green: 0.34, blue: 0.89, alpha: 1)
        let tile = NSBezierPath(roundedRect: NSRect(x: 16, y: 16, width: 480, height: 480), xRadius: 108, yRadius: 108)
        NSGradient(
            starting: NSColor(srgbRed: 0.27, green: 0.47, blue: 0.98, alpha: 1),
            ending: NSColor(srgbRed: 0.12, green: 0.24, blue: 0.74, alpha: 1)
        )?.draw(in: tile, angle: -60)

        // Back to front: each profile is its own window.
        let cards: [(NSPoint, CGFloat)] = [
            (NSPoint(x: 160, y: 190), 0.38),
            (NSPoint(x: 126, y: 156), 0.66),
            (NSPoint(x: 92, y: 122), 1),
        ]
        for (origin, alpha) in cards {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(white: 0, alpha: 0.22)
            shadow.shadowOffset = NSSize(width: 0, height: -6)
            shadow.shadowBlurRadius = 14
            shadow.set()
            NSColor(white: 1, alpha: alpha).setFill()
            NSBezierPath(roundedRect: NSRect(origin: origin, size: NSSize(width: 260, height: 200)), xRadius: 36, yRadius: 36).fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        // A shell prompt on the front window.
        let prompt = NSBezierPath()
        prompt.move(to: NSPoint(x: 134, y: 254))
        prompt.line(to: NSPoint(x: 170, y: 222))
        prompt.line(to: NSPoint(x: 134, y: 190))
        prompt.move(to: NSPoint(x: 192, y: 190))
        prompt.line(to: NSPoint(x: 250, y: 190))
        prompt.lineWidth = 20
        prompt.lineCapStyle = .round
        prompt.lineJoinStyle = .round
        blue.setStroke()
        prompt.stroke()

        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fail("Could not encode the icon PNG.")
        }
        return png
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
        exit(1)
    }
}
