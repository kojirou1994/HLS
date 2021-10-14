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

extension Collection where Element == URL {
  func commonExtension() -> String? {
    let extensions = Set(self.map(\.pathExtension))
    if extensions.count != 1 { fatalError() }
    return extensions.first
  }
}

public enum HlsDownloaderError: Error {
  case invalidSegmentContentType
}

public enum HlsDecryptor {
  case none
  case aes128(key: [UInt8], iv: [UInt8]?)
}

public struct HlsDownloadItem: HTTPDownloaderTaskInfoProtocol {
  public let url: URL
  public let segmentIndex: Int
  public let tempDownloadedURL: URL

  public let destinationURL: URL

  public let watchProgress: Bool = false

  public var outputURL: URL {
    tempDownloadedURL
  }

  public func request() throws -> HTTPClient.Request {
    var req = try HTTPClient.Request(url: url)
    req.headers.replaceOrAdd(name: "User-Agent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15")
    return req
  }
}

public struct DownloadError: Error {
  public let url: URL
  public let error: Error
}

public final class HlsDownloaderDelegate: HTTPDownloaderDelegate {

  public typealias TaskInfo = HlsDownloadItem

  internal init(promise: EventLoopPromise<Void>, decryptor: HlsDecryptor, tempDirectory: URL) {
    self.promise = promise
    self.decryptor = decryptor
    self.tempDirectory = tempDirectory
  }

  private let promise: EventLoopPromise<Void>
  private let decryptor: HlsDecryptor
  private let tempDirectory: URL

  var error: Error?

  deinit {
//    print(#function)
  }

  public func downloadDidReceiveHead(
    downloader: HTTPDownloader<HlsDownloaderDelegate>,
    info: TaskInfo,
    head: HTTPResponseHead
  ) throws {
    if let value = head.headers["Content-Type"].first, value.starts(with: "application/xml") {
      throw HlsDownloaderError.invalidSegmentContentType
    }
  }

  public func downloadStarted(
    downloader: HTTPDownloader<HlsDownloaderDelegate>,
    info: TaskInfo,
    task: HTTPClient.Task<HTTPClientFileDownloader.Response>
  ) {
    print("Start downloading \(info.url.lastPathComponent)")
  }

  public func downloadProgressChanged(
    downloader: HTTPDownloader<HlsDownloaderDelegate>,
    info: TaskInfo,
    total: Int64,
    downloaded: Int64
  ) {

  }

  public func downloadFinished(
    downloader: HTTPDownloader<HlsDownloaderDelegate>,
    info: TaskInfo,
    result: Result<HTTPClientFileDownloader.Response, Error>
  ) {
    switch result {
    case .failure(let error):
      print("Downloading failed")
      self.error = DownloadError(url: info.url, error: error)
      downloader.cancelAll()
    case .success:
      print("Segment \(info.segmentIndex) downloaded")
      do {
        switch decryptor {
        case .none: // no encrypt, just move file
          print("Moving")
          try URLFileManager.default.moveItem(at: info.tempDownloadedURL, to: info.destinationURL)
        case .aes128(let key, let iv):
          func genIV(seqNum: Int) -> [UInt8] {
            // see chapter 3
            let paddingCount = 16 - Int.bitWidth/UInt8.bitWidth
            var bytes = [UInt8](repeating: 0, count: paddingCount)
            bytes.append(contentsOf: seqNum.bytes)
            return bytes
          }

          print("Decrypting file \(info.tempDownloadedURL.path)")
          let tmpDecodedURL = tempDirectory.randomFileURL
          try preconditionOrThrow(fm.createFile(at: tmpDecodedURL))
          let fh = try FileHandle(forWritingTo: tmpDecodedURL)
          let decodedContent = try AES.CBC.decrypt(input: Data(contentsOf: info.tempDownloadedURL), key: key, iv: iv ?? genIV(seqNum: info.segmentIndex))
          try fh.kwiftWrite(contentsOf: decodedContent)
          try fh.close()
          print("Moving")
          try URLFileManager.default.moveItem(at: tmpDecodedURL, to: info.destinationURL)
          try? URLFileManager.default.removeItem(at: info.tempDownloadedURL)
        }
      } catch {
        self.error = error
        downloader.cancelAll()
      }
    }
  }

