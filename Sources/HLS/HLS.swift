internal enum _HlsTagType: String {
    case m3u = "EXTM3U"
    case version = "EXT-X-VERSION"
    case inf = "EXTINF"
    case byteRange = "EXT-X-BYTERANGE"
    case discontinuity = "EXT-X-DISCONTINUITY"
    case key = "EXT-X-KEY"
    case map = "EXT-X-MAP"
    case programDateTime = "EXT-X-PROGRAM-DATE-TIME"
    case dateRange = "EXT-X-DATERANGE"
    case gap = "EXT-X-GAP"
    case bitrate = "EXT-X-BITRATE"
    case targetDuration = "EXT-X-TARGETDURATION"
    case mediaSequence = "EXT-X-MEDIA-SEQUENCE"
    case discontinuitySequence = "EXT-X-DISCONTINUITY-SEQUENCE"
    case endlist = "EXT-X-ENDLIST"
    case playlistType = "EXT-X-PLAYLIST-TYPE"
    case iFramesOnly = "EXT-X-I-FRAMES-ONLY"
    case media = "EXT-X-MEDIA"
    case streamInf = "EXT-X-STREAM-INF"
    case iFrameStreamInf = "EXT-X-I-FRAME-STREAM-INF"
    case sessionData = "EXT-X-SESSION-DATA"
    case sessionKey = "EXT-X-SESSION-KEY"
    case independentSegments = "EXT-X-INDEPENDENT-SEGMENTS"
    case start = "EXT-X-START"
    case define = "EXT-X-DEFINE"
    
    internal enum Attribute {
        case none
        case single
        case keyValue
    }
    
    internal var attributeType: Attribute {
        switch self {
        case .m3u, .discontinuity, .independentSegments:
            return .none
        case .version, .inf, .byteRange:
            return .single
        default:
            return .keyValue
        }
    }
    
    internal var requireURI: Bool {
        switch self {
        case .streamInf:
            return true
        default:
            return false
        }
    }
    
}

protocol _HlsTag {
    var type: _HlsTagType {get}
}

protocol _HlsRawTag: _HlsTag {
    init()
}

protocol HlsSingleValueTag: _HlsTag {
    init(_ string: String) throws
}

protocol _HlsAttributeTag: _HlsTag {
    init(_ dictionary: [String : String]) throws
}

/// 4.4
public enum HlsTag {
    
    case m3u(BasicTags.M3U)
    case version(BasicTags.Version)
    case inf(MediaSegmentTags.Inf)
    case byteRange(MediaSegmentTags.ByteRange)
    case discontinuity(MediaSegmentTags.Discontinuity)
    case key(MediaSegmentTags.Key)
    case map(MediaSegmentTags.Map)
    case programDateTime(MediaSegmentTags.ProgramDateTime)
    case dateRange(MediaSegmentTags.DateRange)
    case gap(MediaSegmentTags.Gap)
    case bitrate(MediaSegmentTags.Bitrate)
    case targetDuration(MediaPlaylistTags.TargetDuration)
    case mediaSequence(MediaPlaylistTags.MediaSequence)
    case discontinuitySequence(MediaPlaylistTags.DiscontinuitySequence)
    case endlist(MediaPlaylistTags.Endlist)
    case playlistType(MediaPlaylistTags.PlaylistType)
    case iFramesOnly(MediaPlaylistTags.IFramesOnly)
    case media(MasterPlaylistTags.Media)
    case streamInf(MasterPlaylistTags.StreamInf)
    case iFrameStreamInf(MasterPlaylistTags.IFrameStreamInf)
    case sessionData(MasterPlaylistTags.SessionData)
    case sessionKey(MasterPlaylistTags.SessionKey)
    case independentSegments(MediaOrMasterPlaylistTags.IndependentSegments)
    case start(MediaOrMasterPlaylistTags.Start)
    case define(MediaOrMasterPlaylistTags.Define)
    
    /// 4.4.1
    public struct BasicTags {
        
        /// 4.4.1.1
        public struct M3U: _HlsRawTag {
            var type: _HlsTagType {.m3u}
        }
        
        /// 4.4.1.2
        public struct Version: HlsSingleValueTag {
            var type: _HlsTagType {.version}
            
            public let number: Int
            
            init(_ string: String) throws {
                number = try string.toInt()
            }
        }
    }
    
    /// 4.4.2
    public struct MediaSegmentTags {
        
