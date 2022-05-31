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

    switch try context.result(url: baseURL) {
    case .master(let master):
      print("master")
      if !master.variants.isEmpty {
        print("variants:")
        master.variants.forEach { variant in
          print(variant.uri)
          print(variant.streamInf)
          [variant.streamInf.video, variant.streamInf.audio, variant.streamInf.subtitles, variant.streamInf.closedCaptions]
            .compactMap { $0 }
            .forEach { groupID in
              let media = master.medias.first(where: { $0.groupID == groupID })!
              print(" - " + (media.uri ?? "no uri"))
              print("   " + media.cliOutput)
            }
          print("\n")
        }
      }
    case .media(let media):
      print("media")
      dump(media)
    }

    let unusedTags = context.unusedTags
    if !unusedTags.isEmpty {
      print("unused tags:")
      unusedTags.forEach { print($0) }
    }
  }
}

extension HlsTag.Media {
  var cliOutput: String {
    var parts = [(String, String)]()
    parts.append(("name", name))
    parts.append(("groupID", groupID))
    if let language = language {
      parts.append(("language", language))
    }
    if let assocLanguage = assocLanguage {
      parts.append(("assocLanguage", assocLanguage))
    }
    if let `default` = `default` {
      parts.append(("default", `default`.boolValue.description))
    }
    if let autoselect = autoselect {
      parts.append(("autoselect", autoselect.boolValue.description))
    }
    if let forced = forced {
      parts.append(("forced", forced.boolValue.description))
    }
    if let instreamID = instreamID {
      parts.append(("instreamID", instreamID.description))
    }
    if let characteristics = characteristics {
      parts.append(("characteristics", characteristics))
    }
    if let channels = channels {
      parts.append(("channels", channels))
    }
    return parts.lazy.map { $0.0 + ": " + $0.1 }.joined(separator: ", ")
  }
}
