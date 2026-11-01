import Foundation
import SwiftUI

func svgPath(width: CGFloat, height: CGFloat, radius: CGFloat, normalized: Bool) -> String {
    let path = RoundedRectangle(cornerRadius: radius, style: .continuous)
        .path(in: CGRect(x: 0, y: 0, width: width, height: height))
    var commands: [String] = []
    func point(_ p: CGPoint) -> String {
        let x = normalized ? p.x / width : p.x
        let y = normalized ? p.y / height : p.y
        return String(format: "%.7f %.7f", Double(x), Double(y))
    }
    path.cgPath.applyWithBlock { pointer in
        let element = pointer.pointee
        switch element.type {
        case .moveToPoint: commands.append("M " + point(element.points[0]))
        case .addLineToPoint: commands.append("L " + point(element.points[0]))
        case .addQuadCurveToPoint:
            commands.append("Q " + point(element.points[0]) + " " + point(element.points[1]))
        case .addCurveToPoint:
            commands.append("C " + point(element.points[0]) + " " + point(element.points[1]) + " " + point(element.points[2]))
        case .closeSubpath: commands.append("Z")
        @unknown default: fatalError("Unexpected path element")
        }
    }
    return commands.joined(separator: " ")
}

let height = CGFloat(670.0 * 2622.0 / 1206.0)
let contours = [
    "outer": svgPath(width: 692, height: height + 22, radius: 96, normalized: false),
    "display": svgPath(width: 670, height: height, radius: 85, normalized: true),
    "icon": svgPath(width: 202, height: 202, radius: 45, normalized: true)
]
let data = try JSONSerialization.data(withJSONObject: contours, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
