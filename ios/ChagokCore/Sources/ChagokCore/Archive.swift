import CZip
import CryptoKit
import Foundation

public enum Archive {
  public static let limit = 300 * 1024 * 1024
  public static func hash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
  private static func crc(_ data: Data) -> UInt32 {
    data.withUnsafeBytes { chagok_crc($0.bindMemory(to: UInt8.self).baseAddress, data.count) }
  }
  public static func zip(_ files: [String: Data]) throws -> Data {
    guard files.count < 65535, files.values.reduce(0, { $0 + $1.count }) <= limit else {
      throw AppError.invalid("백업이 300MB 한도를 넘습니다.")
    }
    var body = Data()
    var central = Data()
    for name in files.keys.sorted() {
      guard safe(name), let data = files[name] else { throw AppError.invalid("파일 이름을 확인하세요.") }
      let filename = Data(name.utf8)
      let checksum = crc(data)
      let offset = body.count
      body.le(UInt32(0x0403_4b50))
      body.le(UInt16(20))
      body.le(UInt16(0x800))
      body.le(UInt16(0))
      body.le(UInt16(0))
      body.le(UInt16(0))
      body.le(checksum)
      body.le(UInt32(data.count))
      body.le(UInt32(data.count))
      body.le(UInt16(filename.count))
      body.le(UInt16(0))
      body.append(filename)
      body.append(data)
      central.le(UInt32(0x0201_4b50))
      central.le(UInt16(20))
      central.le(UInt16(20))
      central.le(UInt16(0x800))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(checksum)
      central.le(UInt32(data.count))
      central.le(UInt32(data.count))
      central.le(UInt16(filename.count))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt16(0))
      central.le(UInt32(0))
      central.le(UInt32(offset))
      central.append(filename)
    }
    let start = body.count
    body.append(central)
    body.le(UInt32(0x0605_4b50))
    body.le(UInt16(0))
    body.le(UInt16(0))
    body.le(UInt16(files.count))
    body.le(UInt16(files.count))
    body.le(UInt32(central.count))
    body.le(UInt32(start))
    body.le(UInt16(0))
    return body
  }
  public static func unzip(_ data: Data) throws -> [String: Data] {
    guard data.count >= 22, data.count <= limit else {
      throw AppError.invalid("ZIP 크기를 확인하세요. 최대 300MB입니다.")
    }
    var end: Int?
    for i in stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1) {
      if try data.u32(i) == 0x0605_4b50, i + 22 + Int(try data.u16(i + 20)) == data.count {
        end = i
        break
      }
    }
    guard let end, try data.u16(end + 4) == 0, try data.u16(end + 6) == 0 else {
      throw AppError.invalid("분할 ZIP은 지원하지 않습니다.")
    }
    let count = Int(try data.u16(end + 10))
    var cursor = Int(try data.u32(end + 16))
    var total = 0
    var files: [String: Data] = [:]
    guard count <= 20000, cursor + Int(try data.u32(end + 12)) <= end else {
      throw AppError.invalid("ZIP 목차가 올바르지 않습니다.")
    }
    for _ in 0..<count {
      guard try data.u32(cursor) == 0x0201_4b50 else { throw AppError.invalid("손상된 ZIP 목차입니다.") }
      let flags = try data.u16(cursor + 8)
      let method = try data.u16(cursor + 10)
      let checksum = try data.u32(cursor + 16)
      let compressed = Int(try data.u32(cursor + 20))
      let size = Int(try data.u32(cursor + 24))
      let nameCount = Int(try data.u16(cursor + 28))
      let extra = Int(try data.u16(cursor + 30))
      let comment = Int(try data.u16(cursor + 32))
      let offset = Int(try data.u32(cursor + 42))
      guard flags & 1 == 0, method == 0 || method == 8 else {
        throw AppError.invalid("암호화 또는 지원하지 않는 ZIP 압축입니다.")
      }
      let nameData = try data.slice(cursor + 46, nameCount)
      guard let name = String(data: nameData, encoding: .utf8), safe(name), files[name] == nil
      else { throw AppError.invalid("중복 또는 잘못된 ZIP 경로입니다.") }
      cursor += 46 + nameCount + extra + comment
      total += size
      guard total <= limit, try data.u32(offset) == 0x0403_4b50 else {
        throw AppError.invalid("압축 해제 한도 초과 또는 손상된 ZIP입니다.")
      }
      let start = offset + 30 + Int(try data.u16(offset + 26)) + Int(try data.u16(offset + 28))
      let input = try data.slice(start, compressed)
      var output: Data
      if method == 0 {
        guard compressed == size else { throw AppError.invalid("잘못된 ZIP 크기입니다.") }
        output = input
      } else {
        // One byte capacity also allows an empty deflate stream to terminate.
        var buffer = Data(count: max(size, 1))
        let capacity = buffer.count
        let valid = buffer.withUnsafeMutableBytes { out in
          input.withUnsafeBytes { src in
            chagok_inflate(
              src.bindMemory(to: UInt8.self).baseAddress, input.count,
              out.bindMemory(to: UInt8.self).baseAddress, size == 0 ? 0 : capacity)
          }
        }
        guard valid == 1 else { throw AppError.invalid("ZIP 압축 해제 실패") }
        output = buffer.prefix(size)
      }
      guard crc(output) == checksum else { throw AppError.invalid("ZIP 파일 검증 실패") }
      if !name.hasSuffix("/") { files[name] = output }
    }
    return files
  }
  private static func safe(_ name: String) -> Bool {
    !name.isEmpty && !name.hasPrefix("/") && !name.contains("\\")
      && !name.split(separator: "/").contains("..") && !name.contains("\0")
  }
}
extension Data {
  fileprivate mutating func le<T: FixedWidthInteger>(_ value: T) {
    var v = value.littleEndian
    Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
  }
  fileprivate func slice(_ offset: Int, _ length: Int) throws -> Data {
    guard offset >= 0, length >= 0, offset <= count, length <= count - offset else {
      throw AppError.invalid("잘린 ZIP 파일입니다.")
    }
    return subdata(in: offset..<offset + length)
  }
  fileprivate func u16(_ offset: Int) throws -> UInt16 {
    let bytes = try slice(offset, 2)
    return UInt16(bytes[0]) | UInt16(bytes[1]) << 8
  }
  fileprivate func u32(_ offset: Int) throws -> UInt32 {
    let bytes = try slice(offset, 4)
    return bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset * 8) }
  }
}
