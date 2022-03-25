import AsyncHTTPClient
import HTTPDownloader
import Foundation
import NIO
import NIOHTTP1
import URLFileManager
import Krypto
import Precondition
import HLS
import MediaTools
import ExecutableLauncher
import IntegerBytes

struct HlsSegmentDownloadItem: HTTPDownloaderTaskInfoProtocol {
  let url: URL
  let segmentIndex: Int
  let tempDownloadedURL: URL

  let destinationURL: URL
  let userAgent: String

  var watchProgress: Bool { false }

  var outputURL: URL {
    tempDownloadedURL
  }

  func request() throws -> HTTPClient.Request {
    var req = try HTTPClient.Request(url: url)
    req.headers.replaceOrAdd(name: "User-Agent", value: userAgent)
    return req
  }
}

enum HlsDecryptor {
  case none
  case aes128(key: [UInt8], iv: [UInt8]?)
}

final class HlsDownloaderDelegate: HTTPDownloaderDelegate {

  typealias TaskInfo = HlsSegmentDownloadItem

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

  func downloadDidReceiveHead(
    downloader: HTTPDownloader<HlsDownloaderDelegate>,
    info: TaskInfo,
    head: HTTPResponseHead
  ) throws {
    if let value = head.headers["Content-Type"].first, value.starts(with: "application/xml") {
      throw HlsDownloaderError.invalidSegmentContentType
    }
  }

  func downloadStarted(
    downloader: HTTPDownloader<HlsDownloaderDelegate>,
    info: TaskInfo,
    task: HTTPClient.Task<HTTPClientFileDownloader.Response>
  ) {
    print("Start downloading segment \(info.segmentIndex)")
  }

  private(set) var records: [Int: (Int64, Int64)] = .init()

  func downloadProgressChanged(
    downloader: HTTPDownloader<HlsDownloaderDelegate>,
    info: TaskInfo,
    total: Int64,
    downloaded: Int64
  ) {
    records[info.segmentIndex] = (total, downloaded)
  }

  func downloadWillRetry(downloader: HTTPDownloader<HlsDownloaderDelegate>, info: HlsSegmentDownloadItem, error: Error, restRetry: Int) {
    print("Failed to download segment \(info.segmentIndex): \(error), retrying...")
  }

  func downloadFinished(
    downloader: HTTPDownloader<HlsDownloaderDelegate>,
    info: TaskInfo,
    result: Result<HTTPClientFileDownloader.Response, Error>
  ) {
    defer {
      records[info.segmentIndex] = nil
    }
    switch result {
    case .failure(let error):
      print("Segment \(info.segmentIndex) failed, downloaded: \(records[info.segmentIndex] ?? (0, 0))")
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
            bytes.append(contentsOf: IntegerBytes(seqNum, endian: .big))
            return bytes
          }

          print("Decrypting segment \(info.segmentIndex)")
          let tmpDecodedURL = tempDirectory.randomFileURL
          try preconditionOrThrow(URLFileManager.default.createFile(at: tmpDecodedURL))
          try autoreleasepool {
            let fh = try FileHandle(forWritingTo: tmpDecodedURL)
            let decodedContent = try AESCBC.decrypt(input: Data(contentsOf: info.tempDownloadedURL), key: key, iv: iv ?? genIV(seqNum: info.segmentIndex))
            try fh.kwiftWrite(contentsOf: decodedContent)
            try fh.close()
          }
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

  func downloadAllFinished(downloader: HTTPDownloader<HlsDownloaderDelegate>) {
    //    completion(error)
    if let e = error {
      promise.fail(e)
    } else {
      promise.succeed(())
    }
  }
}

public final class HLSDownloader {
  public init(http: HTTPClient, userAgent: String?, retryLimit: Int) {
    self.http = http
    self.userAgent = userAgent ?? UserAgent.safari
    self.retryLimit = retryLimit
  }

  private let http: HTTPClient
  let fm = URLFileManager()

  // MARK: Config
  private let userAgent: String
  private let retryLimit: Int
}

extension HLSDownloader {
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

    let variantResult = try http.execute(request: .init(url: variantURL)).wait()
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
      var downloadItems = [HlsSegmentDownloadItem]()

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
          .init(url: segmentURL, segmentIndex: offset, tempDownloadedURL: outputURL, destinationURL: destinationURL, userAgent: userAgent)
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
          let mediaPlaylistBody = try http.execute(request: .init(url: mediaPlaylistURL)).wait()
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
              .init(url: segmentURL, segmentIndex: offset, tempDownloadedURL: outputURL, destinationURL: destinationURL, userAgent: userAgent)
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
          let keyBody = try http.get(url: keyURL).wait().body.unwrap()
          let keyContent = try keyBody.getBytes(at: keyBody.readerIndex, length: keyBody.readableBytes).unwrap()
          decryptor = .aes128(key: keyContent, iv: ivBytes)
        case .sampleAES:
          fatalError("sample-aes not supported yet!")
        }
      } else {
        decryptor = .none
      }

      do {
        let promise = http.eventLoopGroup.next().makePromise(of: Void.self)
        let delegate = HlsDownloaderDelegate(promise: promise, decryptor: decryptor, tempDirectory: tempDirectory)
        let queue = HTTPDownloader(httpClient: http,
                                   retryLimit: retryLimit,
                                   maxCoucurrent: maxCoucurrent, timeout: .minutes(10),
                                   allowUncleanFinished: true,
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

import MediaUtility
import WebVTT

extension HLSDownloader {
  struct JoinFileItem {
    let inputs: [URL]
    let output: URL
  }

  func joinWebVTT(from urls: [URL]) throws -> SRTSubtitle {
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

  func joinFile(_ item: JoinFileItem, tempDirectory: URL) throws {
    if !fm.fileExistance(at: item.output).exists {
      print("Join to \(item.output.path).")
      let tempURL = tempDirectory.randomFileURL
      try joinFile(to: tempURL, inputURLs: item.inputs)
      try fm.moveItem(at: tempURL, to: item.output)
    } else {
      print("\(item.output.path) already exists.")
    }
  }

  func joinFile(to outputURL: URL, inputURLs: [URL]) throws {
    if inputURLs.count == 1 {
      try fm.copyItem(at: inputURLs[0], to: outputURL)
    } else {
      _ = fm.createFile(at: outputURL)
      let handle = try FileHandle(forWritingTo: outputURL)

      for url in inputURLs {
        try autoreleasepool {
          let data = try Data(contentsOf: url, options: .uncached)
          handle.write(data)
        }
      }
      try handle.close()
    }
  }

  func join(uri: String, baseURL: URL) throws -> URL {
    if uri.starts(with: "http://") || uri.starts(with: "https://") {
      return try URL(string: uri).unwrap("Invalid variant uri: \(uri)")
    } else {
      return baseURL.replacingLastComponent(uri)
    }
  }
}
