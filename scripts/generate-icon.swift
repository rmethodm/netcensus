#!/usr/bin/env swift
import AppKit
import CoreGraphics

let size: CGFloat = 1024

func color(_ hex: String, alpha: CGFloat = 1) -> NSColor {
    var value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    if value.count == 3 {
        value = value.map { "\($0)\($0)" }.joined()
    }
    var int: UInt64 = 0
    Scanner(string: value).scanHexInt64(&int)
    let r = CGFloat((int >> 16) & 0xFF) / 255
    let g = CGFloat((int >> 8) & 0xFF) / 255
    let b = CGFloat(int & 0xFF) / 255
    return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func drawGradientBackground(_ ctx: CGContext, top: NSColor, bottom: NSColor) {
    let colors = [top.cgColor, bottom.cgColor] as CFArray
    let space = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: size / 2, y: 0),
        end: CGPoint(x: size / 2, y: size),
        options: []
    )
}

func drawRadialGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: NSColor) {
    let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
    let space = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
    ctx.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: []
    )
}

func drawLine(_ ctx: CGContext, from: CGPoint, to: CGPoint, color: NSColor, width: CGFloat) {
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.move(to: from)
    ctx.addLine(to: to)
    ctx.strokePath()
}

func drawNode(_ ctx: CGContext, center: CGPoint, radius: CGFloat, fill: NSColor, stroke: NSColor) {
    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    ctx.setFillColor(fill.cgColor)
    ctx.fillEllipse(in: rect)
    ctx.setStrokeColor(stroke.cgColor)
    ctx.setLineWidth(max(radius * 0.18, 8))
    ctx.strokeEllipse(in: rect.insetBy(dx: 4, dy: 4))
}

struct Variant {
    var name: String
    var top: String
    var bottom: String
    var glow: String
    var line: String
    var node: String
    var accent: String
    var stroke: String
}

func render(_ variant: Variant) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    drawGradientBackground(ctx, top: color(variant.top), bottom: color(variant.bottom))
    let center = CGPoint(x: size / 2, y: size / 2)
    drawRadialGlow(ctx, center: center, radius: 420, color: color(variant.glow, alpha: 0.35))

    let topNode = CGPoint(x: 512, y: 710)
    let left = CGPoint(x: 250, y: 430)
    let right = CGPoint(x: 774, y: 430)
    let bottom = CGPoint(x: 512, y: 250)
    let hub = CGPoint(x: 512, y: 490)

    let lineColor = color(variant.line)
    let width: CGFloat = 42
    drawLine(ctx, from: hub, to: topNode, color: lineColor, width: width)
    drawLine(ctx, from: hub, to: left, color: lineColor, width: width)
    drawLine(ctx, from: hub, to: right, color: lineColor, width: width)
    drawLine(ctx, from: hub, to: bottom, color: lineColor, width: width)

    let nodeFill = color(variant.node)
    let stroke = color(variant.stroke)
    drawNode(ctx, center: topNode, radius: 78, fill: nodeFill, stroke: stroke)
    drawNode(ctx, center: left, radius: 78, fill: nodeFill, stroke: stroke)
    drawNode(ctx, center: right, radius: 78, fill: nodeFill, stroke: stroke)
    drawNode(ctx, center: bottom, radius: 78, fill: nodeFill, stroke: stroke)
    drawNode(ctx, center: hub, radius: 110, fill: color(variant.accent), stroke: stroke)

    image.unlockFocus()
    return image
}

func pngData(_ image: NSImage) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let variants = [
    Variant(
        name: "light",
        top: "1A4A6B",
        bottom: "0A1628",
        glow: "5AC8FA",
        line: "8FD3F4",
        node: "E8F4FC",
        accent: "34C759",
        stroke: "0A1628"
    ),
    Variant(
        name: "dark",
        top: "122033",
        bottom: "070B12",
        glow: "1A4A6B",
        line: "3D7EA6",
        node: "C5D9E8",
        accent: "30D158",
        stroke: "05070B"
    ),
    Variant(
        name: "tinted",
        top: "2C2C2E",
        bottom: "1C1C1E",
        glow: "8E8E93",
        line: "C7C7CC",
        node: "F2F2F7",
        accent: "FFFFFF",
        stroke: "1C1C1E"
    ),
]

let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("icon-variants", isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for variant in variants {
    let data = pngData(render(variant))
    let url = outDir.appendingPathComponent("icon_\(variant.name).png")
    try data.write(to: url)
    print("wrote \(url.path)")
}
