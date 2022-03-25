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
  let tmp: String

  init(tmp: String?) throws {
    let proxy = HTTPClient.Configuration.Proxy.environment(.init(parseUppercaseKey: true))
    print("http proxy: \(String(describing: proxy))")
    let http = HTTPClient(eventLoopGroupProvider: .createNew, configuration: .init(proxy: proxy))
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
    if let tmp = tmp, !tmp.isEmpty {
      self.tmp = tmp
    } else {
      self.tmp = "./"
    }
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
        try! download(http: http, meta: .init(title: episode.title, subtitle: episode.subtitle ?? episode.title, href: episode.href, area: area))
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
  var fileAlreadyExisted: ((_ filename: String) -> Bool)?
  var didDownloadHref: ((_ href: String, _ filename: String) -> Void)?

  private func download(http: HTTPClient, meta: TverDownloadMeta) throws {

    let title = meta.title.isBlank ? meta.href : meta.title
    let subtitle = meta.subtitle.isBlank ? title : meta.subtitle

    let cacheDir = tmp + "/" + "[Downloading] \(title) - \(subtitle)".safeFilename()
    let tempOutFileName = "\(title) - \(subtitle)"
    let outputDirectoryName = title.safeFilename()
    let outputFilename = subtitle.safeFilename()
    var outputFileURL: URL
    do {
      let rootDirectoryURL: URL
      let maybeOldSeriesDirectoryURL = URL(fileURLWithPath: title.safeFilename())
      if let area = meta.area {
        let areaRootDirectoryURL = URL(fileURLWithPath: area.name.safeFilename())
        try fm.createDirectory(at: areaRootDirectoryURL)

        if fm.fileExistance(at: maybeOldSeriesDirectoryURL).exists {
          #warning("should join dir")
          try fm.moveItem(at: maybeOldSeriesDirectoryURL, toDirectory: areaRootDirectoryURL)
        }
        rootDirectoryURL = areaRootDirectoryURL.appendingPathComponent(outputDirectoryName)
      } else {
        rootDirectoryURL = URL(fileURLWithPath: outputDirectoryName)
      }
      outputFileURL = rootDirectoryURL
        .appendingPathComponent(outputFilename)
        .appendingPathExtension("mkv")
    }

    guard shouldDownloadHref?(meta.href) != false else {
      return
    }

    func genDBFilename(suffix: String = "") -> String {
      var str = "\(outputDirectoryName)/\(outputFilename)"
      if !suffix.isEmpty {
        str.append(" \(suffix)")
      }
      return str
    }

    var databaseSavedFilename = genDBFilename()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HHmmss"
    while URLFileManager.default.fileExistance(at: outputFileURL).exists
    || (fileAlreadyExisted?(databaseSavedFilename) == true) {
      Thread.sleep(forTimeInterval: 0.5)
      let suffix = formatter.string(from: Date()).safeFilename()
      print("Already existed: \(outputFileURL.path), try to use suffix \(suffix)")
      databaseSavedFilename = genDBFilename(suffix: suffix)
      outputFileURL = outputFileURL.deletingLastPathComponent().appendingPathComponent("\(outputFilename) \(suffix)").appendingPathExtension("mkv")
    }

    do {
      print("Downloading...\(meta)")
      let ytbJSON = try retry(body: YoutubeDL(arguments: ["-j", meta.url])
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

      try URLFileManager.default.createDirectory(at: outputFileURL.deletingLastPathComponent())

      do { // Download hls
        let hlsCli = AnyExecutable(executableName: "hls-cli", arguments: ["-o", cacheDir, "-f", tempOutFileName, bestFormat.url])

        try retry(body: hlsCli.launch(use: TSCExecutableLauncher(outputRedirection: .none)))

        try URLFileManager.default.moveItem(at: URL(fileURLWithPath: cacheDir).appendingPathComponent(tempOutFileName).appendingPathExtension("mkv"), to: outputFileURL)
      }

      do { // download all subtitles
        var subtitleContents = Set<[UInt8]>()
        Set(tverInfo.subtitles.map(\.value).joined())
          .forEach { subtitle in
            do {
              let body = try retry(body: http.get(url: subtitle.url).wait().body.unwrap("no http body when downloading subtitle"))
              let subtitleContent = body.getBytes(at: body.readerIndex, length: body.readableBytes)!
              if subtitleContents.insert(subtitleContent).inserted {
                if subtitleContent.starts(with: "#EXTM3U".utf8) {
                  print("ignored m3u8 subtitle: \(subtitle.url)")
                  return
                }
                let subURL = URLFileManager.default.makeUniqueFileURL(outputFileURL.replacingPathExtension(with: subtitle.ext))
                try Data(subtitleContent).write(to: subURL)
                print("Subtitle downloaded: \(subURL.path)")
              }
            } catch {
              print("Subtitle failed: \(subtitle)")
            }

          }
      }

      try? retry(body: URLFileManager.default.removeItem(at: URL(fileURLWithPath: cacheDir)))
      didDownloadHref?(meta.href, databaseSavedFilename)
    } catch {
      print("Downloading failed: \(error)")
    }
  }
}
