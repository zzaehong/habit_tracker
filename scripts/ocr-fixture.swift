import AppKit
let image = NSImage(size: NSSize(width: 800, height: 700))
image.lockFocus()
NSColor.white.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 800, height: 700)).fill()
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 38), .foregroundColor: NSColor.black]
let lines = ["Distance 5.00 km", "Time 32:00", "Heart Rate 145 bpm", "Cadence 176 spm", "Pace 6:24 /km"]
for (i, line) in lines.enumerated() { (line as NSString).draw(at: NSPoint(x: 50, y: 600 - i * 100), withAttributes: attrs) }
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "runtime/ocr-fixture.png"))
