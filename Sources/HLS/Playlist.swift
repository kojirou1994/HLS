import Foundation
import KwiftExtension

internal enum _PlaylistType {
  case unknown
  case known(PlaylistType)
}

public enum PlaylistType {
  case media
  case master
}

public struct Variant {
  public let uri: String
  public let streamInf: HlsTag.StreamInf
  public let videos: [HlsTag.Media]
  public let audios: [HlsTag.Media]
  public let subtitles: [HlsTag.Media]

  fileprivate init(uri: String, streamInf: HlsTag.StreamInf, medias: [HlsTag.Media]) {
    self.uri = uri
    self.streamInf = streamInf
    var videos = [HlsTag.Media]()
    var audios = [HlsTag.Media]()
    var subtitles = [HlsTag.Media]()
    medias.forEach { (media) in
      switch media.mediatype {
      case .video:
        if media.groupID == streamInf.video {
          videos.append(media)
        }
      case .audio:
        if media.groupID == streamInf.audio {
          audios.append(media)
        }
      case .subtitles:
        if media.groupID == streamInf.subtitles {
          subtitles.append(media)
        }
      default:
        break
      }
    }
    self.videos = videos
    self.audios = audios
    self.subtitles = subtitles
  }
}

public struct MasterPlaylist {

  public let url: URL

  public let medias: [HlsTag.Media]

  public let iFrameStreamInf: [HlsTag.IFrameStreamInf]

  public let variants: [Variant]

  fileprivate init(url: URL, medias: [HlsTag.Media], iFrameStreamInf: [HlsTag.IFrameStreamInf], variants: [(uri: String, streamInf: HlsTag.StreamInf)]) {
    self.url = url
    self.medias = medias
    self.iFrameStreamInf = iFrameStreamInf
    self.variants = variants.map {
      .init(uri: $0.uri, streamInf: $0.streamInf, medias: medias)

    }
  }
}

#warning("unfinished")
public struct GlobalProperty {
  public let map: HlsTag.Map?
}

public struct MediaPlaylist {

  public let url: URL

  public let version: Int

  public let globalProperty: GlobalProperty

  public let segments: [MediaSegment]

  public struct MediaSegment {
    public let uri: String
    public let inf: HlsTag.Inf
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
    try lines.notEmpty()
    try preconditionOrThrow({
      switch lines[0] {
      case .tag(.m3u): return true
      default: return false
      }
    }(), "No first line m3u tag!")
    var type = _PlaylistType.unknown
  out: for line in lines {
    switch line {
    case .tag(let tag):
      if tag.category == .masterPlaylist {
        type = .known(.master)
        break out
      } else if tag.category == .mediaPlaylist || tag.category == .mediaSegment {
        type = .known(.media)
        break out
      }
    default:
      break
    }
  }
    guard case .known(let pt) = type else {
      fatalError()
    }
    var version: Int?
    var targetDuration: Int?
    var mediaSequenceNumber: Int?
    var playlistType: HlsTag.PlaylistType?
    var iFramesOnly: Bool?
    var endlist: Bool?
    var inf: HlsTag.Inf?
    var map: HlsTag.Map?
    var gap: Bool = false
    var programDateTime: String?
    var bitrate: Int?
    var unusedTags = [HlsTag]()
    var media = [HlsTag.Media]()
    var iFrameStreamInf = [HlsTag.IFrameStreamInf]()
    var streamInf: HlsTag.StreamInf?
    var independentSegments = false
    var playlists = [(uri: String, streamInf: HlsTag.StreamInf)]()
    var segments = [MediaPlaylist.MediaSegment]()
    for line in lines[1...] {
      switch line {
      case .tag(let tag):
        // MARK: - parse tag
        switch tag {
          /// basic tags
        case .m3u:
          throw PlaylistParseError.duplicate(tag)
        case .version(let v):
          if version != nil {
            throw PlaylistParseError.duplicate(tag)
          }
          version = v.number
          /// media segment tags
        case .inf(let v):
          if inf != nil {
            throw PlaylistParseError.unused(tag)
          }
          inf = v
        case .byteRange(let v):
#warning("not handle it now")
          break
        case .discontinuity:
#warning("not handle it now")
          break
        case .key(_):
#warning("not handle it now")
          break
        case .map(let v):
          map = v
        case .programDateTime(let v):
          if programDateTime != nil {
            throw PlaylistParseError.unused(tag)
          }
          programDateTime = v.dateTime
        case .dateRange(let v):
#warning("not handle it now")
        case .gap:
          gap = true
        case .bitrate(let v):
          bitrate = v.bitrate
          /// media playlist tags
        case .targetDuration(let v):
          if targetDuration != nil {
            throw PlaylistParseError.duplicate(tag)
          }
          targetDuration = v.duration
        case .mediaSequence(let v):
          if mediaSequenceNumber != nil {
            throw PlaylistParseError.duplicate(tag)
          }
          mediaSequenceNumber = v.number
        case .discontinuitySequence(let v):
#warning("not handle it now")
          break
        case .endlist:
          if endlist != nil {
            throw PlaylistParseError.duplicate(tag)
          }
          endlist = true
#warning("should stop?")
          //                    break main
        case .playlistType(let v):
          if playlistType != nil {
            throw PlaylistParseError.duplicate(tag)
          }
          playlistType = v
        case .iFramesOnly:
          if iFramesOnly != nil {
            throw PlaylistParseError.duplicate(tag)
          }
          iFramesOnly = true
          /// master playlist tags
        case .media(let v):
          media.append(v)
        case .streamInf(let v):
          if streamInf != nil {
            throw PlaylistParseError.unused(tag)
          }
          streamInf = v
        case .iFrameStreamInf(let v):
          iFrameStreamInf.append(v)
          // Media or Master Playlist Tags
        case .independentSegments:
          independentSegments = true
        default:
          unusedTags.append(tag)
        }
      case .uri(let uri):
        //                print(uri)
        guard unusedTags.isEmpty else {
          fatalError("Unusedtags!")
        }
        unusedTags = []
        switch pt {
        case .media:
#warning("apply map, programDateTime,gap, bitrate")
          guard let infV = inf else {
            fatalError("No inf")
          }
          //                    print(infV)
          if uri != segments.last?.uri {
            segments.append(.init(uri: uri, inf: infV))
          }
          inf = nil
          programDateTime = nil
          gap = false
        case .master:

          if let streamInfV = streamInf {
            //                        print(streamInfV)
            playlists.append((uri: uri, streamInf: streamInfV))
            streamInf = nil
          } else {
            //                        playlists.append(.init(uri: uri, streamInf: nil))
            fatalError("No streamInf")
          }
        }
      }
    }
#if DEBUG
    print(pt)
#endif
    switch pt {
    case .media:
      precondition(targetDuration != nil)
      let mediaP = MediaPlaylist(
        url: url, version: version!,
        globalProperty: .init(map: map), segments: segments)
      self = .media(mediaP)
    case .master:
      let master = MasterPlaylist.init(url: url, medias: media, iFrameStreamInf: iFrameStreamInf, variants: playlists)

      self = .master(master)
    }
  }
}

