import Foundation

internal enum _PlaylistType {
  case unknown
  case known(PlaylistType)
}

public enum PlaylistType {
  case media
  case master
}

public struct ResolvedVariant {
  public init(uri: String, streamInf: HlsTag.StreamInf, videos: [HlsTag.Media], audios: [HlsTag.Media], subtitles: [HlsTag.Media]) {
    self.uri = uri
    self.streamInf = streamInf
    self.videos = videos
    self.audios = audios
    self.subtitles = subtitles
  }


  public let uri: String
  public let streamInf: HlsTag.StreamInf
  public let videos: [HlsTag.Media]
  public let audios: [HlsTag.Media]
  public let subtitles: [HlsTag.Media]

}

public struct Variant: CustomStringConvertible {

  public let uri: String
  public let streamInf: HlsTag.StreamInf

  public var description: String {
    "Variant(uri: \"\(uri)\", streamInf: \(streamInf))"
  }
}

public struct MasterPlaylist {

  public let url: URL

  public let medias: [HlsTag.Media]

  public let iFrameStreamInf: [HlsTag.IFrameStreamInf]

  public let variants: [Variant]

  init(url: URL, medias: [HlsTag.Media], iFrameStreamInf: [HlsTag.IFrameStreamInf], variants: [(uri: String, streamInf: HlsTag.StreamInf)]) {
    self.url = url
    self.medias = medias
    self.iFrameStreamInf = iFrameStreamInf
    self.variants = variants.map {
      .init(uri: $0.uri, streamInf: $0.streamInf)
    }
  }

  public func resolve(variant: Variant) throws -> ResolvedVariant {
    var videos = [HlsTag.Media]()
    var audios = [HlsTag.Media]()
    var subtitles = [HlsTag.Media]()
    medias.forEach { (media) in
      switch media.mediatype {
      case .video:
        if media.groupID == variant.streamInf.video {
          videos.append(media)
        }
      case .audio:
        if media.groupID == variant.streamInf.audio {
          audios.append(media)
        }
      case .subtitles:
        if media.groupID == variant.streamInf.subtitles {
          subtitles.append(media)
        }
      default:
        break
      }
    }
    return .init(uri: variant.uri, streamInf: variant.streamInf, videos: videos, audios: audios, subtitles: subtitles)
  }
}

public struct GlobalProperty {
  public let key: HlsTag.Key?
}

public struct MediaPlaylist {

  public let url: URL

  public let version: Int

  public let globalProperty: GlobalProperty

  public let segments: [MediaSegment]

  public struct MediaSegment: Equatable {
    public let uri: String
    public let inf: HlsTag.Inf
    public let byteRange: HlsTag.ByteRange?
    public let discontinuity: Bool
    public let map: HlsTag.Map?
    public let programDateTime: HlsTag.ProgramDateTime?
    public let gap: Bool
    public let bitrate: Int?
  }
}

public enum PlaylistParseError: Error {
  case duplicate(HlsTag)
  case unused(HlsTag)
}

public enum Playlist {

  case media(MediaPlaylist)
  case master(MasterPlaylist)

  public init(url: URL) throws {
    try self.init(data: .init(contentsOf: url), url: url)
  }

  public init(data: Data, url: URL) throws {
    let lines = data.split(separator: 0x0a)
      .compactMap { try? PlaylistLine(line: String(decoding: $0, as: UTF8.self))}
      .compactMap(\.goodLine)
    try self.init(lines: lines, url: url)
  }

  public init(lines: [PlaylistLine.GoodLine], url: URL) throws {
//    try lines.notEmpty()
//    try preconditionOrThrow({
//      switch lines[0] {
//      case .tag(.m3u): return true
//      default: return false
//      }
//    }(), "No first line m3u tag!")

    var context = PlaylistParseContext()
    try lines.forEach { try context.add(line: $0) }
    self = try context.result(url: url)
  }
}

