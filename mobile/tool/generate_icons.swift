import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let icons = root.appendingPathComponent("assets/icon")
let launch = root.appendingPathComponent("ios/Runner/Assets.xcassets/LaunchImage.imageset")

let rgb = CGColorSpaceCreateDeviceRGB()

func silver(_ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: rgb, components: [0.76, 0.77, 0.79, alpha])!
}

func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        throw NSError(domain: "icons", code: 1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "icons", code: 2)
    }
}

func context(size: Int, opaque: Bool) -> CGContext {
    let info = opaque
        ? CGImageAlphaInfo.noneSkipLast.rawValue
        : CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: rgb,
        bitmapInfo: info
    ) else {
        fatalError("cannot create context")
    }
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    return ctx
}

func drawArt(_ ctx: CGContext, size: Int, scale: CGFloat) {
    let unit = CGFloat(size) / 1024.0
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
    ctx.scaleBy(x: unit * scale, y: unit * scale)
    ctx.translateBy(x: -512, y: -512)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    ctx.setStrokeColor(silver())
    ctx.setLineWidth(18)
    ctx.strokeEllipse(in: CGRect(x: 132, y: 132, width: 760, height: 760))

    ctx.setStrokeColor(silver(0.42))
    ctx.setLineWidth(4)
    ctx.strokeEllipse(in: CGRect(x: 172, y: 172, width: 680, height: 680))

    ctx.setStrokeColor(silver())
    ctx.setLineWidth(18)

    let triangle = CGMutablePath()
    triangle.move(to: CGPoint(x: 512, y: 247))
    triangle.addLine(to: CGPoint(x: 568, y: 367))
    triangle.addLine(to: CGPoint(x: 456, y: 367))
    triangle.closeSubpath()
    ctx.addPath(triangle)
    ctx.strokePath()

    ctx.strokeEllipse(in: CGRect(x: 657, y: 452, width: 120, height: 120))

    let cross = CGMutablePath()
    cross.move(to: CGPoint(x: 468, y: 673))
    cross.addLine(to: CGPoint(x: 556, y: 761))
    cross.move(to: CGPoint(x: 556, y: 673))
    cross.addLine(to: CGPoint(x: 468, y: 761))
    ctx.addPath(cross)
    ctx.strokePath()

    let square = CGPath(
        roundedRect: CGRect(x: 252, y: 457, width: 110, height: 110),
        cornerWidth: 10,
        cornerHeight: 10,
        transform: nil
    )
    ctx.addPath(square)
    ctx.strokePath()

    ctx.restoreGState()
}

func fullIcon() -> CGImage {
    let size = 1024
    let ctx = context(size: size, opaque: true)
    let gradient = CGGradient(
        colorsSpace: rgb,
        colors: [
            CGColor(colorSpace: rgb, components: [0.07, 0.09, 0.11, 1])!,
            CGColor(colorSpace: rgb, components: [0, 0, 0, 1])!,
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: 512, y: 470),
        startRadius: 30,
        endCenter: CGPoint(x: 512, y: 470),
        endRadius: 720,
        options: []
    )
    drawArt(ctx, size: size, scale: 1)
    return ctx.makeImage()!
}

func foregroundIcon() -> CGImage {
    let size = 1024
    let ctx = context(size: size, opaque: false)
    drawArt(ctx, size: size, scale: 0.78)
    return ctx.makeImage()!
}

func launchIcon(size: Int) -> CGImage {
    let ctx = context(size: size, opaque: false)
    drawArt(ctx, size: size, scale: 0.86)
    return ctx.makeImage()!
}

try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: launch, withIntermediateDirectories: true)

try write(fullIcon(), to: icons.appendingPathComponent("icon.png"))
try write(foregroundIcon(), to: icons.appendingPathComponent("icon_foreground.png"))
try write(launchIcon(size: 168), to: launch.appendingPathComponent("LaunchImage.png"))
try write(launchIcon(size: 336), to: launch.appendingPathComponent("LaunchImage@2x.png"))
try write(launchIcon(size: 504), to: launch.appendingPathComponent("LaunchImage@3x.png"))

print("icons written")
