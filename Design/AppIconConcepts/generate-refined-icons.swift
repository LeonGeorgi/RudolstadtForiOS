import AppKit
import Foundation
import Vision

// Trace the app's actual lettering. Do not substitute a font or redraw its glyphs.
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let files = FileManager.default
enum ArtworkError: Error { case image, contours, selection }
guard let cg = NSImage(contentsOf: source)?.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let context = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ArtworkError.image }
context.setFillColor(CGColor(gray: 0, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
guard let image = context.makeImage() else { throw ArtworkError.image }
let request = VNDetectContoursRequest()
request.detectsDarkOnLight = false
request.maximumImageDimension = 2048
request.contrastAdjustment = 1
try VNImageRequestHandler(cgImage: image).perform([request])
guard let contours = request.results?.first, contours.topLevelContourCount == 10, contours.contourCount == 14 else { throw ArtworkError.contours }
let ruContours = contours.topLevelContours.filter {
    let bounds = $0.normalizedPath.boundingBoxOfPath
    return bounds.midY > 0.5 && bounds.maxX < 0.4
}
guard ruContours.count == 2 else { throw ArtworkError.selection }
let ru = CGMutablePath()
for contour in ruContours { ru.addPath(contour.normalizedPath) }

func number(_ n: CGFloat) -> String { String(format: "%.4f", Double(n)) }
func pathData(_ path: CGPath) -> String {
    var parts: [String] = []
    path.applyWithBlock { pointer in
        let e = pointer.pointee
        func p(_ i: Int) -> String { "\(number(e.points[i].x)),\(number(e.points[i].y))" }
        switch e.type {
        case .moveToPoint: parts.append("M\(p(0))")
        case .addLineToPoint: parts.append("L\(p(0))")
        case .addQuadCurveToPoint: parts.append("Q\(p(0)) \(p(1))")
        case .addCurveToPoint: parts.append("C\(p(0)) \(p(1)) \(p(2))")
        case .closeSubpath: parts.append("Z")
        @unknown default: break
        }
    }
    return parts.joined(separator: " ")
}

func save(_ name: String, title: String, outline: CGPath, maximumWidth: CGFloat, maximumHeight: CGFloat, color: String, background: String, specular: Bool) throws {
    let assets = output.appendingPathComponent(name + ".icon/Assets", isDirectory: true)
    try files.createDirectory(at: assets, withIntermediateDirectories: true)
    let bounds = outline.boundingBoxOfPath
    let scale = min(maximumWidth / bounds.width, maximumHeight / bounds.height)
    let x = (1024 - bounds.width * scale) / 2
    let y = (1024 - bounds.height * scale) / 2
    let transform = "translate(\(number(x)) \(number(y + bounds.height * scale))) scale(\(number(scale)) \(number(-scale))) translate(\(number(-bounds.minX)) \(number(-bounds.minY)))"
    let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\"><title>\(title): Originalkonturen</title><g transform=\"\(transform)\"><path fill=\"\(color)\" fill-rule=\"evenodd\" d=\"\(pathData(outline))\"/></g></svg>\n"
    try svg.write(to: assets.appendingPathComponent("Originalschriftzug.svg"), atomically: true, encoding: .utf8)
    let document: [String: Any] = [
        "fill": ["automatic-gradient": background],
        "groups": [[
            "name": title,
            "lighting": "combined", "specular": specular,
            "shadow": ["kind": "neutral", "opacity": 0.10],
            "translucency": ["enabled": true, "value": 0.15],
            "layers": [["name": "Originalschriftzug", "image-name": "Originalschriftzug.svg", "glass": true,
                        "position": ["scale": 1, "translation-in-points": [0, 0]]]]
        ]],
        "supported-platforms": ["squares": "shared"]
    ]
    let json = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: assets.deletingLastPathComponent().appendingPathComponent("icon.json"))
    print(name + ".icon: original glyph contours, no font substitution")
}

try save("07-original-pur", title: "07 · Original pur", outline: contours.normalizedPath, maximumWidth: 646, maximumHeight: 748, color: "#FFFFFF", background: "srgb:0.40000,0.14700,0.38900,1.00000", specular: false)
try save("08-ru-signet", title: "08 · ru Signet", outline: ru, maximumWidth: 636, maximumHeight: 668, color: "#FFFFFF", background: "srgb:0.28500,0.09000,0.33500,1.00000", specular: true)
try save("09-original-hell", title: "09 · Original hell", outline: contours.normalizedPath, maximumWidth: 646, maximumHeight: 748, color: "#702A70", background: "srgb:0.95000,0.94000,0.97000,1.00000", specular: false)