  public func downloadAllFinished(downloader: HTTPDownloader<HlsDownloaderDelegate>) {
    //    completion(error)
    if let e = error {
      promise.fail(e)
    } else {
      promise.succeed(())
    }
  }
}

struct JoinFileItem {
  let inputs: [URL]
  let output: URL
}

fileprivate func joinWebVTT(from urls: [URL]) throws -> SRTSubtitle {
  try SRTSubtitle(
    urls.reduce(
      into: [TimedText](),
      { now, nextVtt in
        try WebVTT.convert(webVttIn: nextVtt).forEach { text in
          if now.last != text { now.append(text) }
        }
      }
    )
  )
}

fileprivate func joinFile(_ item: JoinFileItem, tempDirectory: URL) throws {
  if !fm.fileExistance(at: item.output).exists {
    print("Join to \(item.output.path).")
    let tempURL = tempDirectory.randomFileURL
    try joinFile(to: tempURL, inputURLs: item.inputs)
    try fm.moveItem(at: tempURL, to: item.output)
  } else {
    print("\(item.output.path) already exists.")
  }
}

fileprivate func joinFile(to outputURL: URL, inputURLs: [URL]) throws {
  if inputURLs.count == 1 {
    try fm.copyItem(at: inputURLs[0], to: outputURL)
  } else {
    _ = fm.createFile(at: outputURL)
    let handle = try FileHandle(forWritingTo: outputURL)

    for url in inputURLs {
      try autoreleasepool {
        let data = try Data(contentsOf: url, options: .alwaysMapped)
        handle.write(data)
      }
    }
    try handle.close()
  }
}

@inlinable
func join(uri: String, baseURL: URL) throws -> URL {
  if uri.starts(with: "http://") || uri.starts(with: "https://") {
    return try URL(string: uri).unwrap("Invalid variant uri: \(uri)")
  } else {
    return baseURL.replacingLastComponent(uri)
  }
}

