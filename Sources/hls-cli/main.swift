import Foundation
import ArgumentParser
import AsyncHTTPClient
import HLS
import HLSDownloader
import KwiftUtility

public enum HlsInput {
  case remote(url: URL)
//  case local(content: Data, baseUrl: URL)
}

public enum HlsInputParseError: Error {
  case invalidInput
}

public func parseInput(string: String) -> Result<HlsInput, HlsInputParseError> {
//  let baseURL: URL?
//  if !baseUrl.isEmpty {
//    baseURL = try URL(string: baseUrl).unwrap()
//  } else {
//    baseURL = nil
//  }
  guard let url = URL(string: string) else {
    return .failure(.invalidInput)
  }
  return .success(.remote(url: url))
}

extension HLSDownloader {
  func load(input: HlsInput) throws -> Playlist {
    switch input {
    case .remote(let url):
      fatalError()
    }
  }
}

struct HlsCli: ParsableCommand {

  @Option(name: .shortAndLong, help: "Output directory")
  var output: String = "./hls-download"

  @Option(name: .shortAndLong)
  var filename: String

  @Option(name: [.customLong("ua")])
  var userAgent: String?

  @Option(help: "Retry limit for segment download error")
  var retry: Int = 4

  @Option(help: "Max download concurrent count")
  var threads: Int = 8

  @Option(name: .shortAndLong)
  var audio: [String] = []

  @Argument
  var url: String

  func run() throws {
    let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
    defer {
      try! httpClient.syncShutdown()
    }

    let url = try URL(string: url).unwrap("Invalid url!")

    let rootDirectoryURL = URL(fileURLWithPath: output)

    let workDirectory = rootDirectoryURL.appendingPathComponent(filename)
    let tempDirectory = rootDirectoryURL.appendingPathComponent("tmp")

    let hlsDownloader = HLSDownloader(http: httpClient, userAgent: userAgent, retryLimit: retry)
    let variant = ResolvedVariant(uri: self.url, streamInf: .init(bandwidth: 0), videos: [.init(mediatype: .video, uri: self.url)], audios: audio.map { .init(mediatype: .audio, uri: $0) }, subtitles: [])
    let fileURL = try hlsDownloader.download(variant: variant, baseURL: url.deletingLastPathComponent(), outputBaseURL: workDirectory, workDirectory: workDirectory, tempDirectory: tempDirectory, maxCoucurrent: threads)

    print("Downloaded to: \(fileURL.path)")
  }
}

HlsCli.main()
