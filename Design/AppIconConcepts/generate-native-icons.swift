import AppKit
import CoreText
import Foundation

// Design sources only. This script does not modify the app target or its active icon.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let files = FileManager.default
let cream = "#FFF1D1"
let copper = "#E97920"
let plum = "#622368"

func number(_ value: CGFloat) -> String {
    String(format: "%.2f", Double(value))
}

func svgPath(_ path: CGPath) -> String {
    var commands: [String] = []
    path.applyWithBlock { pointer in
        let element = pointer.pointee
        func point(_ index: Int) -> String {
            "\(number(element.points[index].x)) \(number(element.points[index].y))"
        }
        switch element.type {
        case .moveToPoint: commands.append("M\(point(0))")
        case .addLineToPoint: commands.append("L\(point(0))")
        case .addQuadCurveToPoint: commands.append("Q\(point(0)) \(point(1))")
        case .addCurveToPoint: commands.append("C\(point(0)) \(point(1)) \(point(2))")
        case .closeSubpath: commands.append("Z")
        @unknown default: break
        }
    }
    return commands.joined(separator: " ")
}

func word(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: String) -> String {
    let font = CTFontCreateWithName("DINCondensed-Bold" as CFString, 200, nil)
    precondition(CTFontCopyPostScriptName(font) as String == "DINCondensed-Bold")
    let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
    let line = CTLineCreateWithAttributedString(attributed)
    let outline = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        for index in 0..<count {
            guard let glyph = CTFontCreatePathForGlyph(font, glyphs[index], nil) else {
                preconditionFailure("Missing glyph in \(text)")
            }
            outline.addPath(glyph, transform: CGAffineTransform(translationX: positions[index].x, y: positions[index].y))
        }
    }
    let bounds = outline.boundingBoxOfPath
    return "<g transform=\"translate(\(number(x)) \(number(y + height))) scale(\(number(width / bounds.width)) \(number(-height / bounds.height))) translate(\(number(-bounds.minX)) \(number(-bounds.minY)))\"><path fill=\"\(color)\" d=\"\(svgPath(outline))\"/></g>"
}

func square(_ x: Int, _ y: Int, size: Int = 74, angle: Int = 18, color: String = copper) -> String {
    "<rect x=\"\(x - size / 2)\" y=\"\(y - size / 2)\" width=\"\(size)\" height=\"\(size)\" rx=\"10\" fill=\"\(color)\" transform=\"rotate(\(angle) \(x) \(y))\"/>"
}

func rect(_ x: Int, _ y: Int, _ width: Int, _ height: Int, radius: Int = 12, color: String) -> String {
    "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" rx=\"\(radius)\" fill=\"\(color)\"/>"
}

struct Layer {
    let name: String
    let artwork: String
}

struct Group {
    let name: String
    let layers: [Layer]
    var translucency: Double = 0.12
}

func save(_ name: String, title: String, groups: [Group], lightBackground: Bool = false) throws {
    let package = output.appendingPathComponent(name + ".icon", isDirectory: true)
    let assets = package.appendingPathComponent("Assets", isDirectory: true)
    try files.createDirectory(at: assets, withIntermediateDirectories: true)
    var groupJSON: [[String: Any]] = []
    for (groupIndex, group) in groups.enumerated() {
        var layers: [[String: Any]] = []
        for (layerIndex, layer) in group.layers.enumerated() {
            let filename = String(format: "%02d-%02d-", groupIndex + 1, layerIndex + 1) + layer.name + ".svg"
            let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\"><title>\(title): \(layer.name)</title>\(layer.artwork)</svg>\n"
            try svg.write(to: assets.appendingPathComponent(filename), atomically: true, encoding: .utf8)
            layers.append([
                "name": layer.name, "image-name": filename, "blend-mode": "normal", "glass": true,
                "position": ["scale": 1.0, "translation-in-points": [0, 0]]
            ])
        }
        groupJSON.append([
            "name": group.name, "layers": Array(layers.reversed()),
            "shadow": ["kind": "neutral", "opacity": 0.22],
            "translucency": ["enabled": true, "value": group.translucency]
        ])
    }
    let background = lightBackground ? "srgb:0.94000,0.89400,0.82000,1.00000" : "srgb:0.35500,0.10500,0.39100,1.00000"
    let json: [String: Any] = [
        // Icon Composer stores the frontmost group first in its sidebar.
        "fill": ["automatic-gradient": background], "groups": Array(groupJSON.reversed()),
        "supported-platforms": ["squares": "shared"]
    ]
    let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: package.appendingPathComponent("icon.json"))
    print(name + ".icon")
}

