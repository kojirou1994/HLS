import Algorithms

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
