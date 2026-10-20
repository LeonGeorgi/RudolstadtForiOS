import AppKit
import Foundation

// Render the compiled Apple icon assets offscreen. No app or simulator is launched.
let compiled = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let files = FileManager.default
let refined = CommandLine.arguments.dropFirst(3).contains("--refined")
let creative = CommandLine.arguments.dropFirst(3).contains("--creative")
let singleRow = refined || creative
let concepts = creative ? [
    ("10-festivalpass", "10 · Festivalpass"),
    ("11-festivalplan", "11 · Festivalplan"),
    ("12-festivalband", "12 · Festivalband")
] : refined ? [
    ("07-original-pur", "07 · Original pur"),
    ("08-ru-signet", "08 · ru Signet"),
    ("09-original-hell", "09 · Original hell")
] : [
    ("01-r-im-tanzkreis", "01 · r im Tanzkreis"),
    ("02-akkordeon-herz", "02 · Akkordeon-Herz"),
    ("03-mein-programm", "03 · Mein Programm"),
    ("04-programm-kompakt", "04 · Programm kompakt"),
    ("05-festivalband", "05 · Festivalband"),
    ("06-r-in-kupfer", "06 · r in Kupfer")
]

enum PreviewError: Error {
    case invalidBitmap, missingImage(String), missingAppearance, invalidPNG
}

func bitmap(width: Int, height: Int, scale: CGFloat = 1, draw: (CGFloat, CGFloat) throws -> Void) throws -> NSBitmapImageRep {
    guard let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(CGFloat(width) * scale), pixelsHigh: Int(CGFloat(height) * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: image) else {
        throw PreviewError.invalidBitmap
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.scaleBy(x: scale, y: scale)
    try draw(CGFloat(width), CGFloat(height))
    return image
}

func save(_ bitmap: NSBitmapImageRep, name: String) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else { throw PreviewError.invalidPNG }
    try data.write(to: output.appendingPathComponent(name))
}

func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, canvasHeight: CGFloat) -> CGRect {
    CGRect(x: x, y: canvasHeight - y - height, width: width, height: height)
}

func label(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, color: NSColor, centered: Bool = false, canvasHeight: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = centered ? .center : .left
    (text as NSString).draw(in: box(x, y, width, size * 1.5, canvasHeight: canvasHeight), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color, .paragraphStyle: paragraph
    ])
}

try files.createDirectory(at: output, withIntermediateDirectories: true)
guard let light = NSAppearance(named: .aqua) else { throw PreviewError.missingAppearance }
for (slug, _) in concepts {
    let folder = compiled.appendingPathComponent(slug, isDirectory: true)
    let bundleURL = folder.appendingPathComponent("Preview.bundle", isDirectory: true)
    let resources = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
    try files.createDirectory(at: resources, withIntermediateDirectories: true)
    let car = try Data(contentsOf: folder.appendingPathComponent("Assets.car"))
    try car.write(to: resources.appendingPathComponent("Assets.car"))
    let info: [String: String] = ["CFBundleIdentifier": "de.leongeorgi.IconConceptPreview." + slug, "CFBundleName": "Preview", "CFBundlePackageType": "BNDL", "CFBundleVersion": "1"]
    let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try plist.write(to: bundleURL.appendingPathComponent("Contents/Info.plist"))
    guard let bundle = Bundle(url: bundleURL), let icon = bundle.image(forResource: NSImage.Name(slug)) else {
        throw PreviewError.missingImage(slug)
    }
    let image = try bitmap(width: 1024, height: 1024) { width, height in
        light.performAsCurrentDrawingAppearance {
            icon.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
    try save(image, name: slug + "-light.png")
}

let overview = try bitmap(width: 960, height: singleRow ? 485 : 870, scale: 2) { width, height in
    NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
    CGRect(x: 0, y: 0, width: width, height: height).fill()
    let title = creative ? "Festivalmotive mit Originalschriftzug" : refined ? "Originalschriftzug · neue Entwürfe" : "Sechs native Festival-Icons"
    label(title, x: 40, y: 20, width: 880, size: 28, color: .black, canvasHeight: height)
    label("Große Vorschau und kleine Ansicht", x: 40, y: 57, width: 880, size: 15, color: .darkGray, canvasHeight: height)
    for (index, concept) in concepts.enumerated() {
        let x = CGFloat(index % 3) * 310 + 15
        let y = CGFloat(index / 3) * 385 + 80
        guard let icon = NSImage(contentsOf: output.appendingPathComponent(concept.0 + "-light.png")) else { throw PreviewError.missingImage(concept.0) }
        icon.draw(in: box(x + 35, y, 250, 250, canvasHeight: height))
        label(concept.1, x: x + 10, y: y + 252, width: 300, size: 18, color: .black, centered: true, canvasHeight: height)
        icon.draw(in: box(x + 122, y + 291, 76, 76, canvasHeight: height))
    }
    label("Apples nativer macOS-Export · Standarddarstellung · keine Texturen in den Vektorebenen", x: 40, y: height - 30, width: 880, size: 13, color: .darkGray, canvasHeight: height)
}
try save(overview, name: creative ? "festivalmotive-vergleich.png" : refined ? "originalschriftzug-vergleich.png" : "alle-sechs-native-icons.png")

let darkOverview = try bitmap(width: 960, height: 290, scale: 2) { width, height in
    NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
    CGRect(x: 0, y: 0, width: width, height: height).fill()
    label("Auf dunklem Hintergrund", x: 40, y: 20, width: 880, size: 24, color: .white, canvasHeight: height)
    for (index, concept) in concepts.enumerated() {
        let cellWidth = (width - 60) / CGFloat(concepts.count)
        let x = CGFloat(index) * cellWidth + 30 + (cellWidth - 150) / 2
        guard let icon = NSImage(contentsOf: output.appendingPathComponent(concept.0 + "-light.png")) else { throw PreviewError.missingImage(concept.0) }
        icon.draw(in: box(x, 84, 150, 150, canvasHeight: height))
        label(String(concept.0.prefix(2)), x: x, y: 238, width: 150, size: 16, color: .white, centered: true, canvasHeight: height)
    }
}
try save(darkOverview, name: creative ? "festivalmotive-dunkler-hintergrund.png" : refined ? "originalschriftzug-dunkler-hintergrund.png" : "alle-sechs-dunkler-hintergrund.png")
print("Exported \(concepts.count) native standard-appearance previews and two comparison sheets.")
