import AppKit
import Foundation

// Shared K1/K3 geometry. The cutouts are vector boolean operations, so exported
// SVG layers need neither luminance masks nor per-key image layers.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fm = FileManager.default
let assets = root.appendingPathComponent("Rudolstadt-Akkordeon.icon/Assets", isDirectory: true)
try fm.createDirectory(at: assets, withIntermediateDirectories: true)
let purple = "#782C74", cream = "#FFF5E9", orange = "#F1B779"

func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
func transform(_ cx: CGFloat, _ cy: CGFloat, _ angle: CGFloat) -> CGAffineTransform {
    CGAffineTransform(translationX: cx, y: cy).rotated(by: angle * .pi / 180)
}
func polygon(_ points: [CGPoint]) -> CGPath {
    let p = CGMutablePath(); p.addLines(between: points); p.closeSubpath(); return p
}
func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    point(a.x + (b.x-a.x)*t, a.y + (b.y-a.y)*t)
}
func stroke(_ a: CGPoint, _ b: CGPoint, width: CGFloat) -> CGPath {
    let p=CGMutablePath();p.move(to:a);p.addLine(to:b)
    return p.copy(strokingWithWidth:width,lineCap:.round,lineJoin:.round,miterLimit:1)
}
func extend(_ a: CGPoint, _ b: CGPoint, _ d: CGFloat) -> (CGPoint, CGPoint) {
    let length=hypot(b.x-a.x,b.y-a.y), ux=(b.x-a.x)/length, uy=(b.y-a.y)/length
    return (point(a.x-ux*d,a.y-uy*d),point(b.x+ux*d,b.y+uy*d))
}
func subtract(_ p: CGPath, _ cutout: CGPath) -> CGPath {
    p.subtracting(cutout, using: .winding)
}
func transformed(_ p: CGPath, _ t: CGAffineTransform) -> CGPath {
    var t=t;return p.copy(using:&t)!
}
func number(_ n: CGFloat) -> String { String(format:"%.5f",Double(n)) }
func data(_ path: CGPath) -> String {
    var result=[String]()
    path.applyWithBlock { e in
        let p=e.pointee
        func xy(_ i: Int) -> String { "\(number(p.points[i].x)),\(number(p.points[i].y))" }
        switch p.type {
        case .moveToPoint: result.append("M\(xy(0))")
        case .addLineToPoint: result.append("L\(xy(0))")
        case .addQuadCurveToPoint: result.append("Q\(xy(0)) \(xy(1))")
        case .addCurveToPoint: result.append("C\(xy(0)) \(xy(1)) \(xy(2))")
        case .closeSubpath: result.append("Z")
        @unknown default: break
        }
    }
    return result.joined(separator:" ")
}
func svg(_ paths: [(CGPath,String)], canvas: String="0 0 108 108") -> String {
    let artwork=paths.map { "<path fill=\"\($0.1)\" d=\"\(data($0.0))\"/>" }.joined()
    return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1024\" height=\"1024\" viewBox=\"\(canvas)\">\(artwork)</svg>\n"
}

// Green's theorem integrates signed area and first area moments over the
// actual Bezier boundaries, including holes. Five-point Gaussian quadrature
// is exact for these polynomial integrands (cubic Beziers need degree <= 8).
func areaMoments(_ path: CGPath) -> (area: CGFloat, center: CGPoint) {
    let nodes: [CGFloat] = [-0.906179845938664, -0.538469310105683, 0, 0.538469310105683, 0.906179845938664]
    let weights: [CGFloat] = [0.236926885056189, 0.478628670499366, 0.568888888888889, 0.478628670499366, 0.236926885056189]
    var area: CGFloat = 0, momentX: CGFloat = 0, momentY: CGFloat = 0
    var current = CGPoint.zero, start = CGPoint.zero
    func evaluate(_ points: [CGPoint], _ t: CGFloat) -> CGPoint {
        var level = points
        while level.count > 1 { level = (0..<(level.count-1)).map { lerp(level[$0], level[$0+1], t) } }
        return level[0]
    }
    func integrate(_ points: [CGPoint]) {
        let degree = CGFloat(points.count-1)
        let derivatives = (0..<(points.count-1)).map { point(degree*(points[$0+1].x-points[$0].x),degree*(points[$0+1].y-points[$0].y)) }
        for i in nodes.indices {
            let t = (nodes[i]+1)/2, w = weights[i]/2
            let p = evaluate(points,t), d = evaluate(derivatives,t)
            area += w*(p.x*d.y-p.y*d.x)/2
            momentX += w*p.x*p.x*d.y/2
            momentY -= w*p.y*p.y*d.x/2
        }
    }
    path.applyWithBlock { raw in
        let element = raw.pointee
        switch element.type {
        case .moveToPoint: current = element.points[0]; start = current
        case .addLineToPoint:
            integrate([current,element.points[0]]); current = element.points[0]
        case .addQuadCurveToPoint:
            integrate([current,element.points[0],element.points[1]]); current = element.points[1]
        case .addCurveToPoint:
            integrate([current,element.points[0],element.points[1],element.points[2]]); current = element.points[2]
        case .closeSubpath: integrate([current,start]); current = start
        @unknown default: break
        }
    }
    precondition(abs(area)>0.000001)
    return (abs(area),point(momentX/area,momentY/area))
}

