import AppKit

let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
	bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
	colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

func polygon(_ points: [(CGFloat, CGFloat)], color: NSColor) {
	let path = NSBezierPath()
	path.move(to: NSPoint(x: points[0].0, y: points[0].1))
	for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
	path.close()
	color.setFill()
	path.fill()
}

let ink = NSColor(red: 0.025, green: 0.035, blue: 0.045, alpha: 1)
let gold = NSColor(red: 0.93, green: 0.73, blue: 0.36, alpha: 1)
ink.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
polygon([(200, 252), (166, 596), (290, 816), (512, 896), (734, 816), (858, 596), (824, 252)],
	color: NSColor(red: 0.12, green: 0.14, blue: 0.16, alpha: 1))
polygon([(238, 252), (222, 590), (326, 782), (512, 846), (698, 782), (802, 590), (786, 252)], color: ink)
polygon([(256, 554), (376, 584), (480, 544), (458, 502), (310, 510)], color: gold)
polygon([(768, 554), (648, 584), (544, 544), (566, 502), (714, 510)], color: gold)
polygon([(288, 456), (512, 414), (736, 456), (714, 298), (512, 224), (310, 298)], color: gold)
polygon([(474, 408), (512, 414), (550, 408), (536, 256), (512, 246), (488, 256)], color: ink)
let colors: [NSColor] = [gold, .init(red: 0.15, green: 0.62, blue: 0.96, alpha: 1),
	.init(red: 0.25, green: 0.82, blue: 0.45, alpha: 1), .init(red: 0.91, green: 0.16, blue: 0.19, alpha: 1)]
for (i, color) in colors.enumerated() {
	color.setFill()
	NSBezierPath(rect: NSRect(x: 292 + CGFloat(i) * 116, y: 128, width: 92, height: 16)).fill()
}
NSGraphicsContext.restoreGraphicsState()
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let folder = root.appendingPathComponent("MK/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("Icon.png"))
print("Generated AppIcon")
