import AsyncHTTPClient
import AsyncHTTPClientProxy
import Foundation
import Precondition
import URLFileManager
import KwiftUtility
import ExecutableLauncher

final class TverDownloader {

  let baseComponents: URLComponents
  let http: HTTPClient
  let fm = URLFileManager.default

  init() throws {
    let http = HTTPClient(eventLoopGroupProvider: .createNew, configuration: .init(proxy: .environment(.init(parseUppercaseKey: true))))

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

    var urlComponents = URLComponents()
    urlComponents.scheme = "https"
    urlComponents.host = "api.tver.jp"
    urlComponents.queryItems = [.init(name: "token", value: token)]
    self.baseComponents = urlComponents
    self.http = http
  }

  deinit {
    try? http.syncShutdown()
  }

  func load(area: TverArea) throws -> TverAreaInfo {
    print("loading area \(area)")
    var urlComponents = baseComponents
    urlComponents.path = "/v4/\(area)"

    let request = try HTTPClient.Request(url: urlComponents.url.unwrap("Cannot generate url"))
    let resBody = try http.execute(request: request).wait().body.unwrap()
    
    return try JSONDecoder().decode(TverAreaInfo.self, from: resBody)
  }

  func download(url urlString: String, area: TverArea?) throws {

    let url = try URL(string: urlString).unwrap()
    let pathComponents = url.pathComponents
    try preconditionOrThrow(pathComponents.count == 3, "\(pathComponents)")
    let category = try TverCategory(rawValue: pathComponents[1].lowercased()).unwrap()

    var urlComponents = baseComponents
    urlComponents.path = "/v4/\(category)/\(pathComponents[2])"

    let request = try HTTPClient.Request(url: urlComponents.url.unwrap("Cannot generate url"))
    let resBody = try http.execute(request: request).wait().body.unwrap()
    let dramaInfo = try JSONDecoder().decode(TverMediaInfo.self, from: resBody)
    if let episodes = dramaInfo.episode, !episodes.isEmpty {
      episodes.forEach { episode in
        try! download(http: http, meta: .init(title: episode.title, subtitle: episode.subtitle, href: episode.href, area: area))
      }
    } else {
      try! download(http: http, meta: .init(title: dramaInfo.main.title, subtitle: dramaInfo.main.subtitle, href: dramaInfo.main.href, area: area))
    }
  }

  struct TverDownloadMeta {
    let title: String
    let subtitle: String
    let href: String
    let area: TverArea?

    var url: String {
      "https://tver.jp\(href)"
    }
  }

  var shouldDownloadHref: ((_ href: String) -> Bool)?
  var didDownloadHref: ((_ href: String) -> Void)?

  private func download(http: HTTPClient, meta: TverDownloadMeta) throws {

    let title = meta.title.isBlank ? meta.href : meta.title
    let subtitle = meta.subtitle.isBlank ? title : meta.subtitle

    let cacheDir = "[Downloading] \(title) - \(subtitle)".safeFilename()
    let tempOutFileName = "\(title) - \(subtitle)"
    let outputFile: URL
    do {
      let maybeOldSeriesDirectoryURL = URL(fileURLWithPath: title.safeFilename())
      let rootDirectoryURL: URL
      if let area = meta.area {
        let areaRootDirectoryURL = URL(fileURLWithPath: area.name.safeFilename())
        try fm.createDirectory(at: areaRootDirectoryURL)

        if fm.fileExistance(at: maybeOldSeriesDirectoryURL).exists {
          #warning("should join dir")
          try fm.moveItem(at: maybeOldSeriesDirectoryURL, toDirectory: areaRootDirectoryURL)
        }
        rootDirectoryURL = areaRootDirectoryURL.appendingPathComponent(title.safeFilename())
      } else {
        rootDirectoryURL = URL(fileURLWithPath: title.safeFilename())
      }
      outputFile = rootDirectoryURL
        .appendingPathComponent(subtitle.safeFilename())
        .appendingPathExtension("mkv")
    }

    guard shouldDownloadHref?(meta.href) != false else {
      return
    }
    if URLFileManager.default.fileExistance(at: outputFile).exists {
      print("Already existed: \(outputFile.path)")
      didDownloadHref?(meta.href)
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
        .filter { $0.vcodec != "none" && $0.acodec != nil && $0.acodec != "none" && $0.protocol == .m3u8_native && $0.width != nil }
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
      didDownloadHref?(meta.href)
    } catch {
      print("Downloading failed: \(error)")
    }
  }
}
