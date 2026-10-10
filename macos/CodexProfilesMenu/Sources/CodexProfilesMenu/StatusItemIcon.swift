import AppKit

/// The menu-bar icon. It stays a monochrome template image, so macOS adapts it
/// to light, dark, tinted and increased-contrast menu bars. Low quota changes
/// its shape, never only its colour: a badge dot when low, and a badge with an
/// exclamation mark when critical.
enum StatusItemIcon {
    static let symbolName = "square.stack.3d.up.fill"

    static func image(for level: QuotaLevel, accessibilityDescription: String) -> NSImage {
        let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
            ?? NSImage(size: NSSize(width: 16, height: 18))
        base.isTemplate = true
        guard level != .normal else { return base }
        let diameter: CGFloat = 8
        let gap: CGFloat = 1.5
        let size = NSSize(width: base.size.width + 2, height: base.size.height)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            base.draw(in: NSRect(origin: .zero, size: base.size))
            let badge = NSRect(x: size.width - diameter, y: 0, width: diameter, height: diameter)
            // Clear a ring so the badge reads as separate from the symbol.
            context.setFillColor(NSColor.black.cgColor)
            context.setBlendMode(.clear)
            context.fillEllipse(in: badge.insetBy(dx: -gap, dy: -gap))
            context.setBlendMode(.normal)
            context.fillEllipse(in: badge)
            if level == .critical {
                // An exclamation mark cut out of the badge: a bar above a dot.
                context.setBlendMode(.clear)
                let bar = CGRect(x: badge.midX - 0.7, y: badge.midY - 0.7, width: 1.4, height: 3.2)
                context.addPath(CGPath(roundedRect: bar, cornerWidth: 0.7, cornerHeight: 0.7, transform: nil))
                context.fillPath()
                context.fillEllipse(in: CGRect(x: badge.midX - 0.75, y: badge.midY - 2.85, width: 1.5, height: 1.5))
                context.setBlendMode(.normal)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }
}
