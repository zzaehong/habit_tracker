import AppKit
for size in [192, 512] {
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
 NSColor(calibratedRed:0.15,green:0.30,blue:0.23,alpha:1).setFill();NSBezierPath(rect:NSRect(x:0,y:0,width:size,height:size)).fill()
 NSColor(calibratedRed:0.84,green:0.93,blue:0.70,alpha:1).setFill()
 let scale=Double(size)/192
 for (i,width) in [96.0,73.0,96.0].enumerated(){NSBezierPath(rect:NSRect(x:48*scale,y:(54+Double(i)*31)*scale,width:width*scale,height:21*scale)).fill()}
 NSGraphicsContext.restoreGraphicsState()
 try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"public/icon-\(size).png"))
}
