import Foundation
import Logging

public struct PlaylistParseContext {

  var hasM3u: Bool = false
  var version: Int?

  // MARK: Tags apply only to the next Media Segment
  var inf: HlsTag.Inf?
  var byteRange: HlsTag.ByteRange?
  var discontinuity: Bool = false
  var programDateTime: HlsTag.ProgramDateTime?
  var gap: Bool = false

  // MARK: Tags apply to every Media Segment between it and the next same tag in the Playlist file (or the end of the Playlist file)
  var map: HlsTag.Map?
  var bitrate: Int?
  var key: HlsTag.Key?

  // MARK: Media Playlist Tags
  /// maximum Media Segment duration
  var targetDuration: Int?
  /// Media Sequence Number of the first Media Segment
  var mediaSequenceNumber: Int?
  var discontinuitySequence: HlsTag.DiscontinuitySequence?
  var endlist: Bool = false
  var playlistType: HlsTag.PlaylistType?
  var iFramesOnly: Bool = false

  // MARK: Master Playlist Tags
  var media = [HlsTag.Media]()
  var streamInf: HlsTag.StreamInf?
  var iFrameStreamInf = [HlsTag.IFrameStreamInf]()

  // MARK: Media or Master Playlist Tags
  var independentSegments = false
  var playlists = [(uri: String, streamInf: HlsTag.StreamInf)]()
  var segments = [MediaPlaylist.MediaSegment]()

  // MARK: Result
  var _verifiedPlaylisyType: _PlaylistType = .unknown

  /// parsed lines
  public private(set) var lines: [PlaylistLine.GoodLine] =  []
  var unusedTags = [HlsTag]()
  private let logger: Logger?

  public init(logger: Logger? = nil) {
    self.logger = logger
  }

  public mutating func add(line: PlaylistLine.GoodLine) throws {

    if case .unknown = _verifiedPlaylisyType {
      // verify
      switch line {
      case .tag(let tag):
        if tag.category == .masterPlaylist {
          _verifiedPlaylisyType = .known(.master)
        } else if tag.category == .mediaPlaylist || tag.category == .mediaSegment {
          _verifiedPlaylisyType = .known(.media)
        }
      default:
        break
      }
    }

    // must know playlist type
//    guard case .known(let pt) = _verifiedPlaylisyType else {
//      fatalError()
//    }

    // MARK: read line
    switch line {
    case .tag(let tag):
      // MARK: - parse tag
      switch tag {
        /// basic tags
      case .m3u:
        if hasM3u {
          throw PlaylistParseError.duplicate(tag)
        }
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
        byteRange = v
      case .discontinuity:
        discontinuity = true
      case .key(let v):
        // TODO: multiple EXT-X-KEY tags
        key = v
      case .map(let v):
        map = v
      case .programDateTime(let v):
        programDateTime = v
      case .dateRange(let v):
        // TODO: Handle it
        print("ignored date range: \(v)")
        break
      case .gap:
        gap = true
      case .bitrate(let v):
        bitrate = v.bitrate
        /// media playlist tags
      case .targetDuration(let v):
        targetDuration = v.duration
      case .mediaSequence(let v):
        mediaSequenceNumber = v.number
      case .discontinuitySequence(let v):
        discontinuitySequence = v
      case .endlist:
        endlist = true
      case .playlistType(let v):
        playlistType = v
      case .iFramesOnly:
        iFramesOnly = true
        /// master playlist tags
      case .media(let v):
        media.append(v)
      case .streamInf(let v):
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
      switch _verifiedPlaylisyType {
      case .unknown: fatalError()
      case .known(.media):
        guard let infV = inf else {
          fatalError("No inf")
        }
        let segment = MediaPlaylist.MediaSegment(
          uri: uri, inf: infV, byteRange: byteRange,
          discontinuity: discontinuity, map: map,
          programDateTime: programDateTime, gap: gap,
          bitrate: byteRange == nil ? bitrate : nil
        )

        // preserve duplicated segment
        if segment != segments.last {
          segments.append(segment)
        }

        // clean uri properties
        inf = nil
        byteRange = nil
        discontinuity = false
        programDateTime = nil
        gap = false
      case .known(.master):
        if let streamInfV = streamInf {
          playlists.append((uri: uri, streamInf: streamInfV))
          streamInf = nil
        } else {
          fatalError("No streamInf")
        }
      }
    } // line parsing

    lines.append(line)
  }

  public func result(url: URL) throws -> Playlist {
    guard case .known(let pt) = _verifiedPlaylisyType else {
      fatalError()
    }
    switch pt {
    case .media:
      precondition(targetDuration != nil)
      let mediaP = MediaPlaylist(
        url: url, version: version!,
        globalProperty: .init(map: map, key: key), segments: segments)
      return .media(mediaP)
    case .master:
      let master = MasterPlaylist(url: url, medias: media, iFrameStreamInf: iFrameStreamInf, variants: playlists)

      return .master(master)
    }
  }

}
