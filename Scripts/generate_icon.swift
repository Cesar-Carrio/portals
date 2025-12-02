import AppKit
import CoreGraphics

let size: CGFloat = 1024
let center = CGPoint(x: size / 2, y: size / 2)
let rect = CGRect(x: 0, y: 0, width: size, height: size)

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let context = NSGraphicsContext.current!.cgContext
context.saveGState()

// Background: deep night gradient with a subtle radial glow.
let backgroundGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedRed: 0.04, green: 0.07, blue: 0.16, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.06, green: 0.12, blue: 0.26, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.12, alpha: 1).cgColor
    ] as CFArray,
    locations: [0.0, 0.55, 1.0]
)!
context.drawRadialGradient(
    backgroundGradient,
    startCenter: center,
    startRadius: 40,
    endCenter: center,
    endRadius: size / 1.1,
    options: [.drawsAfterEndLocation]
)

// Add angled light sweep.
let sweepGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedRed: 0.14, green: 0.45, blue: 0.96, alpha: 0.18).cgColor,
        NSColor(calibratedRed: 0.07, green: 0.85, blue: 0.75, alpha: 0.12).cgColor,
        NSColor.clear.cgColor
    ] as CFArray,
    locations: [0, 0.6, 1]
)!
context.saveGState()
context.concatenate(CGAffineTransform(a: 1, b: 0, c: 0.18, d: 1, tx: 0, ty: 0))
context.drawLinearGradient(
    sweepGradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: 0, y: size * 1.1),
    options: [.drawsAfterEndLocation]
)
context.restoreGState()

func drawRing(rect: CGRect, lineWidth: CGFloat, startColor: NSColor, endColor: NSColor, glow: NSColor?) {
    let path = NSBezierPath(ovalIn: rect)
    let cgPath = path.cgPath

    if let glow = glow {
        context.saveGState()
        context.setShadow(offset: .zero, blur: lineWidth * 1.2, color: glow.withAlphaComponent(0.55).cgColor)
        context.addPath(cgPath)
        context.setLineWidth(lineWidth)
        context.setStrokeColor(glow.cgColor)
        context.strokePath()
        context.restoreGState()
    }

    context.saveGState()
    context.addPath(cgPath)
    context.setLineWidth(lineWidth)
    context.replacePathWithStrokedPath()
    context.clip()

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [startColor.cgColor, endColor.cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )
    context.restoreGState()
}

let outerRect = rect.insetBy(dx: 130, dy: 130)
let middleRect = rect.insetBy(dx: 210, dy: 210)
let innerRect = rect.insetBy(dx: 285, dy: 285)

drawRing(
    rect: outerRect,
    lineWidth: 42,
    startColor: NSColor(calibratedRed: 0.16, green: 0.85, blue: 0.95, alpha: 1),
    endColor: NSColor(calibratedRed: 0.36, green: 0.62, blue: 0.98, alpha: 1),
    glow: NSColor(calibratedRed: 0.12, green: 0.64, blue: 0.95, alpha: 1)
)

drawRing(
    rect: middleRect,
    lineWidth: 32,
    startColor: NSColor(calibratedRed: 0.09, green: 0.92, blue: 0.79, alpha: 1),
    endColor: NSColor(calibratedRed: 0.18, green: 0.73, blue: 0.96, alpha: 1),
    glow: NSColor(calibratedRed: 0.07, green: 0.8, blue: 0.86, alpha: 0.9)
)

drawRing(
    rect: innerRect,
    lineWidth: 24,
    startColor: NSColor(calibratedRed: 0.42, green: 0.93, blue: 0.91, alpha: 1),
    endColor: NSColor(calibratedRed: 0.42, green: 0.69, blue: 0.98, alpha: 1),
    glow: NSColor(calibratedRed: 0.3, green: 0.88, blue: 0.95, alpha: 0.7)
)

// Energy strokes that arc across the portal.
func energyArc(startAngle: CGFloat, endAngle: CGFloat, radius: CGFloat, width: CGFloat, color: NSColor, blur: CGFloat) {
    let arcPath = NSBezierPath()
    arcPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
    context.saveGState()
    context.setShadow(offset: .zero, blur: blur, color: color.withAlphaComponent(0.7).cgColor)
    context.addPath(arcPath.cgPath)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setStrokeColor(color.cgColor)
    context.strokePath()
    context.restoreGState()
}

energyArc(startAngle: 200, endAngle: 330, radius: 240, width: 14, color: NSColor(calibratedRed: 0.17, green: 0.98, blue: 0.86, alpha: 1), blur: 18)
energyArc(startAngle: 40, endAngle: 160, radius: 190, width: 10, color: NSColor(calibratedRed: 0.39, green: 0.77, blue: 0.99, alpha: 1), blur: 12)
energyArc(startAngle: -30, endAngle: 70, radius: 300, width: 8, color: NSColor(calibratedRed: 0.12, green: 0.86, blue: 0.94, alpha: 1), blur: 14)

// Center iris.
let irisGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedRed: 0.1, green: 0.65, blue: 0.94, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.07, green: 0.24, blue: 0.48, alpha: 1).cgColor
    ] as CFArray,
    locations: [0, 1]
)!
let irisRect = rect.insetBy(dx: 360, dy: 360)
context.saveGState()
context.addEllipse(in: irisRect)
context.clip()
context.drawRadialGradient(
    irisGradient,
    startCenter: center,
    startRadius: 10,
    endCenter: center,
    endRadius: irisRect.width / 1.7,
    options: []
)
context.restoreGState()

// Subtle grid hint behind the portal edges.
context.saveGState()
context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.04).cgColor)
let spacing: CGFloat = 64
for i in stride(from: spacing / 2, through: size, by: spacing) {
    context.setLineWidth(1)
    context.move(to: CGPoint(x: i, y: 0))
    context.addLine(to: CGPoint(x: i, y: size))
    context.move(to: CGPoint(x: 0, y: i))
    context.addLine(to: CGPoint(x: size, y: i))
}
context.strokePath()
context.restoreGState()

// Accent particles.
let particleColor = NSColor(calibratedRed: 0.61, green: 0.92, blue: 0.99, alpha: 0.9)
for _ in 0..<22 {
    let angle = CGFloat.random(in: 0..<(2 * .pi))
    let radius = CGFloat.random(in: 140...330)
    let point = CGPoint(
        x: center.x + cos(angle) * radius,
        y: center.y + sin(angle) * radius
    )
    let size = CGFloat.random(in: 5...11)
    let particleRect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
    context.saveGState()
    context.setShadow(offset: .zero, blur: size * 1.8, color: particleColor.withAlphaComponent(0.9).cgColor)
    context.setFillColor(particleColor.cgColor)
    context.fillEllipse(in: particleRect)
    context.restoreGState()
}

context.restoreGState()
image.unlockFocus()

let outputURL = URL(fileURLWithPath: "Assets/AppIconBase.png")
try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render icon")
}

do {
    try data.write(to: outputURL)
    print("Wrote base icon to \(outputURL.path)")
} catch {
    fatalError("Could not write icon: \(error)")
}
