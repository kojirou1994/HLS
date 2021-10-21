import ArgumentParser
import Foundation
import URLFileManager

struct TverYTBInfo: Codable {
  let formats: [Format]

  let subtitles: [String: [Subtitle]]

  struct Subtitle: Codable {
    let url: String
    let ext: String
  }

  struct Format: Codable, CustomStringConvertible {
    let format_id: String
    let url: String
    let manifest_url: String
    let width: Int?
    let height: Int?
    let vcodec: String
    let acodec: String?
    let `protocol`: YTBProtocol
    enum YTBProtocol: String, Codable, CustomStringConvertible {
      case m3u8_native
      case http_dash_segments

      var description: String { rawValue }

    }

    var description: String {
      "\(String(describing: Self.self))(formatID: \(format_id), width: \(width ?? 0), height: \(height ?? 0), vcodec: \(vcodec), acodec: \(acodec ?? "none"), protocol: \(`protocol`))"
    }
  }
}

import Networking
import AsyncHTTPClientNetworking

class TverAPI: AsyncHTTPClientNetworking {
  internal init(client: HTTPClient, token: String) {
    self.client = client
    self.urlComponents = .init()
    urlComponents.scheme = "https"
    urlComponents.host = "api.tver.jp"
    urlComponents.path = "/v4"
    urlComponents.queryItems = [.init(name: "token", value: token)]
    self.commonHTTPHeaders = .init()
  }

  let client: HTTPClient

  private(set) var urlComponents: URLComponents

  private(set) var commonHTTPHeaders: HTTPHeaders

}

struct TverInfo: Endpoint {
  let category: TverCategory
  let videoID: String
  var path: String {
    "/\(category)/\(videoID)"
  }

  typealias ResponseBody = TverMediaInfo
}

class TverLogin: AsyncHTTPClientNetworking {
  internal init(client: HTTPClient) {
    self.client = client
    self.urlComponents = .init()
    urlComponents.scheme = "https"
    urlComponents.host = "tver.jp"
    self.commonHTTPHeaders = .init()
  }

  let client: HTTPClient

  private(set) var urlComponents: URLComponents

  private(set) var commonHTTPHeaders: HTTPHeaders

}

struct TverToken: Endpoint {
  var path: String {
    "/api/access_token.php"
  }

  struct ResponseBody: Decodable {
    let url: String
    let token: String
  }

}
import NIO
import NIOFoundationCompat
import KwiftUtility
import ExecutableDescription
import ExecutableLauncher

public struct TverMediaInfo: Codable {
  public let main: Main
  public struct Main: Codable {
    public let catchupId: String
    public let date: String
    public let href: String
    public let lp: String
    public let media: String
    public let mylistId: String
    public let note: [Note]
    public struct Note: Codable {
      public let text: String
      private enum CodingKeys: String, CodingKey {
        case text
      }
    }
    public let player: String
    public let pos: String
    public let publisherId: String
    public let referenceId: String
    public let service: String
    public let subtitle: String
    public let title: String
    public let type: String
    public let url: String?
    private enum CodingKeys: String, CodingKey {

      case catchupId = "catchup_id"
      case date

      case href

      case lp
      case media
      case mylistId = "mylist_id"
      case note

      case player
      case pos
      case publisherId = "publisher_id"
      case referenceId = "reference_id"
      case service
      case subtitle

      case title
      case type
      case url
    }
  }
  public let mylist: Mylist
  public struct Mylist: Codable {
    public let count: Int
    private enum CodingKeys: String, CodingKey {
      case count
    }
  }

  public let episode: [Episode]?
  public struct Episode: Codable {
    public let title: String
    public let subtitle: String
    public let href: String
  }
  private enum CodingKeys: String, CodingKey {
    case main
    case mylist
    case episode
  }
}

struct TverDownloadMeta {
  let title: String
  let subtitle: String
  let href: String

  var url: String {
    "https://tver.jp\(href)"
  }
}

