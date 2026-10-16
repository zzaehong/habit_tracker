import AppKit
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:3,hasAlpha:false,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
NSColor(calibratedRed:0.96,green:0.95,blue:0.91,alpha:1).setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:size,height:size)).fill()
for (i,width) in [560,440,320].enumerated() { NSColor(calibratedRed:0.12,green:0.34+Double(i)*0.06,blue:0.25,alpha:1).setFill(); NSBezierPath(roundedRect:NSRect(x:(1024-width)/2,y:210+i*190,width:width,height:140),xRadius:48,yRadius:48).fill() }
NSGraphicsContext.restoreGraphicsState(); try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
