import AppKit

@MainActor
@main
struct RenderAppIcon {
    static func main() {
        guard CommandLine.arguments.count == 2,
              CommandLine.arguments[1].hasSuffix(".iconset") else {
            fail("Usage: render-app-icon <output.iconset>")
        }

        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        application.appearance = NSAppearance(named: .aqua)
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for size in [16, 32, 128, 256, 512] {
                for scale in [1, 2] {
                    let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
                    try render(size * scale).write(to: directory.appendingPathComponent(name), options: .atomic)
                }
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func render(_ pixels: Int) -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap),
           let symbol = NSImage(systemSymbolName: "square.stack.3d.up.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.white])) else {
            fail("Could not create icon bitmap or SF Symbol.")
        }

        let side = CGFloat(pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let background = NSRect(x: side * 0.09, y: side * 0.09, width: side * 0.82, height: side * 0.82)
        NSColor(srgbRed: 0.16, green: 0.34, blue: 0.89, alpha: 1).setFill()
        NSBezierPath(roundedRect: background, xRadius: side * 0.18, yRadius: side * 0.18).fill()
        let factor = side * 0.55 / max(symbol.size.width, symbol.size.height)
        let width = symbol.size.width * factor
        let height = symbol.size.height * factor
        symbol.draw(in: NSRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fail("Could not encode icon PNG.")
        }
        return png
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
        exit(1)
    }
}