func download(http: HTTPClient, meta: TverDownloadMeta) {

  let cacheDir = "[Downloading] \(meta.title) - \(meta.subtitle)".safeFilename()
  let tempOutFileName = "\(meta.title) - \(meta.subtitle)"
  let outputFile = URL(fileURLWithPath: meta.title.safeFilename())
    .appendingPathComponent(meta.subtitle.safeFilename())
    .appendingPathExtension("mkv")
  if URLFileManager.default.fileExistance(at: outputFile).exists {
    print("Already existed: \(outputFile.path)")
    return
  }

  do {
    print("Downloading...\(meta)")
    let ytbJSON = try retry(body: AnyExecutable(executableName: "youtube-dl", arguments: ["-j", meta.url])
      .launch(use: TSCExecutableLauncher())
      .output.get()
      )
    let tverInfo = try JSONDecoder().kwiftDecode(from: ytbJSON, as: TverYTBInfo.self)

    print("all formats:")
    tverInfo.formats.forEach { format in
      print(format)
    }
    let format = try tverInfo.formats.filter { $0.vcodec != "none" && $0.acodec != nil && $0.protocol == .m3u8_native }.last.unwrap("No valid formats")

    try URLFileManager.default.createDirectory(at: outputFile.deletingLastPathComponent())

    do { // Download hls
      let hlsCli = AnyExecutable(executableName: "hls-cli", arguments: ["-o", cacheDir, "-f", tempOutFileName, format.url])

      try retry(body: hlsCli.launch(use: TSCExecutableLauncher(outputRedirection: .none)))

      try URLFileManager.default.moveItem(at: URL(fileURLWithPath: cacheDir).appendingPathComponent(tempOutFileName).appendingPathExtension("mkv"), to: outputFile)
    }

    tverInfo.subtitles.forEach { lang, subtitles in
      subtitles.forEach { subtitle in
        do {
          let tempO = UUID().uuidString
          let curl = AnyExecutable(executableName: "curl", arguments: ["-o", tempO, subtitle.url])
          try retry(body: curl.launch(use: TSCExecutableLauncher(outputRedirection: .none)))
          let subURL = try URLFileManager.default.moveAndAutoRenameItem(at: URL(fileURLWithPath: tempO), to: outputFile.replacingPathExtension(with: subtitle.ext))
          print("Subtitle downloaded: \(subURL.path)")
        } catch {
          print("Subtitle failed: \(subtitle)")
        }
      }
    }

    try? retry(body: URLFileManager.default.removeItem(at: URL(fileURLWithPath: cacheDir)))
  } catch {
    print("Downloading failed: \(error)")
  }
}

enum TverCategory: String, CustomStringConvertible {
  case feature
  case corner

  var description: String { rawValue }
}

struct TverCli: ParsableCommand {

  @Argument
  var urls: [String]

  func run() throws {

    let http = HTTPClient(eventLoopGroupProvider: .createNew)
    defer {
      try? http.syncShutdown()
    }
    let loginAPI = TverLogin(client: http)
    print("logging in")
    #if DEBUG
    let token = "t1.1666023555.eyJhcGlrZXkiOiJlMjRmYWEyMS0zMTNjLTRjNjItYjlkMi0wNzJmMjI3ZWVkZGQiLCJ1c2VyIjoiMTI3YTI4ZDgtZTQyNS04OGY2LTA4ZWEtNmVmYTkyMDI4YWY2In0.49331739.27516aee2cff4034a14f9a1eb957bf9c"
    #else
    let token = try loginAPI.eventLoopFuture(TverToken()).wait().body.get().token
    #endif
    print("token: \(token)")
    let tverAPI = TverAPI(client: http, token: token)
    for urlString in urls {
      do {
        let url = try URL(string: urlString).unwrap()
        let pathComponents = url.pathComponents
        try preconditionOrThrow(pathComponents.count == 3, "\(pathComponents)")
        let category = try TverCategory(rawValue: pathComponents[1].lowercased()).unwrap()

        let info =
        TverInfo(category: category, videoID: pathComponents[2])
        let dramaInfo = try tverAPI.eventLoopFuture(info).wait().body.get()
        if let episodes = dramaInfo.episode, !episodes.isEmpty {
          episodes.forEach { episode in
            download(http: http, meta: .init(title: episode.title, subtitle: episode.subtitle, href: episode.href))
          }
        } else {
          download(http: http, meta: .init(title: dramaInfo.main.title, subtitle: dramaInfo.main.subtitle, href: dramaInfo.main.href))
        }
      } catch {
        print("Failed input: \(urlString)", error)
      }

    }

  }

}

TverCli.main()
