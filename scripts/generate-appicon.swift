//
//  generate-appicon.swift
//  Gloaming
//
//  Standalone script (not part of the app target): renders the Gloaming app icon and writes it
//  into an .appiconset. Run via `just icon`, i.e. `swift scripts/generate-appicon.swift <dir>`.
//

import AppKit

guard CommandLine.arguments.count == 2 else {
	FileHandle.standardError.write(Data("usage: generate-appicon.swift <path-to-AppIcon.appiconset>\n".utf8))
	exit(1)
}

let appiconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
var isDirectory: ObjCBool = false
let exists = FileManager.default.fileExists(atPath: appiconsetURL.path, isDirectory: &isDirectory)
guard exists, isDirectory.boolValue else {
	FileHandle.standardError.write(Data("no such directory: \(appiconsetURL.path)\n".utf8))
	exit(1)
}

// MARK: - Palette

func color(_ hex: UInt32) -> NSColor {
	NSColor(
		srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
		blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let skyTop = color(0x1D1B4C) // deep indigo
let skyHorizon = color(0xF0A05A) // warm amber
let skyBottom = color(0x2A1E3F) // deep plum
let sunColor = color(0xFFF6DC) // soft white-yellow

// MARK: - Master render (1024x1024)

let masterSize = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard
	let context = CGContext(
		data: nil, width: masterSize, height: masterSize, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
		bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else {
	FileHandle.standardError.write(Data("could not create bitmap context\n".utf8))
	exit(1)
}

// Flip so y = 0 is the top of the icon, matching the "percent down" language below.
context.translateBy(x: 0, y: CGFloat(masterSize))
context.scaleBy(x: 1, y: -1)

// Full-bleed dusk gradient: indigo -> amber horizon (72% down) -> plum. No rounded-rect mask;
// macOS applies the squircle itself.
let sky = CGGradient(
	colorsSpace: colorSpace, colors: [skyTop.cgColor, skyHorizon.cgColor, skyBottom.cgColor] as CFArray,
	locations: [0, 0.72, 1])!
context.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: masterSize), options: [])

// Sun: ~30% of the width across, centered ~38% down, with a soft outer glow.
let sunCenter = CGPoint(x: CGFloat(masterSize) / 2, y: CGFloat(masterSize) * 0.38)
let sunRadius = CGFloat(masterSize) * 0.15

let glow = CGGradient(
	colorsSpace: colorSpace,
	colors: [sunColor.withAlphaComponent(0.4).cgColor, sunColor.withAlphaComponent(0).cgColor] as CFArray,
	locations: [0, 1])!
context.drawRadialGradient(
	glow, startCenter: sunCenter, startRadius: sunRadius * 0.85, endCenter: sunCenter, endRadius: sunRadius * 2.2,
	options: [])

func disc(center: CGPoint, radius: CGFloat) -> CGRect {
	CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
}

// Crescent: subtract a second circle from the sun disc (true path subtraction), so the glowing
// sky shows through the cut and the mark reads light/dark rather than an eclipse.
let biteRadius = sunRadius * 0.92
let biteOffset = sunRadius * 0.62
let biteCenter = CGPoint(x: sunCenter.x + biteOffset, y: sunCenter.y - biteOffset)
let sunPath = CGPath(ellipseIn: disc(center: sunCenter, radius: sunRadius), transform: nil)
let bitePath = CGPath(ellipseIn: disc(center: biteCenter, radius: biteRadius), transform: nil)
context.addPath(sunPath.subtracting(bitePath))
context.setFillColor(sunColor.cgColor)
context.fillPath()

guard let masterImage = context.makeImage() else {
	FileHandle.standardError.write(Data("could not render master image\n".utf8))
	exit(1)
}

// MARK: - Export scaled PNGs

/// Renders `image` into a fresh `pixels`-square canvas and returns PNG data.
func png(of image: CGImage, pixels: Int) -> Data? {
	guard
		let scaledContext = CGContext(
			data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
	else { return nil }
	scaledContext.interpolationQuality = .high
	scaledContext.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
	guard let scaledImage = scaledContext.makeImage() else { return nil }
	return NSBitmapImageRep(cgImage: scaledImage).representation(using: .png, properties: [:])
}

let basePoints = [16, 32, 128, 256, 512]
var contentsImages: [String] = []

for points in basePoints {
	for scale in [1, 2] {
		let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
		guard let data = png(of: masterImage, pixels: points * scale) else {
			FileHandle.standardError.write(Data("could not render \(filename)\n".utf8))
			exit(1)
		}
		try? data.write(to: appiconsetURL.appendingPathComponent(filename))
		contentsImages.append(
			"    { \"filename\" : \"\(filename)\", \"idiom\" : \"mac\", \"scale\" : \"\(scale)x\", "
				+ "\"size\" : \"\(points)x\(points)\" }")
	}
}

let contentsJSON = """
{
  "images" : [
\(contentsImages.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try? contentsJSON.write(
	to: appiconsetURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

print("Wrote \(contentsImages.count) PNGs + Contents.json to \(appiconsetURL.path)")
