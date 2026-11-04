import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let symbols: [(String, NSColor)] = [
    ("target", .black), ("location.fill", .systemBlue),
    ("map", .black), ("list.bullet", .black),
]
for (name, tint) in symbols {
    let configuration = NSImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [tint]))
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: name)?
        .withSymbolConfiguration(configuration) else { fatalError("Missing symbol: \(name)") }
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 72, pixelsHigh: 72,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: 24, height: 24)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let ratio = min(20 / image.size.width, 20 / image.size.height)
    let size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
    image.draw(in: NSRect(x: (24 - size.width) / 2, y: (24 - size.height) / 2,
                          width: size.width, height: size.height))
    NSGraphicsContext.restoreGraphicsState()
    let path = output.appendingPathComponent("sf-\(name)@3x.png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: path)
    print(path.path)
}
