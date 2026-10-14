import Foundation
import Vision
import ImageIO

struct Line: Codable {
    let text: String
    let confidence: Float
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
func run() throws {
    guard CommandLine.arguments.count == 2 else { throw NSError(domain: "OCR", code: 1, userInfo: [NSLocalizedDescriptionKey: "이미지 경로가 필요합니다."]) }
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "OCR", code: 2, userInfo: [NSLocalizedDescriptionKey: "이미지를 읽지 못했습니다."])
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    let supported = try request.supportedRecognitionLanguages()
    request.recognitionLanguages = ["ko-KR", "en-US"].filter { supported.contains($0) }
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    let lines = (request.results ?? []).compactMap { observation -> Line? in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let box = observation.boundingBox
        return Line(text: candidate.string, confidence: candidate.confidence, x: box.origin.x, y: box.origin.y, width: box.width, height: box.height)
    }
    let data = try JSONEncoder().encode(lines)
    FileHandle.standardOutput.write(data)
}
do { try run() } catch {
    FileHandle.standardError.write(Data("OCR 실패: \(error.localizedDescription)\n".utf8))
    exit(1)
}