let leftTransform=transform(34,56,-17), rightTransform=transform(74,51,14)
let lt=point(6,-19).applying(leftTransform), lb=point(6,19).applying(leftTransform)
let rt=point(-6,-19).applying(rightTransform), rb=point(-6,19).applying(rightTransform)
var top=[CGPoint](), bottom=[CGPoint]()
for i in 0...6 {
    let a=lerp(lt,rt,CGFloat(i)/6), b=lerp(lb,rb,CGFloat(i)/6)
    let offset:CGFloat=i%2 == 1 ? 2.5 : 0
    top.append(point(a.x,a.y-offset));bottom.append(point(b.x,b.y+offset))
}
var bellows=polygon(top+bottom.reversed())
for t:CGFloat in [2.0/6,4.0/6] {
    let (a,b)=extend(lerp(lt,rt,t),lerp(lb,rb,t),-5)
    bellows=subtract(bellows,stroke(a,b,width:3))
}
let left=CGMutablePath()
left.move(to:point(6,-22));left.addLine(to:point(-3,-22))
left.addQuadCurve(to:point(-6,-19),control:point(-6,-22))
left.addLine(to:point(-6,19));left.addQuadCurve(to:point(-3,22),control:point(-6,22))
left.addLine(to:point(6,22));left.closeSubpath()
var keyboard:CGPath=left
for y:CGFloat in [-13,-2.1,8.8] {
    keyboard=subtract(keyboard,CGPath(rect:CGRect(x:-6.4,y:y,width:8.4,height:4.2),transform:nil))
}
let right=CGMutablePath()
right.move(to:point(-6,-22));right.addLine(to:point(3,-22))
right.addQuadCurve(to:point(6,-19),control:point(6,-22));right.addLine(to:point(6,19))
right.addQuadCurve(to:point(3,22),control:point(6,22));right.addLine(to:point(-6,22));right.closeSubpath()
var buttons:CGPath=right
for y:CGFloat in [-11,0,11] {
    buttons=subtract(buttons,CGPath(ellipseIn:CGRect(x:-1.8,y:y-1.8,width:3.6,height:3.6),transform:nil))
}
keyboard=transformed(keyboard,leftTransform);buttons=transformed(buttons,rightTransform)
for (a,b) in [(lt,lb),(rt,rb)] {
    // Extend beyond the end caps, so the seam cannot leave tiny hooked tips.
    let (start,end)=extend(a,b,6), seam=stroke(start,end,width:2.8)
    bellows=subtract(bellows,seam);keyboard=subtract(keyboard,seam);buttons=subtract(buttons,seam)
}
let shells=keyboard.union(buttons,using:.winding)
let normalization=CGAffineTransform(translationX:54,y:54).scaledBy(x:0.855193,y:0.855193).translatedBy(x:-53.5,y:-53.125)
var normalizedBellows=transformed(bellows,normalization), normalizedShells=transformed(shells,normalization)
let before=normalizedBellows.union(normalizedShells,using:.winding)
let beforeMoments=areaMoments(before)
let beforeBounds=before.boundingBoxOfPath
// The 52dp horizontal keyline is a Google Design starting point, not a
// psychophysical optimum. Other scales are exported separately for matching.
let sizeFactor: CGFloat = CommandLine.arguments.count > 2 ? CGFloat(Double(CommandLine.arguments[2])!) : 1
let targetWidth: CGFloat = 52 * sizeFactor
let scale=targetWidth/beforeBounds.width
let centering=CGAffineTransform(translationX:54,y:54).scaledBy(x:scale,y:scale).translatedBy(x:-beforeMoments.center.x,y:-beforeMoments.center.y)
normalizedBellows=transformed(normalizedBellows,centering)
normalizedShells=transformed(normalizedShells,centering)
let foreground=normalizedBellows.union(normalizedShells,using:.winding)
let afterMoments=areaMoments(foreground)
let afterBounds=foreground.boundingBoxOfPath
precondition(hypot(afterMoments.center.x-54,afterMoments.center.y-54)<0.000001)
let flattened=foreground.flattened(threshold:0.0001)
var radius: CGFloat=0
var hullPoints=[CGPoint]()
flattened.applyWithBlock { raw in
    let e=raw.pointee
    if e.type == .moveToPoint || e.type == .addLineToPoint {
        radius=max(radius,hypot(e.points[0].x-54,e.points[0].y-54))
        hullPoints.append(e.points[0])
    }
}
// Monotone-chain hull over adaptively flattened vector boundaries. Interior
// holes cannot shrink the envelope used for optical-size normalization.
hullPoints.sort { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
func cross(_ o: CGPoint,_ a: CGPoint,_ b: CGPoint) -> CGFloat {
    (a.x-o.x)*(b.y-o.y)-(a.y-o.y)*(b.x-o.x)
}
func chain(_ points:[CGPoint]) -> [CGPoint] {
    var result=[CGPoint]()
    for p in points {
        while result.count>1 && cross(result[result.count-2],result[result.count-1],p)<=0 { result.removeLast() }
        result.append(p)
    }
    return result
}
let hull=Array(chain(hullPoints).dropLast())+Array(chain(Array(hullPoints.reversed())).dropLast())
let hullArea=abs(hull.indices.reduce(CGFloat(0)) { sum,i in
    let a=hull[i],b=hull[(i+1)%hull.count]
    return sum+a.x*b.y-b.x*a.y
})/2
let measurements: [String:Any] = [
    "method":"Signed area moments of the filled vector silhouette; exact polynomial quadrature over Bezier paths",
    "before":["centroidX":beforeMoments.center.x,"centroidY":beforeMoments.center.y,"area":beforeMoments.area,"width":beforeBounds.width,"height":beforeBounds.height],
    "translationAtOriginalScale":["dx":54-beforeMoments.center.x,"dy":54-beforeMoments.center.y],
    "after":["centroidX":afterMoments.center.x,"centroidY":afterMoments.center.y,"area":afterMoments.area,"width":afterBounds.width,"height":afterBounds.height,"minX":afterBounds.minX,"maxX":afterBounds.maxX,"minY":afterBounds.minY,"maxY":afterBounds.maxY,"radius":radius,"equivalentAreaDiameter":2*sqrt(afterMoments.area / .pi)],
    "scaleRelativeToOriginal":scale,"sizeFactor":sizeFactor,
    "convexHullArea":hullArea,"convexHull":hull.map { [$0.x,$0.y] },
    "androidCircleFillFraction":afterMoments.area/(.pi*36*36),
    "appleCanvasWidthFraction":afterBounds.width/72,
    "note":"Perceived size requires observer matching in platform context; these measurements are objective design proxies, not a validated icon-perception model."
]
try JSONSerialization.data(withJSONObject:measurements,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("measurements.json"))
try svg([(normalizedBellows,orange),(normalizedShells,cream)]).write(to:root.appendingPathComponent("foreground.svg"),atomically:true,encoding:.utf8)
try svg([(foreground,"#FFFFFF")]).write(to:root.appendingPathComponent("monochrome.svg"),atomically:true,encoding:.utf8)
let background=CGPath(rect:CGRect(x:0,y:0,width:108,height:108),transform:nil)
try svg([(background,purple),(normalizedBellows,orange),(normalizedShells,cream)],canvas:"18 18 72 72").write(to:root.appendingPathComponent("android.svg"),atomically:true,encoding:.utf8)

// The same geometry fills the central 72-unit viewport on the Apple canvas.
let appleTransform=CGAffineTransform(scaleX:1024/72,y:1024/72).translatedBy(x:-18,y:-18)
let appleBellows=transformed(normalizedBellows,appleTransform)
let appleShells=transformed(normalizedShells,appleTransform)
try svg([(appleBellows,orange)],canvas:"0 0 1024 1024").write(to:assets.appendingPathComponent("01-Balg.svg"),atomically:true,encoding:.utf8)
try svg([(appleShells,cream)],canvas:"0 0 1024 1024").write(to:assets.appendingPathComponent("02-Gehaeuse.svg"),atomically:true,encoding:.utf8)
func iconGroup(_ name: String, _ image: String, translucency: Double, shadow: Double) -> [String:Any] {
    ["name":name,"lighting":"combined","specular":true,
     "shadow":["kind":"neutral","opacity":shadow],
     "translucency":["enabled":true,"value":translucency],
     "layers":[["name":name,"image-name":image,"glass":true,"blend-mode":"normal",
                "position":["scale":1,"translation-in-points":[0,0]]]]]
}
let document:[String:Any]=[
    "fill":["automatic-gradient":"srgb:0.47059,0.17255,0.45490,1.00000"],
    "groups":[iconGroup("02 Gehaeuse und Klaviatur","02-Gehaeuse.svg",translucency:0.04,shadow:0.12),
              iconGroup("01 Zusammenhaengender Balg","01-Balg.svg",translucency:0.08,shadow:0.08)],
    "supported-platforms":["squares":"shared","circles":["watchOS"]]
]
let json=try JSONSerialization.data(withJSONObject:document,options:[.prettyPrinted,.sortedKeys])
try json.write(to:assets.deletingLastPathComponent().appendingPathComponent("icon.json"))
print("Exported shared compound vector paths and a native Icon Composer package with two foreground groups.")