        /// 4.4.2.1
        public struct Inf: HlsSingleValueTag {
            init(_ string: String) throws {
                if let sep = string.firstIndex(of: ",") {
                    duration = String(string[..<sep])
                    title = String(string[string.index(after: sep)...])
                } else {
                    duration = string
                    title = nil
                }
            }
            
            var type: _HlsTagType {.inf}
            
            public let duration: String
            public let title: String?
        }
        
        /// 4.4.2.2
        public struct ByteRange: HlsSingleValueTag {
            init(_ string: String) throws {
                let parts = string.split(separator: "@")
                if parts.count == 2 {
                    offset = try String(parts[1]).toInt()
                } else {
                    offset = nil
                }
                length = try String(parts[0]).toInt()
            }
            
            var type: _HlsTagType {.byteRange}
            
            public let length: Int
            public let offset: Int?
        }
        
        /// 4.4.2.3
        public struct Discontinuity: _HlsRawTag {
            var type: _HlsTagType {.discontinuity}
            
            
        }
        
        /// 4.4.2.4
        public struct Key: _HlsAttributeTag {
            init(_ dictionary: [String : String]) throws {
                method = try dictionary.get("METHOD")
                fatalError()
            }
            
            var type: _HlsTagType {.key}
            
            public let method: Method
            public enum Method: String {
                case none = "NONE"
                case aes128 = "AES-128"
                case sampleAES = "SAMPLE-AES"
            }
            public let uri: String?
            public let iv: String
            public let KEYFORMAT: String?
            public let KEYFORMATVERSIONS: String?
        }
        
        /// 4.4.2.5
        public struct Map: _HlsAttributeTag {
            init(_ dictionary: [String : String]) throws {
                uri = try dictionary.get("URI")
                byteRange = dictionary["BYTERANGE"]
            }
            
            var type: _HlsTagType {.map}
            
            public let uri: String
            public let byteRange: String?
        }
        
        /// 4.4.2.6
        public struct ProgramDateTime: HlsSingleValueTag {
            init(_ string: String) throws {
                dateTime = string
            }
            
            var type: _HlsTagType {.programDateTime}
            
            public let dateTime: String
        }
        
        /// 4.4.2.7
        public struct DateRange: _HlsAttributeTag {
            init(_ dictionary: [String : String]) throws {
                fatalError()
            }
            
            var type: _HlsTagType {.dateRange}
            
            public let id: String
            public let `class`: String?
            public let startDate: String
            public let endDate: String?
            public let duration: String?
            public let plannedDuration: String?
            #warning("not complete")
        }
        
        /// 4.4.2.8
        public struct Gap: _HlsRawTag {
            var type: _HlsTagType {.gap}
        }
        
        /// 4.4.2.9
        public struct Bitrate: HlsSingleValueTag {
            init(_ string: String) throws {
                bitrate = try string.toInt()
            }
            
            var type: _HlsTagType {.bitrate}
            
            public let bitrate: Int
        }
    }
    
    /// 4.4.3
    public struct MediaPlaylistTags {
        
        /// 4.4.3.1
        public struct TargetDuration: HlsSingleValueTag {
            init(_ string: String) throws {
                duration = try string.toInt()
            }
            
            var type: _HlsTagType {.targetDuration}
            
            public let duration: Int
        }
        
        /// 4.4.3.2
        public struct MediaSequence: HlsSingleValueTag {
            init(_ string: String) throws {
                number = try string.toInt()
            }
            
            var type: _HlsTagType {.mediaSequence}
            
            public let number: Int
        }
        
        /// 4.4.3.3
        public struct DiscontinuitySequence: HlsSingleValueTag {
            init(_ string: String) throws {
                number = try string.toInt()
            }
            
            var type: _HlsTagType {.discontinuitySequence}
            
            public let number: Int
        }
        
        /// 4.4.3.4
        public struct Endlist: _HlsRawTag {
            var type: _HlsTagType {.endlist}
            
            
        }
        
        /// 4.4.3.5
        public enum PlaylistType: String, HlsSingleValueTag {
            var type: _HlsTagType {.playlistType}
            
            case event = "EVENT"
            case vod = "VOD"
            
            init(_ string: String) throws {
                self = try string.toEnum()
            }
        }
        
        /// 4.4.3.6
        public struct IFramesOnly: _HlsRawTag {
            
            var type: _HlsTagType {.iFramesOnly}
            
        }
    }
    
    
    
