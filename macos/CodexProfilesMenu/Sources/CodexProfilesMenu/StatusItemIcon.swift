import AppKit

/// The menu-bar icon. It stays a monochrome template image, so macOS adapts it
/// to light, dark, tinted and increased-contrast menu bars. Low quota changes
/// its shape, never only its colour: a badge dot when low, and a badge with an
/// exclamation mark when critical.
enum StatusItemIcon {
    static let symbolName = "square.stack.3d.up.fill"
    /// The badge sits in the bottom-right corner on whole points. Its odd
    /// diameter centres a one-point column on pixel boundaries, so the
    /// exclamation mark stays crisp on a 1x menu bar.
    static let badgeDiameter: CGFloat = 9

    static func image(for level: QuotaLevel, accessibilityDescription: String) -> NSImage {
        let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
            ?? NSImage(size: NSSize(width: 16, height: 18))
        base.isTemplate = true
        guard level != .normal else { return base }
        let diameter = badgeDiameter
        let gap: CGFloat = 1.5
        // A whole-point canvas keeps the badge and its cut-outs on pixel boundaries.
        let size = NSSize(width: base.size.width.rounded(.up) + 3, height: base.size.height.rounded(.up))
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
                // An exclamation mark cut out of the badge on whole points: a
                // one-point column with a five-point bar, a one-point gap and a
                // one-point dot, so 1x and 2x both show the bar apart from the dot.
                context.setBlendMode(.clear)
                let column = badge.midX - 0.5
                context.fill(CGRect(x: column, y: badge.minY + 3, width: 1, height: 5))
                context.fill(CGRect(x: column, y: badge.minY + 1, width: 1, height: 1))
                context.setBlendMode(.normal)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }
}
