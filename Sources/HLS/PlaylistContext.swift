import Foundation

public final class PlaylistParseContext {

  var hasM3u: Bool = false
  var version: Int?
  var targetDuration: Int?
  var mediaSequenceNumber: Int?
  var playlistType: HlsTag.PlaylistType?
  var iFramesOnly: Bool?
  var endlist: Bool?
  var inf: HlsTag.Inf?
  var map: HlsTag.Map?
  #warning("non standard")
  var key: HlsTag.Key?
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

  var _verifiedPlaylisyType: _PlaylistType = .unknown

  public init() {

  }

  public func add(line: PlaylistLine.GoodLine) throws {
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
    guard case .known(let pt) = _verifiedPlaylisyType else {
      fatalError()
    }

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
#warning("not handle it now")
        break
      case .discontinuity:
#warning("not handle it now")
        break
      case .key(let v):
#warning("multiple key not supported yet")
        if programDateTime != nil {
          throw PlaylistParseError.duplicate(.key(v))
        }
        key = v
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