    /// 4.4.4
    public struct MasterPlaylistTags {
        /// 4.4.4.1
        public struct Media: _HlsAttributeTag {
            init(_ dictionary: [String : String]) throws {
                mediatype = try dictionary.get("TYPE")
                uri = dictionary["URI"]
                groupID = try dictionary.get("GROUP-ID")
                language = dictionary["LANGUAGE"]
                assocLanguage = dictionary["ASSOC-LANGUAGE"]
                name = try dictionary.get("NAME")
                `default` = try dictionary["DEFAULT"]?.toEnum()
                autoselect = try dictionary["AUTOSELECT"]?.toEnum()
                forced = try dictionary["FORCED"]?.toEnum()
                instreamID = try dictionary["INSTREAM-ID"]?.toEnum()
                characteristics = dictionary["CHARACTERISTICS"]
                channels = dictionary["CHANNELS"]
                
                // check
                if mediatype == .closedCaptions {
                    precondition(uri == nil)
                }
                if mediatype != .closedCaptions {
                    precondition(instreamID == nil)
                }
                if `default` == .some(.yes), autoselect != nil {
                    precondition(autoselect! == .yes)
                }
                if mediatype != .subtitles {
                    precondition(forced == nil)
                }
                if mediatype == .audio {
                    precondition(channels != nil)
                }
            }
            
            var type: _HlsTagType {.media}
            
            public let mediatype: MediaType
            public enum MediaType: String, CustomStringConvertible {
                case audio = "AUDIO"
                case video = "VIDEO"
                case subtitles = "SUBTITLES"
                case closedCaptions = "CLOSED-CAPTIONS"
                
                public var description: String {rawValue}
            }
            public let uri: String?
            public let groupID: String
            public let language: String?
            public let assocLanguage: String?
            public let name: String
            public let `default`: Default?
            public enum Default: String, CustomStringConvertible {
                case yes = "YES"
                case no = "NO"
                
                public var description: String {rawValue}
            }
            public let autoselect: Default?
            public let forced: Default?
            public let instreamID: InstreamID?
            public enum InstreamID: RawRepresentable {
                public init?(rawValue: String) {
                    switch rawValue {
                    case "CC1":
                        self = .cc1
                    case "CC2":
                        self = .cc2
                    case "CC3":
                        self = .cc3
                    case "CC4":
                        self = .cc4
                    default:
                        if rawValue.hasPrefix("SERVICE"), let number = Int(rawValue.dropFirst(7)) {
                            self = .service(number)
                        } else {
                            return nil
                        }
                    }
                }
                
                public var rawValue: String {
                    switch self {
                    case .cc1: return "CC1"
                    case .cc2: return "CC2"
                    case .cc3: return "CC3"
                    case .cc4: return "CC4"
                    case .service(let n): return "SERVICE\(n)"
                    }
                }
                
                case cc1
                case cc2
                case cc3
                case cc4
                case service(Int)
            }
            public let characteristics: String?
            public let channels: String?
        }
        
        /// 4.4.4.2
        public struct StreamInf: _HlsAttributeTag {
            init(_ dictionary: [String : String]) throws {
                bandwidth = try dictionary.get("BANDWIDTH")
                averageBandwidth = try dictionary["AVERAGE-BANDWIDTH"]?.toInt()
                codecs = try dictionary.get("CODECS")
                resolution = dictionary["RESOLUTION"]
                frameRate = dictionary["FRAME-RATE"]
                hdcpLevel = dictionary["HDCP-LEVEL"]
                videoRange = try dictionary["VIDEO-RANGE"]?.toEnum()
                audio = dictionary["AUDIO"]
                video = dictionary["VIDEO"]
                subtitles = dictionary["SUBTITLES"]
                closedCaptions = dictionary["CLOSED-CAPTIONS"]
            }
            
            var type: _HlsTagType {.streamInf}
            
            public let bandwidth: Int
            public let averageBandwidth: Int?
            public let codecs: String
            public let resolution: String?
            public let frameRate: String?
            public let hdcpLevel: String?
            public let videoRange: VideoRange?
            public enum VideoRange: String {
                case sdr = "SDR"
                case pq = "PQ"
            }
            public let audio: String?
            public let video: String?
            public let subtitles: String?
            public let closedCaptions: String?
        }
        
        /// 4.4.4.3
        public struct IFrameStreamInf: _HlsAttributeTag {
            
