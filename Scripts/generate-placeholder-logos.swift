#!/usr/bin/env swift
// Generates placeholder logo PNGs at project-root /Resources.
//
//   Resources/MenuBarIcon.png   — 54×54, pure black on transparent (template)
//   Resources/AppIcon.png       — 1024×1024, white silhouette on gradient
//
// Replace these two files with your own designs and re-run ./Scripts/make-app.sh.

import AppKit
import CoreGraphics
import Foundation

let projectRoot: String = {
    // CWD when invoked via make-app.sh
    let cwd = FileManager.default.currentDirectoryPath
    return cwd
}()
let resourcesDir = "\(projectRoot)/Resources"
try? FileManager.default.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)

// MARK: - Drawing helpers

func newBitmap(_ size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 32
    )!
    rep.size = CGSize(width: s, height: s)
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) throws {
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: path))
}

/// Draws a stylized head + bidirectional arrows.
func drawGlyph(in rect: CGRect, color: NSColor, lineRatio: CGFloat = 0.07) {
    let s = rect.width
    let cx = rect.midX
    let cy = rect.midY
    let lw = s * lineRatio

    let head = s * 0.20
    let armLen = s * 0.16
    let arrowH = s * 0.07
    let gap = lw * 1.5

    color.setStroke()
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setLineWidth(lw)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Head circle
    ctx.strokeEllipse(in: CGRect(x: cx - head, y: cy - head, width: head * 2, height: head * 2))

    // Left arm
    let leftStart = cx - head - gap
    let leftTip = leftStart - armLen
    ctx.move(to: CGPoint(x: leftStart, y: cy))
    ctx.addLine(to: CGPoint(x: leftTip, y: cy))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: leftTip + arrowH, y: cy + arrowH))
    ctx.addLine(to: CGPoint(x: leftTip, y: cy))
    ctx.addLine(to: CGPoint(x: leftTip + arrowH, y: cy - arrowH))
    ctx.strokePath()

    // Right arm
    let rightStart = cx + head + gap
    let rightTip = rightStart + armLen
    ctx.move(to: CGPoint(x: rightStart, y: cy))
    ctx.addLine(to: CGPoint(x: rightTip, y: cy))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: rightTip - arrowH, y: cy + arrowH))
    ctx.addLine(to: CGPoint(x: rightTip, y: cy))
    ctx.addLine(to: CGPoint(x: rightTip - arrowH, y: cy - arrowH))
    ctx.strokePath()
}

// MARK: - Menu bar icon (54×54 black template)

func renderMenuBar() throws {
    let rep = newBitmap(54)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawGlyph(in: CGRect(x: 0, y: 0, width: 54, height: 54), color: .black, lineRatio: 0.075)
    NSGraphicsContext.restoreGraphicsState()
    try writePNG(rep, to: "\(resourcesDir)/MenuBarIcon.png")
}

// MARK: - App icon (1024×1024 color)

func renderAppIcon() throws {
    let size = 1024
    let s = CGFloat(size)
    let rep = newBitmap(size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Inner safe area (~80% of canvas) for the rounded-square content.
    let inset = s * 0.10
    let bg = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = bg.width * 0.225
    let path = CGPath(roundedRect: bg, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Gradient background (indigo → magenta, top-left to bottom-right)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(srgbRed: 0.30, green: 0.18, blue: 0.86, alpha: 1.0),
        CGColor(srgbRed: 0.85, green: 0.30, blue: 0.78, alpha: 1.0)
    ] as CFArray
    let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: bg.minX, y: bg.maxY),
        end: CGPoint(x: bg.maxX, y: bg.minY),
        options: []
    )
    ctx.restoreGState()

    // White glyph centered inside the safe area
    drawGlyph(in: bg.insetBy(dx: bg.width * 0.10, dy: bg.height * 0.10),
              color: .white, lineRatio: 0.06)

    NSGraphicsContext.restoreGraphicsState()
    try writePNG(rep, to: "\(resourcesDir)/AppIcon.png")
}

try renderMenuBar()
try renderAppIcon()

print("Generated:")
print("  \(resourcesDir)/MenuBarIcon.png")
print("  \(resourcesDir)/AppIcon.png")
