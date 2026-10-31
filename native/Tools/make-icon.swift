// Draws the app icon master (1024x1024 PNG): a dark rounded square with a gauge ring and the fan rotor
// from the UI. Run through Tools/make-icon.sh, which also builds AppIcon.icns.
import AppKit

let size = 1024
guard CommandLine.arguments.count > 1 else { print("usage: make-icon.swift OUT.png"); exit(2) }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

// Body: Apple's icon grid (824 px square inside the 1024 canvas, continuous-looking corners).
let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 190, yRadius: 190)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
color(0x0b1220).setFill(); body.fill()
NSGraphicsContext.restoreGraphicsState()
body.addClip()
NSGradient(colors: [color(0x22345c), color(0x0b1220)])!.draw(in: body.bounds, angle: -90)
NSGradient(colors: [color(0x3b82f6, 0.30), color(0x3b82f6, 0)])!.draw(fromCenter: NSPoint(x: 512, y: 560), radius: 0, toCenter: NSPoint(x: 512, y: 560), radius: 430, options: [])

// Gauge ring: faint track plus a green arc (a bit more than two thirds, from the top, clockwise).
let center = NSPoint(x: 512, y: 512)
func ring(_ radius: CGFloat, from: CGFloat, to: CGFloat, width: CGFloat, _ c: NSColor, round: Bool = true) {
    let p = NSBezierPath()
    p.appendArc(withCenter: center, radius: radius, startAngle: from, endAngle: to, clockwise: true)
    p.lineWidth = width; p.lineCapStyle = round ? .round : .butt
    c.setStroke(); p.stroke()
}
ring(318, from: 90, to: 90 - 359.9, width: 30, color(0xffffff, 0.12), round: false)
ring(318, from: 90, to: 90 - 250, width: 30, color(0x34d399))

// Rotor: nine blades from the UI's SVG (100x100 box, y down), drawn at 5.7 px per unit around the center.
let scale: CGFloat = 5.7
let blade = NSBezierPath()
func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: (x - 50) * scale, y: -(y - 50) * scale) } // origin at the hub, y up
blade.move(to: pt(50, 50))
blade.curve(to: pt(46, 9), controlPoint1: pt(40, 38), controlPoint2: pt(36, 22))
blade.curve(to: pt(64, 14), controlPoint1: pt(54, 6), controlPoint2: pt(63, 9))
blade.curve(to: pt(50, 50), controlPoint1: pt(60, 28), controlPoint2: pt(58, 40))
blade.close()
for i in 0..<9 {
    NSGraphicsContext.saveGraphicsState()
    let xf = NSAffineTransform()
    xf.translateX(by: center.x, yBy: center.y)          // applied last: move the hub to the center
    xf.rotate(byDegrees: CGFloat(i) * 40 + 8)             // applied first: rotate around the hub
    let path = blade.copy() as! NSBezierPath
    path.transform(using: xf as AffineTransform)
    NSGradient(colors: [color(0x93c5fd), color(0x3b82f6)])!.draw(in: path, angle: 90 + CGFloat(i) * 40)
    color(0x0b1220, 0.55).setStroke(); path.lineWidth = 3; path.stroke()
    NSGraphicsContext.restoreGraphicsState()
}
// Hub
let hub = NSBezierPath(ovalIn: NSRect(x: center.x - 56, y: center.y - 56, width: 112, height: 112))
color(0x0b1220).setFill(); hub.fill()
let hubDot = NSBezierPath(ovalIn: NSRect(x: center.x - 38, y: center.y - 38, width: 76, height: 76))
color(0xf8fafc).setFill(); hubDot.fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
