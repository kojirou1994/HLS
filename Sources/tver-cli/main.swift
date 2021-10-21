import ArgumentParser
import Foundation
import URLFileManager
import AsyncHTTPClient
import AsyncHTTPClientProxy
import NIO
import NIOFoundationCompat
import KwiftUtility
import ExecutableDescription
import ExecutableLauncher

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
    let tverInfo = try JSONDecoder().kwiftDecode(from: ytbJSON, as: YoutubeDLDumpInfo.self)

    print("all formats:")
    tverInfo.formats.forEach { format in
      print(format)
    }
    let bestFormat = try tverInfo.formats
      .filter { $0.vcodec != "none" && $0.acodec != nil && $0.protocol == .m3u8_native && $0.width != nil }
      .sorted(by: \.width.unsafelyUnwrapped)
      .last.unwrap("No valid formats")
    print("\nselected format: \(bestFormat)")

    try URLFileManager.default.createDirectory(at: outputFile.deletingLastPathComponent())

    do { // Download hls
      let hlsCli = AnyExecutable(executableName: "hls-cli", arguments: ["-o", cacheDir, "-f", tempOutFileName, bestFormat.url])

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

    let http = HTTPClient(eventLoopGroupProvider: .createNew, configuration: .init(proxy: .environment(.init(parseUppercaseKey: true))))
    defer {
      try? http.syncShutdown()
    }

    print("logging in")
    #if DEBUG
    let token = "t1.1666023555.eyJhcGlrZXkiOiJlMjRmYWEyMS0zMTNjLTRjNjItYjlkMi0wNzJmMjI3ZWVkZGQiLCJ1c2VyIjoiMTI3YTI4ZDgtZTQyNS04OGY2LTA4ZWEtNmVmYTkyMDI4YWY2In0.49331739.27516aee2cff4034a14f9a1eb957bf9c"
    #else
    struct TverToken: Decodable {
      let url: String
      let token: String
    }
    let tokenResBody = try http.execute(url: "https://tver.jp/api/access_token.php").wait().body.unwrap()
    let token = try JSONDecoder().decode(TverToken.self, from: tokenResBody).token
    #endif
    print("token: \(token)")

    for urlString in urls {
      do {

        let url = try URL(string: urlString).unwrap()
        let pathComponents = url.pathComponents
        try preconditionOrThrow(pathComponents.count == 3, "\(pathComponents)")
        let category = try TverCategory(rawValue: pathComponents[1].lowercased()).unwrap()

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "api.tver.jp"
        urlComponents.path = "/v4/\(category)/\(pathComponents[2])"
        urlComponents.queryItems = [.init(name: "token", value: token)]

        let request = try HTTPClient.Request(url: urlComponents.url.unwrap("Cannot generate url"))
        let resBody = try http.execute(request: request).wait().body.unwrap()
        let dramaInfo = try JSONDecoder().decode(TverMediaInfo.self, from: resBody)
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
