import Foundation

/// A tiny hand-authored bitmap font: each glyph is 3×5 "art pixels", matching
/// the cat sprite's pixel grid. Rendering these as solid blocks (rather than
/// upscaling an anti-aliased system font) gives clean, crisp pixel text.
///
/// Uppercase only — a 3×5 grid can't fit lowercase descenders cleanly, and
/// all-caps reads as intentional pixel art. `~` is a small water droplet.
enum PixelFont {

    static let glyphWidth = 3
    static let glyphHeight = 5
    static let spacing = 1 // blank columns between glyphs

    /// Character that renders as the blue water droplet.
    static let droplet: Character = "~"

    /// Rows are top-to-bottom; "1" is a filled pixel.
    private static let glyphs: [Character: [String]] = [
        "A": ["010", "101", "111", "101", "101"],
        "B": ["110", "101", "110", "101", "110"],
        "C": ["011", "100", "100", "100", "011"],
        "D": ["110", "101", "101", "101", "110"],
        "E": ["111", "100", "110", "100", "111"],
        "F": ["111", "100", "110", "100", "100"],
        "G": ["011", "100", "101", "101", "011"],
        "H": ["101", "101", "111", "101", "101"],
        "I": ["111", "010", "010", "010", "111"],
        "J": ["001", "001", "001", "101", "010"],
        "K": ["101", "101", "110", "101", "101"],
        "L": ["100", "100", "100", "100", "111"],
        "M": ["101", "111", "111", "101", "101"],
        "N": ["101", "111", "111", "111", "101"],
        "O": ["010", "101", "101", "101", "010"],
        "P": ["110", "101", "110", "100", "100"],
        "Q": ["010", "101", "101", "110", "011"],
        "R": ["110", "101", "110", "101", "101"],
        "S": ["011", "100", "010", "001", "110"],
        "T": ["111", "010", "010", "010", "010"],
        "U": ["101", "101", "101", "101", "111"],
        "V": ["101", "101", "101", "101", "010"],
        "W": ["101", "101", "111", "111", "101"],
        "X": ["101", "101", "010", "101", "101"],
        "Y": ["101", "101", "010", "010", "010"],
        "Z": ["111", "001", "010", "100", "111"],
        "0": ["111", "101", "101", "101", "111"],
        "1": ["010", "110", "010", "010", "111"],
        "2": ["110", "001", "010", "100", "111"],
        "3": ["110", "001", "010", "001", "110"],
        "4": ["101", "101", "111", "001", "001"],
        "5": ["111", "100", "110", "001", "110"],
        "6": ["011", "100", "110", "101", "010"],
        "7": ["111", "001", "010", "010", "010"],
        "8": ["010", "101", "010", "101", "010"],
        "9": ["010", "101", "011", "001", "110"],
        " ": ["000", "000", "000", "000", "000"],
        "!": ["010", "010", "010", "000", "010"],
        "?": ["110", "001", "010", "000", "010"],
        ".": ["000", "000", "000", "000", "010"],
        ",": ["000", "000", "000", "010", "100"],
        "'": ["010", "010", "000", "000", "000"],
        "-": ["000", "000", "111", "000", "000"],
        "~": ["010", "010", "111", "111", "111"], // water droplet
    ]

    private static let fallback = ["111", "101", "101", "101", "111"] // box for unknowns

    static func rows(for character: Character) -> [String] {
        let key = Character(character.uppercased())
        return glyphs[key] ?? fallback
    }

    /// Width in art-pixels of a rendered string (glyphs + spacing between them).
    static func widthInPixels(_ text: String) -> Int {
        let n = text.count
        guard n > 0 else { return 0 }
        return n * glyphWidth + (n - 1) * spacing
    }
}
