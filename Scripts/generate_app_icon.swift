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

// A warm, softly luminous orb on the same near-black base as the UI.
context.saveGState()
context.addPath(tilePath)
context.clip()
context.setFillColor(CGColor(red: 5 / 255, green: 3 / 255, blue: 3 / 255, alpha: 1))
context.fill(tileRect)

func drawGlow(center: CGPoint, radius: CGFloat, colors: [CGColor], stops: [CGFloat]) {
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: stops) else { return }
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: []
    )
}

drawGlow(
    center: CGPoint(x: 468, y: 592), radius: 460,
    colors: [
        CGColor(red: 0.78, green: 0.48, blue: 0.24, alpha: 0.68),
        CGColor(red: 0.48, green: 0.18, blue: 0.11, alpha: 0.35),
        CGColor(red: 0.48, green: 0.18, blue: 0.11, alpha: 0)
    ],
    stops: [0, 0.42, 1]
)
drawGlow(
    center: CGPoint(x: 512, y: 524), radius: 272,
    colors: [
        CGColor(red: 0.96, green: 0.85, blue: 0.68, alpha: 1),
        CGColor(red: 0.84, green: 0.60, blue: 0.35, alpha: 0.98),
        CGColor(red: 0.78, green: 0.42, blue: 0.23, alpha: 0.72),
        CGColor(red: 0.48, green: 0.18, blue: 0.11, alpha: 0)
    ],
    stops: [0, 0.46, 0.78, 1]
)
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
