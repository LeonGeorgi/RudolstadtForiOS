import AppKit
import Vision
let url=URL(fileURLWithPath:CommandLine.arguments[1])
guard let cg=NSImage(contentsOf:url)?.cgImage(forProposedRect:nil, context:nil, hints:nil) else { throw NSError(domain:"trace",code:1) }
guard let context=CGContext(data:nil,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { throw NSError(domain:"trace",code:2) }
context.setFillColor(CGColor(gray:1,alpha:1))
context.fill(CGRect(x:0,y:0,width:cg.width,height:cg.height))
context.draw(cg,in:CGRect(x:0,y:0,width:cg.width,height:cg.height))
guard let flattened=context.makeImage() else { throw NSError(domain:"trace",code:3) }
let r=VNDetectContoursRequest()
r.detectsDarkOnLight=true
r.maximumImageDimension=2048
r.regionOfInterest=CGRect(x:0,y:0,width:0.54,height:1)
try VNImageRequestHandler(cgImage:flattened).perform([r])

guard let observation=r.results?.first else { throw NSError(domain:"trace",code:4) }
let letters=observation.topLevelContours.filter { $0.normalizedPath.boundingBoxOfPath.width > 0.02 }
guard letters.count==10 else { throw NSError(domain:"trace",code:5) }
let path=CGMutablePath()
func append(_ contour: VNContour) {
    path.addPath(contour.normalizedPath)
    for child in contour.childContours { append(child) }
}
for letter in letters { append(letter) }
var pixelTransform=CGAffineTransform(a:CGFloat(cg.width)*0.54,b:0,c:0,d:-CGFloat(cg.height),tx:0,ty:CGFloat(cg.height))
guard let physicalPath=path.copy(using:&pixelTransform) else { throw NSError(domain:"trace",code:6) }
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


let bounds=physicalPath.boundingBoxOfPath
let scale=900/bounds.width
let x=(1024-bounds.width*scale)/2
let y=(1024-bounds.height*scale)/2
let transform="translate(\(number(x)) \(number(y))) scale(\(number(scale))) translate(\(number(-bounds.minX)) \(number(-bounds.minY)))"
let svg="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\"><title>Original horizontal Rudolstadt lettering: all ten glyphs</title><g transform=\"\(transform)\"><path fill=\"#FFFFFF\" fill-rule=\"evenodd\" d=\"\(pathData(physicalPath))\"/></g></svg>"
try svg.write(to:URL(fileURLWithPath:CommandLine.arguments[2]),atomically:true,encoding:.utf8)
print("Traced ten original glyphs and their counters; physical aspect ratio preserved.")