            var type: _HlsTagType {.iFrameStreamInf}
            
            
            init(_ dictionary: [String : String]) throws {
                bandwidth = try dictionary.get("BANDWIDTH")
                averageBandwidth = try dictionary["AVERAGE-BANDWIDTH"]?.toInt()
                codecs = try dictionary.get("CODECS")
                resolution = dictionary["RESOLUTION"]
                
                hdcpLevel = dictionary["HDCP-LEVEL"]
                videoRange = try dictionary["VIDEO-RANGE"]?.toEnum()
                
                video = dictionary["VIDEO"]
                
                uri = try dictionary.get("URI")
            }
            
            
            public let uri: String
            public let bandwidth: Int
            public let averageBandwidth: Int?
            public let codecs: String
            public let resolution: String?
            public let hdcpLevel: String?
            public let videoRange: VideoRange?
            public typealias VideoRange = StreamInf.VideoRange
            
            public let video: String?
        }
        
        /// 4.4.4.4
        public struct SessionData: _HlsAttributeTag {
            init(_ dictionary: [String : String]) throws {
                dataID = try dictionary.get("DATA-ID")
                value = try dictionary.get("VALUE")
                uri = try dictionary.get("URI")
                language = dictionary["LANGUAGE"]
            }
            
            var type: _HlsTagType {.sessionData}
            
            public let dataID: String
            public let value: String
            public let uri: String
            public let language: String?
        }
        
        /// 4.4.4.5
        public struct SessionKey {

        }
        
        
    }
    
    /// 4.4.5
    public struct MediaOrMasterPlaylistTags {
        /// 4.4.5.1
        public struct IndependentSegments: _HlsRawTag {
            var type: _HlsTagType {.independentSegments}
        }
        
        /// 4.4.5.2
        public struct Start: _HlsAttributeTag {
            init(_ dictionary: [String : String]) throws {
                timeOffset = try dictionary.get("TIME-OFFSET")
                precise = dictionary["PRECISE"]
            }
            
            var type: _HlsTagType {.start}
            
            public let timeOffset: String
            public let precise: String?
        }
        
        public enum Define: _HlsAttributeTag {
            init(_ dictionary: [String : String]) throws {
                if let name = dictionary["NAME"] {
                    self = .kv(name: name, value: try dictionary.get("VALUE"))
                } else {
                    self = .import(try dictionary.get("IMPORT"))
                }
            }
            
            var type: _HlsTagType {.define}
            case kv(name: String, value: String)
            case`import`(String)
        }
    }
    
}

public func parse(line: String) throws {
    if !line.isEmpty, line.hasPrefix("#EXT") {
        if let sep = line.firstIndex(of: ":") {
            let tag = _HlsTagType.init(rawValue: String(line[line.index(after: line.startIndex)..<sep]))!
            switch tag.attributeType {
            case .keyValue:
                var attributes: [String : String] = [:]
                var currentIndex = line.index(after: sep)
                while let attrSepIndex = line[currentIndex...].firstIndex(of: "=") {
                    let key = line[currentIndex..<attrSepIndex]
                    let value: Substring
                    var valueStartIndex = line.index(after: attrSepIndex)
                    var valueEndIndex: String.Index
                    if line[valueStartIndex] == "\"" {
                        // find next "
                        valueStartIndex = line.index(after: valueStartIndex)
                        valueEndIndex = line[valueStartIndex...].firstIndex(of: "\"")!
                        value = line[valueStartIndex..<valueEndIndex]
                        valueEndIndex = line.index(after: valueEndIndex)
                    } else {
                        valueEndIndex = line[valueStartIndex...].firstIndex(of: ",") ?? line.endIndex
                        value = line[valueStartIndex..<valueEndIndex]
                    }
                    attributes[String(key)] =  String(value)
                    if valueEndIndex == line.endIndex {
                        break
                    }
                    currentIndex = line.index(after: valueEndIndex)
                    // find next ,
                }
                switch tag {
                case .media:
                    print(try HlsTag.MasterPlaylistTags.Media.init(attributes))
                case .streamInf:
                    print(try HlsTag.MasterPlaylistTags.StreamInf.init(attributes))
                case .iFrameStreamInf:
                    print(try HlsTag.MasterPlaylistTags.IFrameStreamInf.init(attributes))
                default:
                    break
                }
            case .none:
                fatalError()
            case .single:
                let str = String(line[line.index(after: sep)...])
                switch tag {
                case .version:
                    print(try HlsTag.BasicTags.Version.init(str))
                default:
                    fatalError()
                }
            }

        } else {
            let tag = _HlsTagType.init(rawValue: String(line[line.index(after: line.startIndex)...]))!
            precondition(tag.attributeType == .none)
            switch tag {
            case .m3u:
                print(HlsTag.BasicTags.M3U.init())
            case .independentSegments:
                print(HlsTag.MediaOrMasterPlaylistTags.IndependentSegments.init())
            default:
                fatalError()
            }
        }
    }
}
