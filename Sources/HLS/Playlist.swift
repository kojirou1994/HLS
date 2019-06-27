import Foundation

internal enum _PlaylistType {
    case unknown
    case known(PlaylistType)
}

public enum PlaylistType {
    case media
    case master
}

public struct MasterPlaylist {
    
}

public struct MediaPlaylist {
    let version: Int
    let globalProperty: GlobalProperty
    
    struct GlobalProperty {
        
    }
    
    let segments: [MediaSegment]
    
    struct MediaSegment {
        let uri: String
        let inf: HlsTag.Inf
    }
}

extension PlaylistLine {
    var unignoredLine: UnignoredLine? {
        switch self {
        case .unignored(let v):
            return v
        default:
            return nil
        }
    }
}

public struct Playlist {
    
    public init(url: URL) throws {
        try self.init(data: .init(contentsOf: url), baseURL: url)
    }
    
    public init(data: Data, baseURL: URL) throws {
        let lines = try data.split(separator: 0x0a)
            .compactMap { try parse(line: String(decoding: $0, as: UTF8.self)).unignoredLine}
        precondition(!lines.isEmpty)
        guard case .tag(.m3u(_)) = lines.first! else {
            fatalError("No m3u tag!")
        }
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
        for line in lines[1...] {
            switch line {
            case .tag(let tag):
                // MARK: - parse tag
                switch tag {
                /// basic tags
                case .m3u(_):
                    fatalError("mor than one m3u tag")
                case .version(let v):
                    if version != nil {
                        fatalError("more than one version tag")
                    }
                    version = v.number
                /// media segment tags
                case .inf(let v):
                    if inf != nil {
                        fatalError("inf is not used")
                    }
                    inf = v
                case .byteRange(let v):
                    #warning("not handle it now")
                    break
                case .discontinuity(_):
                    #warning("not handle it now")
                    break
                case .key(_):
                    #warning("not handle it now")
                    break
                case .map(let v):
                    map = v
                case .programDateTime(let v):
                    if programDateTime != nil {
                        fatalError("programDateTime not used")
                    }
                    programDateTime = v.dateTime
                case .dateRange(let v):
                    #warning("not handle it now")
                case .gap(_):
                    gap = true
                case .bitrate(let v):
                    bitrate = v.bitrate
                /// media playlist tags
                case .targetDuration(let v):
                    if targetDuration != nil {
                        fatalError("more than one targetDuration tag")
                    }
                    targetDuration = v.duration
                case .mediaSequence(let v):
                    if mediaSequenceNumber != nil {
                        fatalError("more than one mediaSequenceNumber tag")
                    }
                    mediaSequenceNumber = v.number
                case .discontinuitySequence(let v):
                    #warning("not handle it now")
                    break
                case .endlist(_):
                    if endlist != nil {
                        fatalError("more than one endlist tag")
                    }
                    endlist = true
                    #warning("should stop?")
//                    break main
                case .playlistType(let v):
                    if playlistType != nil {
                        fatalError("more than one playlistType tag")
                    }
                    playlistType = v
                case .iFramesOnly(_):
                    if iFramesOnly != nil {
                        fatalError("more than one iFramesOnly tag")
                    }
                    iFramesOnly = true
                /// master playlist tags
                case .media(let v):
                    media.append(v)
                case .streamInf(let v):
                    if streamInf != nil {
                        fatalError("streamInf not used")
                    }
                    streamInf = v
                case .iFrameStreamInf(let v):
                    iFrameStreamInf.append(v)
                // Media or Master Playlist Tags
                case .independentSegments(_):
                    independentSegments = true
                default:
                    unusedTags.append(tag)
                }
            case .uri(let uri):
                print(uri)
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
                    print(infV)
                    inf = nil
                    programDateTime = nil
                    gap = false
                case .master:
                    
                    if let streamInfV = streamInf {
                        print(streamInfV)
                        streamInf = nil
                    }
                }
            }
        }
        switch pt {
        case .media:
            precondition(targetDuration != nil)
        case .master:
            print("Medias: \(media)")
            print("iFrameStreamInf: \(iFrameStreamInf)")
        }
        print(pt)
//        fatalError()
    }
}
