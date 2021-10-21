import XMLCoder

public struct MediaPresentationDescription: Decodable {
  public let baseURL: String
  public let period: Period

  private enum CodingKeys: String, CodingKey {
    case baseURL = "BaseURL"
    case period = "Period"
  }
  
}

extension MediaPresentationDescription {

  public struct Period: Codable {
    public let start: String?
    public let duration: String?
    public let bitstreamSwitching: Bool?

    public let adaptationSet: [AdaptationSet]

    private enum CodingKeys: String, CodingKey {
      case adaptationSet = "AdaptationSet"
      case start, duration, bitstreamSwitching
    }
  }

  public struct AdaptationSet: Codable {
    public let mimeType: String?
    public let startWithSAP: Bool?
    public let segmentAlignment: Bool?
    public let lang: String?
    public let role: Role?

    public let segmentTemplate: SegmentTemplate?
    public let representations: [Representation]

    private enum CodingKeys: String, CodingKey {
      case representations = "Representation"
      case mimeType
      case startWithSAP
      case segmentAlignment
      case lang
      case role = "Role"
      case segmentTemplate = "SegmentTemplate"
    }
  }

  public struct Role: Codable {
    public let value: String?
  }

  public struct SegmentTemplate: Codable {
    public let duration: Int?
    public let initialization: String?
    public let media: String?
    public let startNumber: Int
    public let timescale: Int
  }

  public struct Representation: Codable {
    // MARK: Base
    public let profiles: String?
    public let width: Int?
    public let height: Int?
    public let sar: String?
    // <xs:pattern value="[0-9]*[0-9](/[0-9]*[0-9])?"/>
    public let frameRate: String?
    public let audioSamplingRate: Int?
    public let mimeType: String?
    public let segmentProfiles: String?
    public let codecs: String?
    public let maximumSAPPeriod: Double?
    public let startWithSAP: String?
    public let maxPlayoutRate: Double?
    public let codingDependency: Double?
    public let scanType: String?

    // MARK: Rpresentation
    public let id: String
    public let bandwidth: UInt
    public let qualityRanking: UInt?
    public let dependencyId: String?
    public let mediaStreamStructureId: String?

//    private enum CodingKeys: String, CodingKey {
//      case width
//    }

//    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
//      switch key {
//      default: return .element
//      }
//    }
  }
}
