import Foundation
import MediaUtility
import HTMLString

// MARK: Web VTT to SRT
public enum WebVTT {
  public static func convert(webVttIn fileURL: URL) throws -> [TimedText] {
    try autoreleasepool {
      try convert(
        webVtt: String(contentsOf: fileURL)
          .components(separatedBy: .newlines)
      )
    }
  }

  public static func convert<S: StringProtocol>(webVtt lines: [S]) throws -> [TimedText] {
    var result = [TimedText]()
    var needSub = false
    var start: Timestamp?
    var end: Timestamp?
    var subtitleLines = [Substring]()
    var getSub = false

    func appendSub() {
      if getSub {
        let subtitle = TimedText(start: start!, end: end!, text: subtitleLines.joined(separator: "\n"))

        if let last = result.last, subtitle == last {
          #if DEBUG
          print("ignored duplicate subtitle: \(subtitle)")
          #endif
        } else {
          result.append(subtitle)
        }
        getSub = false
        needSub = false
        subtitleLines = []
      }
    }

    for line in lines {
      if line.isBlank {
        appendSub()
        continue
      }
      let parts = line.split(separator: " ")
      if parts.count >= 3, let s = Timestamp(String(parts[0])),
        parts[1] == "-->", let e = Timestamp(String(parts[2])) {
        appendSub()
        needSub = true
        start = s
        end = e
      } else if needSub {
        subtitleLines.append(String(line).removingHTMLEntities.trim{$0.isWhitespace || $0.isNewline})
        getSub = true
      }
    }

    appendSub()

    return result
  }


}