extension HTTPClient {
  public func download(
    variant: ResolvedVariant,
    baseURL: URL,
    outputBaseURL: URL,
    workDirectory: URL,
    tempDirectory: URL,
    overwrite: Bool = true,
    maxCoucurrent: Int = 4
  ) throws -> URL {
    try fm.createDirectory(at: tempDirectory)
    let variantURL = try join(uri: variant.uri, baseURL: baseURL)

    let variantResult = try self.execute(request: Request(url: variantURL)).wait()
    let variantBody = try variantResult.body.unwrap()
    let variantData = try variantBody.getData(
      at: variantBody.readerIndex,
      length: variantBody.readableBytes
    ).unwrap()
    let variantPlaylist = try Playlist(data: variantData, url: variantURL)

    switch variantPlaylist {
    case .media(let mediaPlaylist):

      let rootDownloadDirectory = workDirectory

      /// All items need to be downloaded
      var downloadItems = [HlsDownloadItem]()

      let mainSegmentURLs = try mediaPlaylist.segments.map {
//        mediaPlaylist.url.replacingLastComponent($0.uri)
        try join(uri: $0.uri, baseURL: mediaPlaylist.url)
      }

      let mainSegmentExtension = mainSegmentURLs.commonExtension()!
      switch mainSegmentExtension {
      case "ts", "aac": break
      case "mp4":
        if (mainSegmentURLs.count != 1) {
          // many mp4 segments
        }
      default: fatalError("Unsupported segment extension: \(mainSegmentExtension)!")
      }

      let mainDownloadDirectory = rootDownloadDirectory.appendingPathComponent("main")
      try fm.createDirectory(at: mainDownloadDirectory)

      mainSegmentURLs.enumerated().forEach { offset,segmentURL in
        let destinationURL = mainDownloadDirectory.appendingPathComponent(
          segmentURL.lastPathComponent
        )

        if fm.fileExistance(at: destinationURL).exists { return }
        let outputURL = tempDirectory.randomFileURL
        downloadItems.append(
          .init(url: segmentURL, segmentIndex: offset, tempDownloadedURL: outputURL, destinationURL: destinationURL)
        )
      }

      let mainItem = JoinFileItem(
        inputs: mainSegmentURLs.map {
          mainDownloadDirectory.appendingPathComponent($0.lastPathComponent)
        },
        output: rootDownloadDirectory.appendingPathComponent("main").appendingPathExtension(
          mainSegmentExtension
        )
      )

      func handle(medias: [HlsTag.Media], prefix: String) throws -> [JoinFileItem] {
        try medias.enumerated().map { offset, media -> JoinFileItem in
          let mediaPlaylistURL = try join(uri: media.uri.unwrap(), baseURL: baseURL)
          let mediaPlaylistBody = try self.execute(request: Request(url: mediaPlaylistURL)).wait()
            .body.unwrap()
          let mediaPlaylistData = try mediaPlaylistBody.getData(
            at: mediaPlaylistBody.readerIndex,
            length: mediaPlaylistBody.readableBytes
          ).unwrap()
          let mediaPlaylist = try Playlist(data: mediaPlaylistData, url: mediaPlaylistURL)

          guard case .media(let mediaMediaPlaylist) = mediaPlaylist else {
            fatalError("Must be media playlist")
          }

          let mediaSegmentURLs = try mediaMediaPlaylist.segments.map {
//            audioMediaPlaylist.url.replacingLastComponent($0.uri)
            try join(uri: $0.uri, baseURL: mediaMediaPlaylist.url)
          }
          var mediaSegmentExtension = try mediaSegmentURLs.commonExtension().unwrap()
          switch mediaSegmentExtension {
          case "aac": break
          case "webvtt": mediaSegmentExtension = "srt"
          case "mp4":
            if mediaSegmentURLs.count != 1 {
              print("Many mp4")
            }
          default: fatalError("Unsupported!")
          }

          let thisMediaName = "\(prefix)\(offset)"
          let thisMediaDownloadDirectory = rootDownloadDirectory.appendingPathComponent(
            thisMediaName
          )
          try fm.createDirectory(at: thisMediaDownloadDirectory)

          mediaSegmentURLs.enumerated().forEach { offset, segmentURL in
            let destinationURL = thisMediaDownloadDirectory.appendingPathComponent(
              segmentURL.lastPathComponent
            )

            if fm.fileExistance(at: destinationURL).exists { return }
            let outputURL = tempDirectory.randomFileURL
            downloadItems.append(
              .init(url: segmentURL, segmentIndex: offset, tempDownloadedURL: outputURL, destinationURL: destinationURL)
            )
          }

          return .init(
            inputs: mediaSegmentURLs.map {
              thisMediaDownloadDirectory.appendingPathComponent($0.lastPathComponent)
            },
            output: rootDownloadDirectory.appendingPathComponent(thisMediaName)
              .appendingPathExtension(mediaSegmentExtension)
          )
        }
      }

      let audioFileItems = try handle(medias: variant.audios, prefix: "audio")
      let subtitleFileItems = try handle(medias: variant.subtitles, prefix: "subtitle")

      let decryptor: HlsDecryptor
      if let key = mediaPlaylist.globalProperty.key {
        switch key.method {
        case .none:
          decryptor = .none
        case .aes128:
          let keyURL = try key.uri.unwrap("NO URI!")
          let ivBytes = try key.iv.map([UInt8].init(hexString:))
          let keyBody = try self.get(url: keyURL).wait().body.unwrap()
          let keyContent = try keyBody.getBytes(at: keyBody.readerIndex, length: keyBody.readableBytes).unwrap()
          decryptor = .aes128(key: keyContent, iv: ivBytes)
        case .sampleAES:
          fatalError("sample-aes not supported yet!")
        }
      } else {
        decryptor = .none
      }

      do {
        let promise = eventLoopGroup.next().makePromise(of: Void.self)
        let delegate = HlsDownloaderDelegate(promise: promise, decryptor: decryptor, tempDirectory: tempDirectory)
        let queue = HTTPDownloader(httpClient: self,
                                   maxCoucurrent: maxCoucurrent, timeout: .minutes(10),
                                   delegate: delegate)
        queue.download(contentsOf: downloadItems)

        try promise.futureResult.wait()
      }

      func mediaToMkvInput(_ files: [URL], _ medias: [HlsTag.Media]) -> [MkvMerge.Input] {
        zip(files, medias).map {
          MkvMerge.Input(
            file: $0.path,
            options: [
              .language(tid: 0, language: $1.language ?? "und"),
              .trackName(tid: 0, name: $1.name),
            ]
          )
        }
      }

      // join
      try (CollectionOfOne(mainItem) + audioFileItems).forEach { try joinFile($0, tempDirectory: tempDirectory) }

      switch mainSegmentExtension {
      case "aac":
        if audioFileItems.isEmpty {
          // remux aac to m4a
          let finalOutputURL = outputBaseURL.appendingPathExtension("m4a")
          if !fm.fileExistance(at: finalOutputURL).exists || overwrite {
            let tempOutputURL = tempDirectory.randomFileURL.appendingPathExtension("m4a")

            _ = try AnyExecutable(
              executableName: "ffmpeg",
              arguments: ["-nostdin", "-i", mainItem.output.path,
                          "-c:a", "copy", "-absf", "aac_adtstoasc",
                          "-flags", "+global_header", tempOutputURL.path])
              .launch(use: TSCExecutableLauncher(outputRedirection: .none))
            try fm.moveItem(at: tempOutputURL, to: finalOutputURL)
          }

          return finalOutputURL
        }
        else {
          fallthrough
        }
      default:
        let finalOutputURL = outputBaseURL.appendingPathExtension("mkv")
        if !fm.fileExistance(at: finalOutputURL).exists || overwrite {
          let tempOutputURL = tempDirectory.randomFileURL.appendingPathExtension("mkv")

          _ = try MkvMerge(
            global: .init(quiet: false),
            output: tempOutputURL.path,
            inputs: CollectionOfOne(.init(file: mainItem.output.path))
              + mediaToMkvInput(audioFileItems.map(\.output), variant.audios)//          + mediaToMkvInput(convertedSRTFiles, variant.subtitles))
          )
          .launch(use: TSCExecutableLauncher(outputRedirection: .none))

          try fm.moveItem(at: tempOutputURL, to: finalOutputURL)
        }

        try zip(variant.subtitles, subtitleFileItems).forEach { subMedia, subtitle in
//          switch subtitle.output.pathExtension {
//            case "srt"
//          }
          try joinWebVTT(from: subtitle.inputs).export()
            .write(to: outputBaseURL.appendingPathExtension(subMedia.language ?? "und").appendingPathExtension(subtitle.output.pathExtension), atomically: true, encoding: .utf8)
        }

        return finalOutputURL
      }
    default: throw NSError(domain: "must be media playlist", code: 0, userInfo: nil)
    }
  }
}
extension URL {

  @inlinable func replacingLastComponent(_ str: String) -> URL {
    deletingLastPathComponent().appendingPathComponent(str)
  }

  @inlinable var randomFileURL: URL { appendingPathComponent(UUID().uuidString) }

}

public enum HlsDownloadError: Error { case noValidStream }

private struct Aria2BatchDownload: Executable {
  static let executableName: String = "aria2c"
  let arguments: [String]

  init(
    inputFile: String,
    outputDir: String
  ) {
    arguments = [
      "-i", inputFile, "-d", outputDir, "-j", "10", "--file-allocation", "trunc", "--continue",
      "true", "--console-log-level", "warn", "--summary-interval", "0",
    ]
  }
}

let fm = URLFileManager()
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
