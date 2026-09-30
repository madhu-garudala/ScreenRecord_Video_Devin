import AppKit
import Foundation

// Renders Recordly brand assets: squircle app-icon variants + transparent wordmark.
// Usage: swift scripts/render-icons.swift [outDir]

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "App/Branding"
try! FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
try! FileManager.default.createDirectory(atPath: "App/Recordly.iconset", withIntermediateDirectories: true)

// MARK: - Icon variants

// a: dark squircle, white ring + red dot (matches the menu-bar glyph)
// b: red squircle, white ring + white dot
// c: indigo squircle, white ring + red dot
func makeIcon(size: CGFloat, variant: String) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let inset = size * 0.06
        let iconRect = rect.insetBy(dx: inset, dy: inset)
        let squircle = NSBezierPath(roundedRect: iconRect,
                                    xRadius: iconRect.width * 0.235,
                                    yRadius: iconRect.height * 0.235)

        let bg: [NSColor]
        switch variant {
        case "b": bg = [NSColor(srgbRed: 0.99, green: 0.42, blue: 0.38, alpha: 1),
                        NSColor(srgbRed: 0.80, green: 0.09, blue: 0.15, alpha: 1)]
        case "c": bg = [NSColor(srgbRed: 0.38, green: 0.35, blue: 0.93, alpha: 1),
                        NSColor(srgbRed: 0.71, green: 0.33, blue: 0.92, alpha: 1)]
        default:  bg = [NSColor(srgbRed: 0.16, green: 0.16, blue: 0.19, alpha: 1),
                        NSColor(srgbRed: 0.05, green: 0.05, blue: 0.07, alpha: 1)]
        }
        NSGradient(colors: bg)!.draw(in: squircle, angle: 90)

        let c = NSPoint(x: rect.midX, y: rect.midY)
        let ringR = size * 0.30
        let ring = NSBezierPath(ovalIn: NSRect(x: c.x - ringR, y: c.y - ringR,
                                               width: ringR * 2, height: ringR * 2))
        ring.lineWidth = size * 0.052
        NSColor.white.withAlphaComponent(0.95).setStroke()
        ring.stroke()

        let dotR = size * 0.195
        let dotRect = NSRect(x: c.x - dotR, y: c.y - dotR, width: dotR * 2, height: dotR * 2)
        let dot = NSBezierPath(ovalIn: dotRect)
        if variant == "b" {
            NSColor.white.setFill()
            dot.fill()
        } else {
            NSGradient(colors: [NSColor(srgbRed: 1.00, green: 0.38, blue: 0.34, alpha: 1),
                                NSColor(srgbRed: 0.84, green: 0.09, blue: 0.14, alpha: 1)])!
                .draw(in: dot, angle: 90)
        }
        return true
    }
}

func writePNG(_ img: NSImage, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(img.size.width), pixelsHigh: Int(img.size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(origin: .zero, size: img.size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
}

// MARK: - Variant previews (512px)

for v in ["a", "b", "c"] {
    writePNG(makeIcon(size: 512, variant: v),
             to: "\(outDir)/recordly-icon-\(v).png")
}

// MARK: - Iconset for the chosen default (variant a)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in sizes {
    writePNG(makeIcon(size: px, variant: "a"), to: "App/Recordly.iconset/\(name)")
}

// MARK: - Wordmark (transparent, for docs/web)

func makeWordmark() -> NSImage {
    let size = NSSize(width: 1024, height: 256)
    return NSImage(size: size, flipped: false) { rect in
        let c = NSPoint(x: 128, y: 128)
        let ringR: CGFloat = 88
        let ring = NSBezierPath(ovalIn: NSRect(x: c.x - ringR, y: c.y - ringR,
                                               width: ringR * 2, height: ringR * 2))
        ring.lineWidth = 20
        NSColor.white.withAlphaComponent(0.95).setStroke()
        ring.stroke()
        let dotR: CGFloat = 56
        let dot = NSBezierPath(ovalIn: NSRect(x: c.x - dotR, y: c.y - dotR,
                                              width: dotR * 2, height: dotR * 2))
        NSGradient(colors: [NSColor(srgbRed: 1.00, green: 0.38, blue: 0.34, alpha: 1),
                            NSColor(srgbRed: 0.84, green: 0.09, blue: 0.14, alpha: 1)])!
            .draw(in: dot, angle: 90)

        let font = NSFont.systemFont(ofSize: 128, weight: .bold)
        let str = NSAttributedString(string: "Recordly", attributes: [
            .font: font,
            .foregroundColor: NSColor.white,
        ])
        str.draw(at: NSPoint(x: 260, y: 128 - str.size().height / 2))
        return true
    }
}
writePNG(makeWordmark(), to: "\(outDir)/recordly-wordmark-dark.png")

print("Wrote assets to \(outDir) and App/Recordly.iconset")
