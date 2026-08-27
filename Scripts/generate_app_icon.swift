import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let canvasSize = 1024

private func bigEndianData(_ value: Int) -> Data {
    var encoded = UInt32(value).bigEndian
    return Data(bytes: &encoded, count: MemoryLayout<UInt32>.size)
}

private func packageIconset(at iconsetURL: URL, outputURL: URL) throws {
    let representations: [(type: String, filename: String)] = [
        ("icp4", "icon_16x16.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("icp5", "icon_32x32.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic08", "icon_256x256.png"),
        ("ic14", "icon_256x256@2x.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png")
    ]

    var body = Data()
    for representation in representations {
        let imageURL = iconsetURL.appendingPathComponent(representation.filename)
        let imageData = try Data(contentsOf: imageURL)
        body.append(contentsOf: representation.type.utf8)
        body.append(bigEndianData(imageData.count + 8))
        body.append(imageData)
    }

    var icns = Data("icns".utf8)
    icns.append(bigEndianData(body.count + 8))
    icns.append(body)
    try icns.write(to: outputURL, options: .atomic)
}

if CommandLine.arguments.count == 4,
   CommandLine.arguments[1] == "--package-iconset" {
    do {
        try packageIconset(
            at: URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true),
            outputURL: URL(fileURLWithPath: CommandLine.arguments[3])
        )
        exit(0)
    } catch {
        fputs("Could not package the iconset: \(error)\n", stderr)
        exit(1)
    }
}

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate_app_icon <output.png>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: nil,
    width: canvasSize,
    height: canvasSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Could not create the icon drawing context.\n", stderr)
    exit(1)
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let tileRect = CGRect(x: 48, y: 48, width: 928, height: 928)
let tilePath = CGPath(
    roundedRect: tileRect,
    cornerWidth: 224,
    cornerHeight: 224,
    transform: nil
)

let graphiteColors = [
    CGColor(red: 0.20, green: 0.22, blue: 0.25, alpha: 1),
    CGColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
] as CFArray

guard let graphiteGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: graphiteColors,
    locations: [0, 1]
) else {
    fputs("Could not create the icon gradient.\n", stderr)
    exit(1)
}

context.saveGState()
context.addPath(tilePath)
context.clip()
context.drawLinearGradient(
    graphiteGradient,
    start: CGPoint(x: 160, y: 864),
    end: CGPoint(x: 864, y: 160),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)
context.restoreGState()

context.addPath(tilePath)
context.setStrokeColor(CGColor(gray: 1, alpha: 0.10))
context.setLineWidth(10)
context.strokePath()

let eyePath = CGMutablePath()
eyePath.move(to: CGPoint(x: 214, y: 512))
eyePath.addCurve(
    to: CGPoint(x: 810, y: 512),
    control1: CGPoint(x: 340, y: 704),
    control2: CGPoint(x: 684, y: 704)
)
eyePath.addCurve(
    to: CGPoint(x: 214, y: 512),
    control1: CGPoint(x: 684, y: 320),
    control2: CGPoint(x: 340, y: 320)
)

let white = CGColor(gray: 1, alpha: 0.96)
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -8),
    blur: 22,
    color: CGColor(gray: 1, alpha: 0.22)
)
context.addPath(eyePath)
context.setStrokeColor(white)
context.setLineWidth(54)
context.setLineJoin(.round)
context.setLineCap(.round)
context.strokePath()

context.setFillColor(white)
context.fillEllipse(in: CGRect(x: 414, y: 414, width: 196, height: 196))
context.restoreGState()

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
          outputURL as CFURL,
          UTType.png.identifier as CFString,
          1,
          nil
      ) else {
    fputs("Could not create the output image.\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Could not write \(outputURL.path).\n", stderr)
    exit(1)
}
