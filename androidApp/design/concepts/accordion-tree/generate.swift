import AppKit
import Foundation

// Shared K1/K3 geometry. The cutouts are vector boolean operations, so exported
// SVG layers need neither luminance masks nor per-key image layers.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fm = FileManager.default
try fm.createDirectory(at: root, withIntermediateDirectories: true)
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

struct Study {
    let id: String, title: String, parent: String
    let leftAngle: CGFloat, rightAngle: CGFloat, leftY: CGFloat, rightY: CGFloat
    let seam: CGFloat, slot: CGFloat, key: CGFloat, button: CGFloat
}
let studies = [
    Study(id:"0",title:"Ausgangspunkt",parent:"",leftAngle:-17,rightAngle:14,leftY:56,rightY:51,seam:2.8,slot:3,key:4.2,button:1.8),
    Study(id:"A",title:"Ruhiger",parent:"0",leftAngle:-10,rightAngle:10,leftY:54,rightY:54,seam:2.8,slot:3,key:4.2,button:1.8),
    Study(id:"B",title:"Bewegter",parent:"0",leftAngle:-22,rightAngle:19,leftY:56,rightY:51,seam:2.8,slot:3,key:4.2,button:1.8),
    Study(id:"A1",title:"Ruhiger · fein",parent:"A",leftAngle:-10,rightAngle:10,leftY:54,rightY:54,seam:2.2,slot:2.5,key:3.6,button:1.55),
    Study(id:"A2",title:"Ruhiger · kräftig",parent:"A",leftAngle:-10,rightAngle:10,leftY:54,rightY:54,seam:3.35,slot:3.6,key:4.85,button:2.1),
    Study(id:"B1",title:"Bewegter · fein",parent:"B",leftAngle:-22,rightAngle:19,leftY:56,rightY:51,seam:2.2,slot:2.5,key:3.6,button:1.55),
    Study(id:"B2",title:"Bewegter · kräftig",parent:"B",leftAngle:-22,rightAngle:19,leftY:56,rightY:51,seam:3.35,slot:3.6,key:4.85,button:2.1),
]
func groupJSON(_ name: String, _ image: String, translucency: Double, shadow: Double) -> [String:Any] {
    ["name":name,"lighting":"combined","specular":true,
     "shadow":["kind":"neutral","opacity":shadow],
     "translucency":["enabled":true,"value":translucency],
     "layers":[["name":name,"image-name":image,"glass":true,"blend-mode":"normal",
                "position":["scale":1,"translation-in-points":[0,0]]]]]
}
var manifest=[[String:Any]]()
for study in studies {
    let folder=root.appendingPathComponent(study.id,isDirectory:true)
    let assets=folder.appendingPathComponent("Akkordeon-\(study.id).icon/Assets",isDirectory:true)
    try fm.createDirectory(at:assets,withIntermediateDirectories:true)
    let leftTransform=transform(34,study.leftY,study.leftAngle)
    let rightTransform=transform(74,study.rightY,study.rightAngle)
    let lt=point(6,-19).applying(leftTransform),lb=point(6,19).applying(leftTransform)
    let rt=point(-6,-19).applying(rightTransform),rb=point(-6,19).applying(rightTransform)
    var top=[CGPoint](),bottom=[CGPoint]()
    for i in 0...6 {
        let a=lerp(lt,rt,CGFloat(i)/6),b=lerp(lb,rb,CGFloat(i)/6)
        let offset:CGFloat=i%2==1 ? 2.5 : 0
        top.append(point(a.x,a.y-offset));bottom.append(point(b.x,b.y+offset))
    }
    var bellows=polygon(top+bottom.reversed())
    for t:CGFloat in [2.0/6,4.0/6] {
        let (a,b)=extend(lerp(lt,rt,t),lerp(lb,rb,t),-5)
        bellows=subtract(bellows,stroke(a,b,width:study.slot))
    }
    let left=CGMutablePath()
    left.move(to:point(6,-22));left.addLine(to:point(-3,-22))
    left.addQuadCurve(to:point(-6,-19),control:point(-6,-22))
    left.addLine(to:point(-6,19));left.addQuadCurve(to:point(-3,22),control:point(-6,22))
    left.addLine(to:point(6,22));left.closeSubpath()
    var keyboard:CGPath=left
    for center:CGFloat in [-10.9,0,10.9] {
        keyboard=subtract(keyboard,CGPath(rect:CGRect(x:-6.4,y:center-study.key/2,width:8.4,height:study.key),transform:nil))
    }
    let right=CGMutablePath()
    right.move(to:point(-6,-22));right.addLine(to:point(3,-22))
    right.addQuadCurve(to:point(6,-19),control:point(6,-22));right.addLine(to:point(6,19))
    right.addQuadCurve(to:point(3,22),control:point(6,22));right.addLine(to:point(-6,22));right.closeSubpath()
    var buttons:CGPath=right
    for y:CGFloat in [-11,0,11] {
        let r=study.button
        buttons=subtract(buttons,CGPath(ellipseIn:CGRect(x:-r,y:y-r,width:2*r,height:2*r),transform:nil))
    }
    keyboard=transformed(keyboard,leftTransform);buttons=transformed(buttons,rightTransform)
    for (a,b) in [(lt,lb),(rt,rb)] {
        let (start,end)=extend(a,b,6),seam=stroke(start,end,width:study.seam)
        bellows=subtract(bellows,seam);keyboard=subtract(keyboard,seam);buttons=subtract(buttons,seam)
    }
    let shells=keyboard.union(buttons,using:.winding)
    // Normalize visible geometry to a common radius so shape is compared at
    // the same optical size. The baseline keeps its original placement.
    var normalization=CGAffineTransform(translationX:54,y:54).scaledBy(x:0.855193,y:0.855193).translatedBy(x:-53.5,y:-53.125)
    if study.id != "0" {
        let foreground=bellows.union(shells,using:.winding)
        let bounds=foreground.boundingBoxOfPath,center=point(bounds.midX,bounds.midY)
        let flat=foreground.flattened(threshold:0.02)
        var radius:CGFloat=0
        flat.applyWithBlock { raw in
            let e=raw.pointee
            if e.type == .moveToPoint || e.type == .addLineToPoint {
                radius=max(radius,hypot(e.points[0].x-center.x,e.points[0].y-center.y))
            }
        }
        let scale=32/radius
        normalization=CGAffineTransform(translationX:54,y:54).scaledBy(x:scale,y:scale).translatedBy(x:-center.x,y:-center.y)
    }
    let normalizedBellows=transformed(bellows,normalization),normalizedShells=transformed(shells,normalization)
    let foreground=normalizedBellows.union(normalizedShells,using:.winding)
    try svg([(normalizedBellows,orange),(normalizedShells,cream)]).write(to:folder.appendingPathComponent("foreground.svg"),atomically:true,encoding:.utf8)
    try svg([(foreground,"#FFFFFF")]).write(to:folder.appendingPathComponent("monochrome.svg"),atomically:true,encoding:.utf8)
    let appleTransform=CGAffineTransform(scaleX:1024/72,y:1024/72).translatedBy(x:-18,y:-18)
    try svg([(transformed(normalizedBellows,appleTransform),orange)],canvas:"0 0 1024 1024").write(to:assets.appendingPathComponent("01-Balg.svg"),atomically:true,encoding:.utf8)
    try svg([(transformed(normalizedShells,appleTransform),cream)],canvas:"0 0 1024 1024").write(to:assets.appendingPathComponent("02-Gehaeuse.svg"),atomically:true,encoding:.utf8)
    let doc:[String:Any]=[
        "fill":["automatic-gradient":"srgb:0.47059,0.17255,0.45490,1.00000"],
        "groups":[groupJSON("02 Gehaeuse und Klaviatur","02-Gehaeuse.svg",translucency:0.04,shadow:0.12),
                  groupJSON("01 Zusammenhaengender Balg","01-Balg.svg",translucency:0.08,shadow:0.08)],
        "supported-platforms":["squares":"shared","circles":["watchOS"]]
    ]
    try JSONSerialization.data(withJSONObject:doc,options:[.prettyPrinted,.sortedKeys]).write(to:assets.deletingLastPathComponent().appendingPathComponent("icon.json"))
    manifest.append(["id":study.id,"title":study.title,"parent":study.parent,"leftAngle":study.leftAngle,"rightAngle":study.rightAngle,"leftY":study.leftY,"rightY":study.rightY,"seam":study.seam,"slot":study.slot,"key":study.key,"button":study.button])
    print("Generated \(study.id): \(study.title)")
}
try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("variants.json"))
