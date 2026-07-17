import Foundation

/// A selectable reminder character. Each character owns its sprite sheets
/// (bundled under `Resources/Characters/<id>/`), frame counts, and frame
/// timings; all animation code reads these instead of hardcoded paths.
///
/// Note: this shadows `Swift.Character` inside the module — stdlib usages
/// (e.g. in `PixelFont`) are qualified as `Swift.Character`.
struct Character: Identifiable, Equatable {
    let id: String
    let displayName: String
    let walkFrameCount: Int
    let idleFrameCount: Int
    let walkFPS: Double
    let idleFPS: Double

    /// Bundle subdirectory holding this character's sheets.
    var resourceSubdirectory: String { "Characters/\(id)" }

    func walkSheet() -> SpriteSheet {
        SpriteSheet.fromResource(named: "walk", subdirectory: resourceSubdirectory,
                                 frameCount: walkFrameCount)
            ?? SpriteSheet.placeholder(frameCount: walkFrameCount, frameSize: 16)
    }

    func idleSheet() -> SpriteSheet {
        SpriteSheet.fromResource(named: "idle", subdirectory: resourceSubdirectory,
                                 frameCount: idleFrameCount)
            ?? SpriteSheet.placeholder(frameCount: idleFrameCount, frameSize: 16)
    }

    // MARK: - Roster

    /// The original pixel cat — the default, so existing users see no change.
    static let puddles = Character(
        id: "puddles", displayName: "Puddles",
        walkFrameCount: 4, idleFrameCount: 2,
        walkFPS: 8, idleFPS: 2
    )

    /// A bouncy purple-bat buddy.
    static let echo = Character(
        id: "echo", displayName: "Echo",
        walkFrameCount: 4, idleFrameCount: 2,
        walkFPS: 8, idleFPS: 2
    )

    static let all: [Character] = [.puddles, .echo]

    /// Sentinel stored in preferences meaning "pick randomly per reminder".
    static let surpriseID = "surprise"

    /// Resolves a persisted selection to a concrete character: "surprise"
    /// picks randomly per call, unknown ids fall back to the default.
    static func resolve(selectionID: String) -> Character {
        if selectionID == surpriseID {
            return all.randomElement() ?? .puddles
        }
        return all.first { $0.id == selectionID } ?? .puddles
    }
}
