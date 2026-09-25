// Generates the 1024×1024 master app icon: the Puddles cat (idle frame 0,
// holding its glass of water) standing in a pixel puddle on a rounded
// water-blue tile. Art pixels are laid on a 32px grid (1024 = 32 × 32), so the
// icon stays crisp when build.sh downsamples it to 512/256/128/64/32.
//
// Usage:
//   swift tools/gen_app_icon.swift
//
// Reads  Resources/Characters/puddles/idle.png
// Writes art/AppIcon.png  (build.sh turns it into AppIcon.icns)

import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

let inPath = "Resources/Characters/puddles/idle.png"
let outPath = "art/AppIcon.png"

let canvas = 1024
let unit = 32 // one art pixel, in icon pixels

// --- Load idle frame 0 ------------------------------------------------------
guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: inPath) as CFURL, nil),
      let sheet = CGImageSourceCreateImageAtIndex(src, 0, nil),
      let frame = sheet.cropping(to: CGRect(x: 0, y: 0, width: 16, height: 16)) else {
    FileHandle.standardError.write(Data("error: could not load \(inPath)\n".utf8))
    exit(1)
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: canvas, height: canvas,
    bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// Art-grid helper: (gx, gy) in 32px units, measured from the TOP-left.
func cell(_ gx: Int, _ gy: Int, _ color: CGColor) {
    ctx.setFillColor(color)
    ctx.fill(CGRect(x: gx * unit, y: canvas - (gy + 1) * unit, width: unit, height: unit))
}

// --- Tile: macOS-template rounded square (824 on 1024) with a soft shadow ----
let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tileRect, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(tilePath)
ctx.setFillColor(rgb(0x2F6DB5))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [rgb(0x4A8FDB), rgb(0x1E4F8F)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tileRect.maxY),
                       end: CGPoint(x: 0, y: tileRect.minY), options: [])

// Sparkles (tiny plus shapes and dots) in the empty corners.
let sparkle = rgb(0xBFE3FF, 0.9)
for (x, y) in [(7, 8), (24, 7)] {
    cell(x, y, sparkle); cell(x - 1, y, sparkle); cell(x + 1, y, sparkle)
    cell(x, y - 1, sparkle); cell(x, y + 1, sparkle)
}
for (x, y) in [(26, 11), (6, 12)] { cell(x, y, rgb(0xBFE3FF, 0.6)) }

// --- Puddle under the cat's feet (drawn first so the cat stands in it) ------
let catX = 10, catY = 10 // cat frame origin on the grid
let puddle = rgb(0x7FC4F5)
let puddleHi = rgb(0xE5F4FF)
for x in (catX + 1)...(catX + 11) { cell(x, catY + 9, puddle); cell(x, catY + 11, puddle) }
for x in (catX - 1)...(catX + 13) { cell(x, catY + 10, puddle) }
cell(catX + 11, catY + 10, puddleHi); cell(catX + 12, catY + 10, puddleHi)
cell(catX - 1, catY + 10, rgb(0xA9D8FA))

// --- Cat: frame 0 upscaled nearest-neighbor, aligned to the grid ------------
ctx.interpolationQuality = .none
ctx.draw(frame, in: CGRect(x: catX * unit, y: canvas - (catY + 16) * unit,
                           width: 16 * unit, height: 16 * unit))
ctx.restoreGState()

// --- Write -------------------------------------------------------------------
guard let img = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
          URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("error: could not create \(outPath)\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("error: could not finalize \(outPath)\n".utf8))
    exit(1)
}
print("wrote \(outPath) (\(canvas)x\(canvas))")
