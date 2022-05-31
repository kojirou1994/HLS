import ArgumentParser
import Foundation
import HLS

@main
struct HlsParser: AsyncParsableCommand {

  @Option
  var baseURL: String = "baseURL"

  @Argument
  var input: String

  func run() async throws {

    guard let baseURL = URL(string: baseURL) else {
      print("invalid baseURL: \(baseURL)")
      throw ExitCode(2)
    }

    let inputFileHandle: FileHandle
    if input == "-" {
      inputFileHandle = .standardInput
    } else {
      inputFileHandle = try .init(forReadingFrom: URL(fileURLWithPath: input))
    }

    let content: Data
    if #available(macOS 10.15.4, *) {
      content = try inputFileHandle.readToEnd() ?? Data()
    } else {
      // Fallback on earlier versions
      content = inputFileHandle.readDataToEndOfFile()
    }

    if content.isEmpty {
      print("empty input!")
      throw ExitCode(2)
    }

    var context = PlaylistParseContext()
    content.split(separator: UInt8(ascii: "\n"))
      .forEach { line in
        guard !line.isEmpty else {
          return
        }
        let parsedLine = try! PlaylistLine(line: String(decoding: line, as: UTF8.self))
        switch parsedLine {
        case .garbage(let garbageLine):
          print("useless line: \(garbageLine)")
        case .good(let goodLine):
          try! context.add(line: goodLine)
        }
      }

    let playlist = try context.result(url: baseURL)
    dump(playlist)
  }
}
