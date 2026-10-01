import AppKit
import Foundation
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let silhouette = NSBezierPath(roundedRect: NSRect(x: 20, y: 20, width: 984, height: 984), xRadius: 215, yRadius: 215)
let gradient = NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.25, blue: 0.69, alpha: 1),
                          ending: NSColor(calibratedRed: 0.28, green: 0.60, blue: 0.96, alpha: 1))!
gradient.draw(in: silhouette, angle: 90)
NSColor(calibratedWhite: 0.98, alpha: 1).set()
let pad = NSBezierPath(roundedRect: NSRect(x: 210, y: 282, width: 604, height: 460), xRadius: 100, yRadius: 100)
pad.lineWidth = 30
pad.stroke()
for x in [390.0, 560.0] {
    NSBezierPath(roundedRect: NSRect(x: x, y: 475, width: 74, height: 130), xRadius: 37, yRadius: 37).fill()
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
