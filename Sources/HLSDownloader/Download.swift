import AsyncHTTPClient
import ExecutableDescription
import ExecutableLauncher
import Foundation
import HLS
import HTMLString
import HTTPDownloader
import KwiftUtility
import MediaTools
import MediaUtility
import NIO
import NIOHTTP1
import URLFileManager
import WebVTT
import Krypto
import CryptoKit

/*
extension Playlist {

  public func download(outputPath: URL, tempPath: URL, width: Int = 1920) throws {
    try fm.createDirectory(at: tempPath)
    switch self {
    case .media(let mediaP):
      let downloadTempPath = tempPath.appendingPathComponent(UUID().uuidString)
      let linkFile = tempPath.appendingPathComponent("\(UUID().uuidString).txt").path
      try mediaP.segments.map {
        mediaP.url.deletingLastPathComponent().appendingPathComponent($0.uri).absoluteString
      }.joined(separator: "\n").write(toFile: linkFile, atomically: true, encoding: .utf8)
      let aria = Aria2BatchDownload.init(inputFile: linkFile, outputDir: downloadTempPath.path)
      _ = try retry(
        body: try aria.runTSC(),
        onError: { (index, error) in

        }
      )
      _ = try Mkvmerge(
        global: .init(quiet: false),
        output: outputPath.path,
        inputs: mediaP.segments.enumerated().map {
          Mkvmerge.Input(
            file: downloadTempPath.appendingPathComponent(
              URL(string: $0.element.uri)!.lastPathComponent
            ).path,
            append: $0.offset != 0,
            options: [.noChapters]
          )
        }
      ).runTSC()
    case .master(let masterP):
      guard
        let maxStream = masterP.variants.first(where: {
          ($0.streamInf.resolution?.width ?? 0) == width
        })
      else { throw HlsDownloadError.noValidStream }
      let subP = try Playlist.init(url: masterP.url.replacingLastComponent(maxStream.uri))

      let vStreamO = tempPath.appendingPathComponent("\(UUID().uuidString).mkv")
      try subP.download(outputPath: vStreamO, tempPath: tempPath)
      let aStreamOs = try maxStream.downloadAudios(
        baseURL: masterP.url,
        outputPrefix: vStreamO.deletingPathExtension(),
        tempPath: tempPath
      )
      // join
      try Mkvmerge(
        global: .init(quiet: false),
        output: outputPath.path,
        inputs: ([vStreamO] + aStreamOs).map { Mkvmerge.Input.init(file: $0.path) }
      ).runTSC()
      try maxStream.downloadSubtitles(
        baseURL: masterP.url,
        outputPrefix: outputPath.deletingPathExtension()
      )
    }
  }
}

extension Variant {

  func downloadAudios(baseURL: URL, outputPrefix: URL, tempPath: URL) throws -> [URL] {
    return try audios.enumerated().map { (offset, audio) -> URL in
      let m3u8 = baseURL.replacingLastComponent(audio.uri!)
      let playlist = try Playlist.init(url: m3u8)
      guard case .media(let media) = playlist else { fatalError() }
      let segmentExtension = URL(string: media.segments[0].uri)!.pathExtension
      switch segmentExtension {
      case "aac", "mp4":
        let downloadTempPath = tempPath.appendingPathComponent(UUID().uuidString)
        let linkFile = tempPath.appendingPathComponent("\(UUID().uuidString).txt")
        try media.segments.map {
          media.url.deletingLastPathComponent().appendingPathComponent($0.uri).absoluteString
        }.joined(separator: "\n").write(toFile: linkFile.path, atomically: true, encoding: .utf8)
        let aria = Aria2BatchDownload.init(
          inputFile: linkFile.path,
          outputDir: downloadTempPath.path
        )
        _ = try retry(
          body: try aria.runTSC(),
          onError: { (index, error) in

          }
        )
        let output = outputPrefix.appendingPathExtension(
          "\(offset).\(audio.language ?? audio.name).mka"
        )
        try Mkvmerge(
          global: .init(quiet: true),
          output: output.path,
          inputs: media.segments.enumerated().map {
            Mkvmerge.Input.init(
              file: downloadTempPath.appendingPathComponent(
                URL(string: $0.element.uri)!.lastPathComponent
              ).path,
              append: $0.offset != 0,
              options: [.language(tid: 0, language: audio.language ?? "und")]
            )
          }
        ).runTSC()
        return output
      default: fatalError("Unsupported segment extension: \(segmentExtension)")
      }
    }
  }

  public func downloadSubtitles(baseURL: URL, outputPrefix: URL) throws {
    try subtitles.forEach { (subtitle) in

      //            if subtitle.name != "简体中文" { return [] }

      let m3u8 = baseURL.replacingLastComponent(subtitle.uri!)
      let playlist = try Playlist.init(url: m3u8)
      guard case .media(let media) = playlist else { fatalError() }
      let result: [TimedText]
      switch URL(string: media.segments[0].uri)!.pathExtension {
      case "webvtt":
        result = try media.segments.reduce(
          into: [],
          {
            $0.append(contentsOf: try WebVTT.convert(webVttIn: m3u8.replacingLastComponent($1.uri)))
          }
        )
      default: fatalError()
      }

      // write
      let srt = SRTSubtitle(result)
      try srt.export().write(
        toFile: outputPrefix.appendingPathExtension("\(subtitle.language ?? subtitle.name).srt")
          .path,
        atomically: true,
        encoding: .utf8
      )
    }
  }

}
*/
