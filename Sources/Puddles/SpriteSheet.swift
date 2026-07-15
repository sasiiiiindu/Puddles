import AppKit

/// A horizontal sprite sheet sliced into individual frames.
/// Frames are stored as `CGImage`s so they can be drawn with
/// nearest-neighbor interpolation for crisp pixel art.
final class SpriteSheet {
    let frames: [CGImage]

    /// Slice a horizontal PNG sheet into `frameCount` equal-width frames.
    init?(pngData: Data, frameCount: Int) {
        guard frameCount > 0,
              let rep = NSBitmapImageRep(data: pngData),
              let full = rep.cgImage else { return nil }

        let frameWidth = full.width / frameCount
        let frameHeight = full.height
        var sliced: [CGImage] = []
        for i in 0..<frameCount {
            let rect = CGRect(x: i * frameWidth, y: 0, width: frameWidth, height: frameHeight)
            if let frame = full.cropping(to: rect) {
                sliced.append(frame)
            }
        }
        guard !sliced.isEmpty else { return nil }
        self.frames = sliced
    }

    /// Load a PNG sheet bundled in `Contents/Resources/` (via build.sh).
    /// Returns nil if the resource is missing or can't be decoded, so callers
    /// can fall back to the placeholder.
    static func fromResource(named name: String, frameCount: Int) -> SpriteSheet? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url) else { return nil }
        return SpriteSheet(pngData: data, frameCount: frameCount)
    }

    /// A placeholder sheet generated in memory — used as a fallback when real
    /// art can't be loaded.
    static func placeholder(frameCount: Int, frameSize: Int) -> SpriteSheet {
        let data = PlaceholderSprite.makeSheetPNG(frameCount: frameCount, frameSize: frameSize)
        return SpriteSheet(pngData: data, frameCount: frameCount)!
    }
}

/// Generates a simple placeholder walking sprite sheet as PNG data, so the
/// animation pipeline is testable before real pixel art exists. It draws a
/// chunky "cat" body with legs that shift each frame to read as a walk cycle.
enum PlaceholderSprite {
    static func makeSheetPNG(frameCount: Int, frameSize: Int) -> Data {
        let width = frameCount * frameSize
        let height = frameSize

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fatalError("Could not allocate placeholder bitmap")
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
            fatalError("Could not create graphics context")
        }
        NSGraphicsContext.current = gctx
        let ctx = gctx.cgContext
        ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))

        let bodyColor = NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.28, alpha: 1).cgColor
        let dark = NSColor.black.cgColor
        let fs = CGFloat(frameSize)

        for i in 0..<frameCount {
            let ox = CGFloat(i * frameSize)

            // Body block.
            ctx.setFillColor(bodyColor)
            ctx.fill(CGRect(x: ox + 2, y: 3, width: fs - 4, height: fs - 6))

            // Ears (two little blocks up top).
            ctx.fill(CGRect(x: ox + 3, y: fs - 4, width: 2, height: 2))
            ctx.fill(CGRect(x: ox + fs - 5, y: fs - 4, width: 2, height: 2))

            // Eye.
            ctx.setFillColor(dark)
            ctx.fill(CGRect(x: ox + 4, y: fs - 7, width: 2, height: 2))

            // Moving marker: legs that shift horizontally each frame so the
            // walk cycle is visible even in the placeholder.
            let shift = CGFloat(i) * 2
            ctx.fill(CGRect(x: ox + 4 + shift, y: 1, width: 3, height: 3))
            ctx.fill(CGRect(x: ox + fs - 7 - shift, y: 1, width: 3, height: 3))
        }

        guard let data = rep.representation(using: .png, properties: [:]) else {
            fatalError("Could not encode placeholder PNG")
        }
        return data
    }
}
