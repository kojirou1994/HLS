import Algorithms
import Foundation

extension Array where Element == UInt8 {
  init<S: StringProtocol>(hexString: S) throws {
    self.init()
    var string = hexString[hexString.startIndex...]
    if string.hasPrefix("0x") {
      string = string.dropFirst(2)
    }
    string.chunks(ofCount: 2).forEach { hex in
      append(Element(hex, radix: 16)!)
    }
  }
}

extension Collection where Element == URL {
  func commonExtension() -> String? {
    let extensions = Set(self.map(\.pathExtension))
    if extensions.count != 1 { fatalError() }
    return extensions.first
  }
}

extension URL {

  func replacingLastComponent(_ str: String) -> URL {
    deletingLastPathComponent().appendingPathComponent(str)
  }

  var randomFileURL: URL {
    appendingPathComponent(UUID().uuidString)
  }

}