let r = "M306 824 Q282 824 282 800 V334 Q282 246 370 232 L520 208 Q555 202 555 238 V310 Q555 342 520 347 L452 360 Q423 366 423 398 V800 Q423 825 399 829 Z"
let orbit = [(666, 245, -28), (785, 365, 18), (824, 520, 12), (782, 677, 29), (665, 792, -28)]
try save("01-r-im-tanzkreis", title: "r im Tanzkreis", groups: [
    Group(name: "01 Schriftzeichen", layers: [Layer(name: "r", artwork: "<path fill=\"\(cream)\" d=\"\(r)\"/>")]),
    Group(name: "02 Festivalbogen", layers: [Layer(name: "Quadrate", artwork: orbit.map { square($0.0, $0.1, angle: $0.2) }.joined())])
])

let bellows = "<path fill=\"\(cream)\" fill-rule=\"evenodd\" d=\"M282 377 Q332 312 383 354 L512 418 L641 354 Q692 312 742 377 L700 663 L512 800 L324 663 Z M366 357 L387 366 L459 755 L436 738 Z M456 390 L478 401 L507 791 L486 775 Z M546 401 L568 390 L538 775 L517 791 Z M637 366 L658 357 L588 738 L565 755 Z\"/>"
let endboards = "<g transform=\"rotate(-14 262 531)\">\(rect(178, 359, 146, 340, radius: 26, color: copper))</g><g transform=\"rotate(14 762 531)\">\(rect(700, 359, 146, 340, radius: 26, color: copper))</g>"
let buttons = [420, 478, 536, 594, 652].map { y in
    "<circle cx=\"246\" cy=\"\(y)\" r=\"15\" fill=\"\(cream)\" transform=\"rotate(-14 262 531)\"/><circle cx=\"773\" cy=\"\(y)\" r=\"15\" fill=\"\(cream)\" transform=\"rotate(14 762 531)\"/>"
}.joined()
try save("02-akkordeon-herz", title: "Akkordeon-Herz", groups: [
    Group(name: "01 Faltenbalg", layers: [Layer(name: "Balg", artwork: bellows)], translucency: 0.08),
    Group(name: "02 Instrument", layers: [Layer(name: "Enden", artwork: endboards), Layer(name: "Festivalquadrate", artwork: square(407, 252, size: 62, angle: -22) + square(512, 214, size: 62, angle: 18) + square(617, 252, size: 62, angle: 28))]),
    Group(name: "03 Knoepfe", layers: [Layer(name: "Knoepfe", artwork: buttons)], translucency: 0.05)
])

