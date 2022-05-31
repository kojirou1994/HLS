import Foundation

internal enum Category {
  case basic
  case mediaSegment
  case mediaPlaylist
  case masterPlaylist
  case mediaOrMasterPlaylist
}

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

  internal init(_ string: String) throws {
    guard let v = _HlsTagType(rawValue: string) else {
      throw HlsTagParseError.unsupportedTag(string)
    }
    self = v
  }

  internal enum Attribute {
    case none
    case single
    case keyValue
  }

  internal var category: Category {
    switch self {
    case .m3u, .version:
      return .basic
    case .inf, .byteRange, .discontinuity, .key, .map,
        .programDateTime, .dateRange, .gap, .bitrate:
      return .mediaSegment
    case .targetDuration, .mediaSequence, .discontinuitySequence,
        .endlist, .playlistType, .iFramesOnly:
      return .mediaPlaylist
    case .media, .streamInf, .iFrameStreamInf, .sessionData, .sessionKey:
      return .masterPlaylist
    case .independentSegments, .start, .define:
      return .mediaOrMasterPlaylist
    }
  }

  internal var attributeType: Attribute {
  #warning("this list is not complete now")
    switch self {
    case .m3u, .discontinuity, .independentSegments, .endlist:
      return .none
    case .version, .inf, .byteRange, .targetDuration, .mediaSequence,
        .playlistType, .programDateTime, .bitrate:
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

  internal var minimalVersion: Int { 7 }

}

protocol _HlsTag: Equatable {
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
public enum HlsTag: Equatable {

  case m3u
  case version(Version)
  case inf(Inf)
  case byteRange(ByteRange)
  case discontinuity
  case key(Key)
  case map(Map)
  case programDateTime(ProgramDateTime)
  case dateRange(DateRange)
  case gap
  case bitrate(Bitrate)
  case targetDuration(TargetDuration)
  case mediaSequence(MediaSequence)
  case discontinuitySequence(DiscontinuitySequence)
  case endlist
  case playlistType(PlaylistType)
  case iFramesOnly
  case media(Media)
  case streamInf(StreamInf)
  case iFrameStreamInf(IFrameStreamInf)
  case sessionData(SessionData)
  case sessionKey(SessionKey)
  case independentSegments
  case start(Start)
  case define(Define)

  internal var category: Category {
    switch self {
    case .m3u, .version:
      return .basic
    case .inf, .byteRange, .discontinuity, .key, .map,
        .programDateTime, .dateRange, .gap, .bitrate:
      return .mediaSegment
    case .targetDuration, .mediaSequence, .discontinuitySequence,
        .endlist, .playlistType, .iFramesOnly:
      return .mediaPlaylist
    case .media, .streamInf, .iFrameStreamInf, .sessionData, .sessionKey:
      return .masterPlaylist
    case .independentSegments, .start, .define:
      return .mediaOrMasterPlaylist
    }
  }

  /// 4.4.1
  //    public struct BasicTags {

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
  //    }

  /// 4.4.2
  //    public struct MediaSegmentTags {

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
      uri = dictionary["URI"]
      iv = dictionary["IV"]
      keyFormat = dictionary["KEYFORMAT"]
      keyFormatVersions = dictionary["KEYFORMATVERSIONS"]

      switch method {
      case .none:
        // An encryption method of NONE means that Media Segments are not encrypted.  If the encryption method is NONE, other attributes MUST NOT be present.
        precondition(uri == nil)
        precondition(iv == nil)
        precondition(keyFormat == nil)
        precondition(keyFormatVersions == nil)
      case .aes128, .sampleAES:
        // This attribute is REQUIRED unless the METHOD is NONE.
        precondition(uri != nil)
      }

    }

    var type: _HlsTagType {.key}

    public let method: Method
    public enum Method: String, CaseIterable {
      case none = "NONE"
      case aes128 = "AES-128"
      case sampleAES = "SAMPLE-AES"
    }
    public let uri: String?
    public let iv: String?
    public let keyFormat: String?
    public let keyFormatVersions: String?
  }

  /// 4.4.2.5
  public struct Map: _HlsAttributeTag {
    init(_ dictionary: [String : String]) throws {
      uri = try dictionary.get("URI")
      byteRange = try dictionary["BYTERANGE"].map(ByteRange.init)
    }

    var type: _HlsTagType {.map}

    public let uri: String
    public let byteRange: ByteRange?
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
  //    }

  /// 4.4.3
  //    public struct MediaPlaylistTags {

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
  public enum PlaylistType: String, HlsSingleValueTag, CaseIterable {
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
  //    }

  // MARK: MasterPlaylistTags

  /// 4.4.4.1
  public struct Media: _HlsAttributeTag {
    public init(mediatype: MediaType, uri: String?) {
      self.mediatype = mediatype
      self.uri = uri
      self.groupID = ""
      self.language = nil
      self.assocLanguage = nil
      self.name = ""
      self.default = nil
      self.autoselect = nil
      self.forced = nil
      self.instreamID = nil
      self.characteristics = nil
      self.channels = nil
    }


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
        //                    precondition(forced == nil)
      }
      if mediatype == .audio {
        //                    precondition(channels != nil)
      }
    }

    var type: _HlsTagType {.media}

    /// The value is an enumerated-string; valid strings are AUDIO, VIDEO,
    /// SUBTITLES, and CLOSED-CAPTIONS.  This attribute is REQUIRED.

    /// Typically, closed-caption [CEA608] media is carried in the video
    /// stream.  Therefore, an EXT-X-MEDIA tag with TYPE of CLOSED-
    /// CAPTIONS does not specify a Rendition; the closed-caption media is
    /// present in the Media Segments of every video Rendition.
    public let mediatype: MediaType
    public enum MediaType: String, Equatable, CaseIterable {
      case audio = "AUDIO"
      case video = "VIDEO"
      case subtitles = "SUBTITLES"
      case closedCaptions = "CLOSED-CAPTIONS"
    }

    /// The value is a quoted-string containing a URI that identifies the
    /// Media Playlist file.  This attribute is OPTIONAL; see
    /// Section 4.4.4.2.1.  If the TYPE is CLOSED-CAPTIONS, the URI
    /// attribute MUST NOT be present.
    public let uri: String?
    /// The value is a quoted-string that specifies the group to which the
    /// Rendition belongs.  See Section 4.4.4.1.1.  This attribute is
    /// REQUIRED.
    public let groupID: String
    /// The value is a quoted-string containing one of the standard Tags
    /// for Identifying Languages [RFC5646], which identifies the primary
    /// language used in the Rendition.  This attribute is OPTIONAL.
    public let language: String?
    /// The value is a quoted-string containing a language tag [RFC5646]
    /// that identifies a language that is associated with the Rendition.
    /// An associated language is often used in a different role than the
    /// language specified by the LANGUAGE attribute (e.g., written versus
    /// spoken, or a fallback dialect).  This attribute is OPTIONAL.
    ///
    /// The LANGUAGE and ASSOC-LANGUAGE attributes can be used, for
    /// example, to link Norwegian Renditions that use different spoken
    /// and written languages.
    public let assocLanguage: String?
    /// The value is a quoted-string containing a human-readable
    /// description of the Rendition.  If the LANGUAGE attribute is
    /// present, then this description SHOULD be in that language.  This
    /// attribute is REQUIRED.
    public let name: String
    /// The value is an enumerated-string; valid strings are YES and NO.
    /// If the value is YES, then the client SHOULD play this Rendition of
    /// the content in the absence of information from the user indicating
    /// a different choice.  This attribute is OPTIONAL.  Its absence
    /// indicates an implicit value of NO.
    public let `default`: Default?
    public enum Default: String, Equatable, CaseIterable {
      case yes = "YES"
      case no = "NO"

      var boolValue: Bool { self == .yes }
    }
    /// The value is an enumerated-string; valid strings are YES and NO.
    /// This attribute is OPTIONAL.  Its absence indicates an implicit
    /// value of NO.  If the value is YES, then the client MAY choose to
    /// play this Rendition in the absence of explicit user preference
    /// because it matches the current playback environment, such as
    /// chosen system language.
    /// If the AUTOSELECT attribute is present, its value MUST be YES if
    /// the value of the DEFAULT attribute is YES.
    public let autoselect: Default?
    /// The value is an enumerated-string; valid strings are YES and NO.
    /// This attribute is OPTIONAL.  Its absence indicates an implicit
    /// value of NO.  The FORCED attribute MUST NOT be present unless the
    /// TYPE is SUBTITLES.
    ///
    /// A value of YES indicates that the Rendition contains content that
    /// is considered essential to play.  When selecting a FORCED
    /// Rendition, a client SHOULD choose the one that best matches the
    /// current playback environment (e.g., language).
    ///
    /// A value of NO indicates that the Rendition contains content that
    /// is intended to be played in response to explicit user request.
    public let forced: Default?
    /// The value is a quoted-string that specifies a Rendition within the
    /// segments in the Media Playlist.  This attribute is REQUIRED if the
    /// TYPE attribute is CLOSED-CAPTIONS, in which case it MUST have one
    /// of the values: "CC1", "CC2", "CC3", "CC4", or "SERVICEn" where n
    /// MUST be an integer between 1 and 63 (e.g., "SERVICE9" or
    /// "SERVICE42").
    ///
    /// The values "CC1", "CC2", "CC3", and "CC4" identify a Line 21 Data
    /// Services channel [CEA608].  The "SERVICE" values identify a
    /// Digital Television Closed Captioning [CEA708] service block
    /// number.
    ///
    /// For all other TYPE values, the INSTREAM-ID MUST NOT be specified.
    public let instreamID: InstreamID?
    public enum InstreamID: RawRepresentable, Equatable, CaseIterable {
      public static var allCases: [Self] {
        [.cc1, .cc2, .cc3, .cc4, .service(0)]
      }

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
    /// The value is a quoted-string containing one or more Uniform Type
    /// Identifiers [UTI] separated by comma (,) characters.  This
    /// attribute is OPTIONAL.  Each UTI indicates an individual
    /// characteristic of the Rendition.
    ///
    /// A SUBTITLES Rendition MAY include the following characteristics:
    /// "public.accessibility.transcribes-spoken-dialog",
    /// "public.accessibility.describes-music-and-sound", and
    /// "public.easy-to-read" (which indicates that the subtitles have
    /// been edited for ease of reading).
    ///
    /// An AUDIO Rendition MAY include the following characteristic:
    /// "public.accessibility.describes-video".
    ///
    /// The CHARACTERISTICS attribute MAY include private UTIs.
    public let characteristics: String?
    /// The value is a quoted-string that specifies an ordered, slash-
    /// separated ("/") list of parameters.
    ///
    /// If the TYPE attribute is AUDIO, then the first parameter is a
    /// count of audio channels expressed as a decimal-integer, indicating
    /// the maximum number of independent, simultaneous audio channels
    /// present in any Media Segment in the Rendition.  For example, an
    /// AC-3 5.1 Rendition would have a CHANNELS="6" attribute.
    ///
    /// If the TYPE attribute is AUDIO, then the second parameter
    /// identifies the encoding of object-based audio used by the
    /// Rendition.  This parameter is a comma-separated list of Audio
    /// Object Coding Identifiers.  It is optional.  An Audio Object
    /// Coding Identifier is a string containing characters from the set
    /// [A..Z], [0..9], and '-'.  They are codec-specific.  A parameter
    /// value of consisting solely of the dash character (0x2D) indicates
    /// that the audio is not object-based.
    ///
    /// No other CHANNELS parameters are currently defined.
    ///
    /// All audio EXT-X-MEDIA tags SHOULD have a CHANNELS attribute.  If a
    /// Master Playlist contains two Renditions with the same NAME encoded
    /// with the same codec but a different number of channels, then the
    /// CHANNELS attribute is REQUIRED; otherwise, it is OPTIONAL.
    public let channels: String?
  }

  /// 4.4.4.2
  /// The EXT-X-STREAM-INF tag specifies a Variant Stream, which is a set
  /// of Renditions that can be combined to play the presentation.  The
  /// attributes of the tag provide information about the Variant Stream.
  public struct StreamInf: _HlsAttributeTag, CustomStringConvertible {

    public init(bandwidth: Int) {
      self.bandwidth = bandwidth
      self.averageBandwidth = nil
      self.codecs = ""
      self.resolution = nil
      self.frameRate = nil
      self.hdcpLevel = nil
      self.videoRange = nil
      self.audio = nil
      self.video = nil
      self.subtitles = nil
      self.closedCaptions = nil
    }

    init(_ dictionary: [String : String]) throws {
      // Every EXT-X-STREAM-INF tag MUST include the BANDWIDTH attribute.
      bandwidth = try dictionary.get("BANDWIDTH")
      averageBandwidth = try dictionary["AVERAGE-BANDWIDTH"]?.toInt()
      // Every EXT-X-STREAM-INF tag SHOULD include a CODECS attribute.
      codecs = try dictionary.get("CODECS")
      resolution = try dictionary["RESOLUTION"]?.toResolution()
      frameRate = dictionary["FRAME-RATE"]
      hdcpLevel = try dictionary["HDCP-LEVEL"]?.toEnum()
      videoRange = try dictionary["VIDEO-RANGE"]?.toEnum()
      audio = dictionary["AUDIO"]
      video = dictionary["VIDEO"]
      subtitles = dictionary["SUBTITLES"]
      closedCaptions = dictionary["CLOSED-CAPTIONS"]
    }

    var type: _HlsTagType {.streamInf}

    public var description: String {
      "StreamInf(" +
      ([
        ("bandwidth", bandwidth.description),
        ("averageBandwidth", averageBandwidth?.description),
        ("codecs", codecs),
        ("resolution", resolution?.description),
        ("video", video),
        ("audio", audio),
        ("subtitles", subtitles),
        ("closedCaptions", closedCaptions),
      ] as [(String, String?)])
        .lazy.filter { $0.1 != nil }
        .map { "\($0.0): \($0.1!)"}
        .joined(separator: ", ")
      + ")"
    }

    /// The value is a decimal-integer of bits per second.  It represents the peak segment bit rate of the Variant Stream.
    public let bandwidth: Int
    /// The value is a decimal-integer of bits per second.  It represents the average segment bit rate of the Variant Stream.
    public let averageBandwidth: Int?
    /***
     The value is a quoted-string containing a comma-separated list of
     formats, where each format specifies a media sample type that is
     present in one or more Renditions specified by the Variant Stream.
     Valid format identifiers are those in the ISO Base Media File
     Format Name Space defined by "The ’Codecs’ and ’Profiles’
     Parameters for "Bucket" Media Types" [RFC6381].
     For example, a stream containing AAC low complexity (AAC-LC) audio
     and H.264 Main Profile Level 3.0 video would have a CODECS value
     of "mp4a.40.2,avc1.4d401e".
     Note that if a Variant Stream specifies one or more Renditions
     that include IMSC subtitles, the CODECS attribute MUST indicate
     this with a format identifier such as "stpp.ttml.im1t".
     */
    public let codecs: String
    public let resolution: HLSResolution?
    public let frameRate: String?
    public let hdcpLevel: HdcpLevel?
    public enum HdcpLevel: String, CaseIterable {
      /**
       the content does not require output copy protection.
       */
      case none = "NONE"
      /**
       the Variant Stream could fail to play unless the
       output is protected by High-bandwidth Digital Content Protection
       (HDCP) Type 0 [HDCP] or equivalent.
       */
      case type0 = "TYPE-0"
      /**
       the Variant Stream could fail to play unless the output is
       protected by HDCP Type 1 or equivalent.
       */
      case type1 = "TYPE-1"
    }
    public let videoRange: VideoRange?
    public enum VideoRange: String, CaseIterable {
      case sdr = "SDR"
      case pq = "PQ"
    }
    /**
     It MUST match the value of the
     GROUP-ID attribute of an EXT-X-MEDIA tag elsewhere in the Master
     Playlist whose TYPE attribute is AUDIO.  It indicates the set of
     audio Renditions that SHOULD be used when playing the
     presentation.  See Section 4.4.4.2.1.
     */
    public let audio: String?
    /**
     The value is a quoted-string.  It MUST match the value of the
     GROUP-ID attribute of an EXT-X-MEDIA tag elsewhere in the Master
     Playlist whose TYPE attribute is VIDEO.  It indicates the set of
     video Renditions that SHOULD be used when playing the
     presentation.  See Section 4.4.4.2.1.
     */
    public let video: String?
    /**
     It MUST match the value of the
     GROUP-ID attribute of an EXT-X-MEDIA tag elsewhere in the Master
     Playlist whose TYPE attribute is SUBTITLES.  It indicates the set
     of subtitle Renditions that can be used when playing the
     presentation.  See Section 4.4.4.2.1.
     */
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
      resolution = try dictionary["RESOLUTION"]?.toResolution()

      hdcpLevel = dictionary["HDCP-LEVEL"]
      videoRange = try dictionary["VIDEO-RANGE"]?.toEnum()

      video = dictionary["VIDEO"]

      uri = try dictionary.get("URI")
    }


    public let uri: String
    public let bandwidth: Int
    public let averageBandwidth: Int?
    public let codecs: String
    public let resolution: HLSResolution?
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
  public struct SessionKey: _HlsAttributeTag {
    init(_ dictionary: [String : String]) throws {
      method = try dictionary.get("METHOD")
      fatalError()
    }

    var type: _HlsTagType {.sessionKey}

    public let method: Method
    public enum Method: String, CaseIterable {
      case aes128 = "AES-128"
      case sampleAES = "SAMPLE-AES"
    }
    public let uri: String?
    public let iv: String
    public let KEYFORMAT: String?
    public let KEYFORMATVERSIONS: String?
  }


  //    }

  /// 4.4.5
  //    public struct MediaOrMasterPlaylistTags {
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

  /// 4.4.5.3
  public enum Define: _HlsAttributeTag {
    init(_ dictionary: [String : String]) throws {
      if let name = dictionary["NAME"] {
        self = .variable(name: name, value: try dictionary.get("VALUE"))
      } else if let imp = dictionary["IMPORT"] {
        self = .import(imp)
      } else {
        throw HlsTagParseError.noRequiredValue(key: "NAME or IMPORT")
      }
    }

    var type: _HlsTagType {.define}
    case variable(name: String, value: String)
    case`import`(String)
  }
  //    }

}


public enum PlaylistLine {

  case garbage(GarbageLine)
  case good(GoodLine)

  public enum GarbageLine {
    ///Blank lines are ignored.
    case comment(String)
  }

  public enum GoodLine {
    case tag(HlsTag)
    case uri(String)
  }

  @usableFromInline
  internal var goodLine: GoodLine? {
    switch self {
    case .good(let v):
      return v
    default:
      return nil
    }
  }

  public init(line: String) throws {
    if line.hasPrefix("#") {
      if line.hasPrefix("#EXT") {
        // tag
        if let attributeSeperateIndex = line.firstIndex(of: ":") {
          let tag = try _HlsTagType(String(line.dropFirst()[..<attributeSeperateIndex]))
          switch tag.attributeType {
          case .keyValue:
            var attributes: [String : String] = [:]
            var currentIndex = line.index(after: attributeSeperateIndex)
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
              if !value.isEmpty {
                attributes[String(key)] =  String(value)
              }
              if valueEndIndex == line.endIndex {
                break
              }
              currentIndex = line.index(after: valueEndIndex)
              // find next ,
            }
            switch tag {
            case .media:
              self = .good(.tag(.media(try .init(attributes))))
            case .streamInf:
              self = .good(.tag(.streamInf(try .init(attributes))))
            case .iFrameStreamInf:
              self = .good(.tag(.iFrameStreamInf(try .init(attributes))))
            case .map:
              self = .good(.tag(.map(try .init(attributes))))
            case .key:
              self = .good(.tag(.key(try .init(attributes))))
            default:
              fatalError()
            }
          case .none:
            fatalError()
          case .single:
            let str = String(line[line.index(after: attributeSeperateIndex)...])
            switch tag {
            case .version:
              self = .good(.tag(.version(try .init(str))))
            case .targetDuration:
              self = .good(.tag(.targetDuration(try .init(str))))
            case .mediaSequence:
              self = .good(.tag(.mediaSequence(try .init(str))))
            case .playlistType:
              self = .good(.tag(.playlistType(try .init(str))))
            case .inf:
              self = .good(.tag(.inf(try .init(str))))
            case .byteRange:
              self = .good(.tag(.byteRange(try .init(str))))
            case .programDateTime:
              self = .good(.tag(.programDateTime(try .init(str))))
            case .bitrate:
              self = .good(.tag(.bitrate(try .init(str))))
            default:
              fatalError()
            }
          }

        } else {
          let tag = _HlsTagType.init(rawValue: String(line[line.index(after: line.startIndex)...]))!
          precondition(tag.attributeType == .none)
          switch tag {
          case .m3u:
            self = .good(.tag(.m3u))
          case .independentSegments:
            self = .good(.tag(.independentSegments))
          case .endlist:
            self = .good(.tag(.endlist))
          default:
            fatalError()
          }
        }
      } else {
        //comment
        self = .garbage(.comment(line[line.index(after: line.startIndex)...].trimmingCharacters(in: .whitespaces)))
      }
    } else {
      self = .good(.uri(line.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
  }

}
