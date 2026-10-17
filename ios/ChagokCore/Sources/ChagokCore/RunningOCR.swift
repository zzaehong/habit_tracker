import Foundation

public struct RunningCandidate: Equatable, Sendable {
  public var distance: Double?
  public var seconds: Double?
  public var reportedPace: Double?
  public var heartRate: Double?
  public var cadence: Double?
  public var raw: String = ""
  public var questions: [String] = []
  public init() {}
}
public enum RunningOCR {
  public static func parse(_ text: String) -> RunningCandidate {
    var output = RunningCandidate()
    output.raw = text
    let lines = text.lowercased().components(separatedBy: .newlines).map {
      $0.trimmingCharacters(in: .whitespaces)
    }
    func matches(_ pattern: String, _ line: String) -> String? {
      guard let re = try? NSRegularExpression(pattern: pattern),
        let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
        let r = Range(m.range(at: 1), in: line)
      else { return nil }
      return String(line[r])
    }
    func near(_ i: Int, pattern: String) -> String? {
      for k in [i, i - 1, i + 1] where lines.indices.contains(k) {
        if let s = matches(pattern, lines[k]) { return s }
      }
      return nil
    }
    func time(_ s: String) -> Double? {
      let p = s.split(separator: ":").compactMap { Double($0) }
      guard (2...3).contains(p.count), p.dropFirst().allSatisfy({ $0 < 60 }) else { return nil }
      return p.reduce(0) { $0 * 60 + $1 }
    }
    for (i, line) in lines.enumerated() {
      if line.contains("km") || line.contains("킬로미터") || line.contains("mile") || line == "mi"
        || line.contains("거리"), !line.contains("/"), !line.contains("페이스"), !line.contains("pace"),
        let n = near(i, pattern: #"(\d+(?:[.,]\d+)?)"#).flatMap({
          Double($0.replacingOccurrences(of: ",", with: "."))
        })
      {
        output.distance = n * (line.contains("mile") || line == "mi" ? 1.609344 : 1)
      }
      if line.contains("시간") || line.contains("duration") || line.contains("time"),
        let s = near(i, pattern: #"(\d{1,3}:\d{2}(?::\d{2})?)"#)
      {
        output.seconds = time(s)
      }
      if line.contains("페이스") || line.contains("pace"),
        let s = near(i, pattern: #"(\d{1,3}:\d{2})"#)
      {
        output.reportedPace = time(s).map { $0 / (line.contains("mi") ? 1.609344 : 1) }
      }
      if line.contains("심박") || line.contains("heart") || line.contains("bpm"),
        let n = near(i, pattern: #"(\d{2,3})"#).flatMap(Double.init)
      {
        output.heartRate = n
      }
      if line.contains("케이던스") || line.contains("cadence") || line.contains("spm"),
        let n = near(i, pattern: #"(\d{2,3})"#).flatMap(Double.init)
      {
        output.cadence = n
      }
    }
    if let km = output.distance, km > 0, let seconds = output.seconds,
      let pace = output.reportedPace, abs(seconds / km - pace) > 10
    {
      output.questions.append("표시 페이스와 거리·시간 계산이 다릅니다. 원본을 확인하세요.")
    }
    if output.distance == nil { output.questions.append("거리를 읽지 못했습니다. 직접 입력하세요.") }
    if output.seconds == nil { output.questions.append("시간을 읽지 못했습니다. 직접 입력하세요.") }
    return output
  }
  public static func merge(_ values: [RunningCandidate]) -> RunningCandidate {
    var result = RunningCandidate()
    result.raw = values.map(\.raw).joined(separator: "\n---\n")
    func resolve(_ key: KeyPath<RunningCandidate, Double?>, _ name: String) -> Double? {
      let nums = values.compactMap { $0[keyPath: key] }
      guard let first = nums.first else { return nil }
      if nums.contains(where: { abs($0 - first) > 0.01 }) {
        result.questions.append("\(name)이 여러 이미지에서 다릅니다. 직접 확인하세요.")
        return nil
      }
      return first
    }
    result.distance = resolve(\.distance, "거리")
    result.seconds = resolve(\.seconds, "시간")
    result.reportedPace = resolve(\.reportedPace, "표시 페이스")
    result.heartRate = resolve(\.heartRate, "심박수")
    result.cadence = resolve(\.cadence, "케이던스")
    result.questions += values.flatMap(\.questions)
    return result
  }
}
