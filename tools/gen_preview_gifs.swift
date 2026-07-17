// Generates a looping animated GIF preview from a character's walk sheet, for
// the README Characters section. Slices the horizontal sheet into frames,
// upscales each nearest-neighbor (so pixels stay crisp), and writes a
// transparent, infinitely-looping GIF.
//
// Usage:
//   swift tools/gen_preview_gifs.swift <characterID> [frameCount] [scale] [delaySeconds]
// e.g.
//   swift tools/gen_preview_gifs.swift puddles
//   swift tools/gen_preview_gifs.swift echo 4 8 0.12
//
// Reads  Resources/Characters/<id>/walk.png
// Writes docs/<id>.gif

import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: gen_preview_gifs.swift <characterID> [frameCount] [scale] [delaySeconds]\n".utf8))
    exit(2)
}

let id = args[1]
let frameCount = args.count > 2 ? Int(args[2]) ?? 4 : 4
let scale = args.count > 3 ? Int(args[3]) ?? 8 : 8
let delay = args.count > 4 ? Double(args[4]) ?? 0.12 : 0.12

let inPath = "Resources/Characters/\(id)/walk.png"
let outPath = "docs/\(id).gif"

// --- Load the sheet as a CGImage --------------------------------------------
guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: inPath) as CFURL, nil),
      let sheet = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write(Data("error: could not load \(inPath)\n".utf8))
    exit(1)
}

let frameW = sheet.width / frameCount
let frameH = sheet.height
let outW = frameW * scale
let outH = frameH * scale

// --- Slice + upscale each frame (nearest-neighbor) --------------------------
func upscaledFrame(_ i: Int) -> CGImage? {
    let cropRect = CGRect(x: i * frameW, y: 0, width: frameW, height: frameH)
    guard let frame = sheet.cropping(to: cropRect) else { return nil }

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: outW, height: outH,
        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.clear(CGRect(x: 0, y: 0, width: outW, height: outH)) // transparent bg
    ctx.interpolationQuality = .none                          // crisp pixels
    ctx.draw(frame, in: CGRect(x: 0, y: 0, width: outW, height: outH))
    return ctx.makeImage()
}

// --- Write the animated GIF -------------------------------------------------
guard let dest = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: outPath) as CFURL, UTType.gif.identifier as CFString, frameCount, nil
) else {
    FileHandle.standardError.write(Data("error: could not create \(outPath)\n".utf8))
    exit(1)
}

let gifProps: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0] // loop forever
]
CGImageDestinationSetProperties(dest, gifProps as CFDictionary)

let frameProps: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: delay,
        kCGImagePropertyGIFUnclampedDelayTime: delay,
    ]
]

for i in 0..<frameCount {
    guard let img = upscaledFrame(i) else {
        FileHandle.standardError.write(Data("error: could not build frame \(i)\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(dest, img, frameProps as CFDictionary)
}

guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("error: could not finalize \(outPath)\n".utf8))
    exit(1)
}

print("wrote \(outPath) (\(frameCount) frames, \(outW)x\(outH))")