let programmeType = word("rudol", x: 298, y: 341, width: 396, height: 164, color: cream) + word("stadt", x: 298, y: 536, width: 396, height: 164, color: cream)
let sheetRotation = "rotate(-7 512 512)"
try save("03-mein-programm", title: "Mein Festivalprogramm", groups: [
    Group(name: "01 Hinterblatt", layers: [Layer(name: "Papier", artwork: "<g transform=\"rotate(5 512 512)\">\(rect(300, 192, 476, 626, radius: 22, color: cream))</g>")], translucency: 0.10),
    Group(name: "02 Titelseite", layers: [Layer(name: "Blatt", artwork: "<g transform=\"\(sheetRotation)\">\(rect(239, 240, 516, 620, radius: 22, color: cream))</g>"), Layer(name: "Titelfeld", artwork: "<g transform=\"\(sheetRotation)\">\(rect(270, 301, 454, 436, radius: 12, color: plum))</g>")], translucency: 0.05),
    Group(name: "03 Festivalname", layers: [Layer(name: "rudol-stadt", artwork: "<g transform=\"\(sheetRotation)\">\(programmeType)</g>")], translucency: 0.03),
    Group(name: "04 Persoenlich", layers: [Layer(name: "Lesezeichen", artwork: "<g transform=\"\(sheetRotation)\"><path fill=\"\(copper)\" d=\"M627 218 H708 V330 L667 300 L627 330 Z\"/>\(rect(285, 778, 280, 18, radius: 8, color: copper))\(rect(285, 810, 210, 14, radius: 7, color: copper))</g>"), Layer(name: "Quadratbogen", artwork: square(174, 399, size: 53, angle: -30) + square(151, 507, size: 53, angle: 16) + square(164, 619, size: 53, angle: -14))])
])

let compactType = word("rudol", x: 290, y: 315, width: 438, height: 170, color: plum) + word("stadt", x: 290, y: 520, width: 438, height: 170, color: plum)
try save("04-programm-kompakt", title: "Programm kompakt", groups: [
    Group(name: "01 Programm", layers: [Layer(name: "Titelseite", artwork: "<path fill=\"\(cream)\" d=\"M252 204 H684 L788 308 V795 Q788 824 759 824 H252 Q223 824 223 795 V233 Q223 204 252 204 Z\"/>")], translucency: 0.10),
    Group(name: "02 Festivalname", layers: [Layer(name: "rudol-stadt", artwork: compactType)], translucency: 0.03),
    Group(name: "03 Merkliste", layers: [Layer(name: "Lesezeichen", artwork: "<path fill=\"\(copper)\" d=\"M659 204 H735 V300 L697 277 L659 300 Z\"/>"), Layer(name: "Markierung", artwork: rect(291, 753, 272, 18, radius: 9, color: copper) + square(684, 762, size: 37, angle: 18))])
])

let bandText = word("rudol", x: 271, y: 371, width: 414, height: 115, color: plum) + word("stadt", x: 271, y: 512, width: 414, height: 115, color: plum)
try save("05-festivalband", title: "Mein Festivalband", groups: [
    Group(name: "01 Bandenden", layers: [Layer(name: "Schlaufe", artwork: "<path fill=\"\(copper)\" d=\"M654 300 Q848 280 846 432 L825 730 L770 700 L712 755 L730 430 Q733 397 697 404 Z\"/>"), Layer(name: "Bandende", artwork: "<path fill=\"\(copper)\" d=\"M298 606 L398 647 L328 807 L291 755 L232 766 Z\"/>")]),
    Group(name: "02 Festivalband", layers: [Layer(name: "Druckflaeche", artwork: "<g transform=\"rotate(-10 512 512)\">\(rect(217, 312, 533, 380, radius: 38, color: cream))</g>")], translucency: 0.08),
    Group(name: "03 Festivalname", layers: [Layer(name: "rudol-stadt", artwork: "<g transform=\"rotate(-10 512 512)\">\(bandText)</g>")], translucency: 0.03),
    Group(name: "04 Verschluss", layers: [Layer(name: "Schieber", artwork: "<g transform=\"rotate(-10 512 512)\">\(rect(718, 334, 72, 330, radius: 18, color: copper))</g>"), Layer(name: "Festivalquadrate", artwork: square(336, 222, size: 53, angle: -14) + square(437, 193, size: 53, angle: 16) + square(539, 187, size: 53, angle: 25))])
])

try save("06-r-in-kupfer", title: "r in Kupfer", groups: [
    Group(name: "01 Schriftzeichen", layers: [Layer(name: "r", artwork: "<path fill=\"\(copper)\" d=\"\(r)\"/>")], translucency: 0.10),
    Group(name: "02 Festivalbogen", layers: [Layer(name: "Quadrate", artwork: orbit.map { square($0.0, $0.1, angle: $0.2, color: plum) }.joined())], translucency: 0.15)
], lightBackground: true)
