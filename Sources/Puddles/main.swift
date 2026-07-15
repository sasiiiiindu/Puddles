import AppKit

// Puddles — a menu bar water-drinking reminder with a pixel-art cat.
// Entry point: create the shared application, install our delegate, and run.
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no dock icon; belt-and-suspenders with LSUIElement

let delegate = AppDelegate()
app.delegate = delegate
app.run()
