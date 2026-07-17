// Generates the Echo sprite sheets (walk.png, idle.png) as 16x16 pixel-art
// frames, matching the Puddles cat's format: horizontal sheet, facing left.
//
// STALE: this generator draws the *original blue droplet* design. Echo shipped
// as a hand-drawn purple bat instead, so the committed art in
// Resources/Characters/echo/ was replaced by hand and does NOT come from this
// script. Kept for reference only — do not re-run it over the shipped art.
//
// Usage: swift gen_echo.swift <output-dir>

import AppKit

let frameSize = 16

// Palette
let colors: [Swift.Character: (UInt8, UInt8, UInt8, UInt8)] = [
    "D": (23, 66, 107, 255),    // dark outline
    "B": (86, 174, 236, 255),   // body blue
    "H": (150, 214, 250, 255),  // highlight
    "E": (16, 24, 38, 255),     // eyes / mouth
]

// Base body, rows 0-13 (rows 14-15 are left for feet / empty). Facing left:
// eyes sit left of center. Droplet tip on top, rounded body, flat bottom.
let body: [String] = [
    "................",
    ".......D........",
    "......DBD.......",
    ".....DBBBD......",
    "....DBHBBBD.....",
    "....DBHBBBD.....",
    "...DBBBBBBBD....",
    "..DBBBBBBBBBD...",
    "..DBEBBBEBBBD...",
    "..DBEBBBEBBBD...",
    "..DBBBBBBBBBD...",
    "..DBBEBBBBBBD...",
    "..DBBBBBBBBBD...",
    "...DDDDDDDDD....",
]

struct Frame {
    var bodyOffsetY: Int          // -1 = bobbed up one pixel
    var feet: [(Int, Int)]        // (startCol, endCol) pairs, 1px tall
    var blink: Bool = false
}

func renderGrid(_ frame: Frame) -> [[Swift.Character]] {
    var grid = Array(repeating: Array(repeating: Swift.Character("."), count: frameSize),
                     count: frameSize)
    var rows = body
    if frame.blink {
        // Close the eyes: clear the top half (row 8), keep the bottom (row 9).
        rows[8] = rows[8].replacingOccurrences(of: "E", with: "B")
    }
    for (r, row) in rows.enumerated() {
        let dest = r + frame.bodyOffsetY
        guard dest >= 0 && dest < frameSize else { continue }
        for (c, ch) in row.enumerated() where ch != "." {
            grid[dest][c] = ch
        }
    }
    // Feet sit one row under the body's bottom outline (row 13 + offset).
    let feetRow = 14 + frame.bodyOffsetY
    for (a, b) in frame.feet {
        for c in a...b { grid[feetRow][c] = "D" }
    }
    return grid
}

func writeSheet(frames: [Frame], to url: URL) {
    let sheetW = frameSize * frames.count
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: sheetW, pixelsHigh: frameSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 4 * sheetW, bitsPerPixel: 32
    ), let data = rep.bitmapData else { fatalError("bitmap alloc failed") }

    for (i, frame) in frames.enumerated() {
        let grid = renderGrid(frame)
        for y in 0..<frameSize {
            for x in 0..<frameSize {
                let ch = grid[y][x]
                guard let (r, g, b, a) = colors[ch] else { continue }
                let off = (y * sheetW + (i * frameSize + x)) * 4
                data[off] = r; data[off + 1] = g; data[off + 2] = b; data[off + 3] = a
            }
        }
    }

    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("png encode failed")
    }
    try! png.write(to: url)
    print("wrote \(url.path)")
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try! FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// Walk: alternate stride positions with a 1px bob between steps.
writeSheet(frames: [
    Frame(bodyOffsetY: 0,  feet: [(4, 5), (9, 10)]),
    Frame(bodyOffsetY: -1, feet: [(5, 6), (8, 9)]),
    Frame(bodyOffsetY: 0,  feet: [(3, 4), (10, 11)]),
    Frame(bodyOffsetY: -1, feet: [(5, 6), (8, 9)]),
], to: outDir.appendingPathComponent("walk.png"))

// Idle: feet together, slow blink.
writeSheet(frames: [
    Frame(bodyOffsetY: 0, feet: [(4, 5), (9, 10)]),
    Frame(bodyOffsetY: 0, feet: [(4, 5), (9, 10)], blink: true),
], to: outDir.appendingPathComponent("idle.png"))
