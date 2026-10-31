import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("Usage: generate-app-icon.swift <iconset-directory> <preview-png>\n", stderr)
    exit(EXIT_FAILURE)
}

let iconsetURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
let previewURL = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func render(size: Int) throws -> CGImage {
    guard let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "SubtitleConverter.Icon", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to allocate \(size)px icon canvas."])
    }

    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 180, cornerHeight: 180, transform: nil)
    context.addPath(tilePath)
    context.setFillColor(CGColor(red: 10 / 255, green: 132 / 255, blue: 1, alpha: 1))
    context.fillPath()
    context.addPath(tilePath)
    context.clip()

    let rearPageColor = CGColor(red: 0.80, green: 0.89, blue: 1, alpha: 1)
    let foldColor = CGColor(red: 0.90, green: 0.95, blue: 1, alpha: 1)
    let blue = CGColor(red: 10 / 255, green: 132 / 255, blue: 1, alpha: 1)
    let white = CGColor(gray: 1, alpha: 1)
    let orange = CGColor(red: 1, green: 168 / 255, blue: 38 / 255, alpha: 1)

    context.saveGState()
    context.translateBy(x: 394, y: 478)
    context.rotate(by: -.pi / 15)
    let rearPage = CGPath(
        roundedRect: CGRect(x: -164, y: -235, width: 328, height: 470),
        cornerWidth: 42,
        cornerHeight: 42,
        transform: nil
    )
    context.addPath(rearPage)
    context.setFillColor(rearPageColor)
    context.fillPath()
    context.restoreGState()

    let page = CGMutablePath()
    page.move(to: CGPoint(x: 407, y: 306))
    page.addLine(to: CGPoint(x: 646, y: 306))
    page.addLine(to: CGPoint(x: 734, y: 394))
    page.addLine(to: CGPoint(x: 734, y: 702))
    page.addQuadCurve(to: CGPoint(x: 696, y: 740), control: CGPoint(x: 734, y: 740))
    page.addLine(to: CGPoint(x: 406, y: 740))
    page.addQuadCurve(to: CGPoint(x: 368, y: 702), control: CGPoint(x: 368, y: 740))
    page.addLine(to: CGPoint(x: 368, y: 344))
    page.addQuadCurve(to: CGPoint(x: 406, y: 306), control: CGPoint(x: 368, y: 306))
    page.closeSubpath()
    context.addPath(page)
    context.setFillColor(white)
    context.fillPath()

    let foldedCorner = CGMutablePath()
    foldedCorner.move(to: CGPoint(x: 646, y: 306))
    foldedCorner.addLine(to: CGPoint(x: 734, y: 394))
    foldedCorner.addLine(to: CGPoint(x: 678, y: 394))
    foldedCorner.addQuadCurve(to: CGPoint(x: 646, y: 362), control: CGPoint(x: 646, y: 394))
    foldedCorner.closeSubpath()
    context.addPath(foldedCorner)
    context.setFillColor(foldColor)
    context.fillPath()

    func stroke(_ path: CGPath, color: CGColor, width: CGFloat) {
        context.addPath(path)
        context.setStrokeColor(color)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
    }

    let subtitleLines: [(CGFloat, CGFloat, CGFloat)] = [(432, 664, 458), (432, 615, 516), (432, 565, 574)]
    for (startX, endX, y) in subtitleLines {
        let line = CGMutablePath()
        line.move(to: CGPoint(x: startX, y: y))
        line.addLine(to: CGPoint(x: endX, y: y))
        stroke(line, color: blue, width: 28)
    }

    context.beginPath()
    context.addEllipse(in: CGRect(x: 608, y: 576, width: 204, height: 204))
    context.setFillColor(orange)
    context.fillPath()

    let upperArrow = CGMutablePath()
    upperArrow.move(to: CGPoint(x: 657, y: 666))
    upperArrow.addCurve(
        to: CGPoint(x: 754, y: 658),
        control1: CGPoint(x: 657, y: 617),
        control2: CGPoint(x: 719, y: 608)
    )
    stroke(upperArrow, color: white, width: 22)
    let upperHead = CGMutablePath()
    upperHead.move(to: CGPoint(x: 753, y: 658))
    upperHead.addLine(to: CGPoint(x: 727, y: 632))
    upperHead.move(to: CGPoint(x: 753, y: 658))
    upperHead.addLine(to: CGPoint(x: 728, y: 682))
    stroke(upperHead, color: white, width: 22)

    let lowerArrow = CGMutablePath()
    lowerArrow.move(to: CGPoint(x: 762, y: 694))
    lowerArrow.addCurve(
        to: CGPoint(x: 657, y: 702),
        control1: CGPoint(x: 759, y: 741),
        control2: CGPoint(x: 692, y: 748)
    )
    stroke(lowerArrow, color: white, width: 22)
    let lowerHead = CGMutablePath()
    lowerHead.move(to: CGPoint(x: 657, y: 702))
    lowerHead.addLine(to: CGPoint(x: 682, y: 728))
    lowerHead.move(to: CGPoint(x: 657, y: 702))
    lowerHead.addLine(to: CGPoint(x: 682, y: 677))
    stroke(lowerHead, color: white, width: 22)

    guard let image = context.makeImage() else {
        throw NSError(domain: "SubtitleConverter.Icon", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to render \(size)px icon."])
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        throw NSError(domain: "SubtitleConverter.Icon", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to create PNG at \(url.path)."])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "SubtitleConverter.Icon", code: 4,
                      userInfo: [NSLocalizedDescriptionKey: "Unable to write PNG at \(url.path)."])
    }
}

let preview = try render(size: 1024)
try writePNG(preview, to: previewURL)

let iconVariants = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in iconVariants {
    try writePNG(render(size: size), to: iconsetURL.appendingPathComponent(name))
}

print("Created transparent 1024px preview and \(iconVariants.count) iconset images.")
