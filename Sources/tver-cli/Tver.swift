public struct TverBool: Codable {
  public let cast: Bool?
  public let is_simul: Bool?
  public let is_new: Bool?
}

public struct TverMediaInfo: Codable {
  public let main: Main
  public struct Main: Codable {
    public let catchupId: String
    public let date: String
    public let href: String
    public let lp: String
    public let media: String
    public let mylistId: String
    public let note: [Note]
    public struct Note: Codable {
      public let text: String
      private enum CodingKeys: String, CodingKey {
        case text
      }
    }
    public let player: String
    public let pos: String
    public let publisherId: String
    public let referenceId: String
    public let service: String
    public let subtitle: String
    public let title: String
    public let type: String
    public let url: String?
    private enum CodingKeys: String, CodingKey {

      case catchupId = "catchup_id"
      case date

      case href

      case lp
      case media
      case mylistId = "mylist_id"
      case note

      case player
      case pos
      case publisherId = "publisher_id"
      case referenceId = "reference_id"
      case service
      case subtitle

      case title
      case type
      case url
    }
  }
  public let mylist: Mylist
  public struct Mylist: Codable {
    public let count: Int
    private enum CodingKeys: String, CodingKey {
      case count
    }
  }

  public let episode: [Episode]?
  public struct Episode: Codable {
    public let title: String
    public let subtitle: String?
    public let href: String
  }
  private enum CodingKeys: String, CodingKey {
    case main
    case mylist
    case episode
  }
}

struct TverAreaInfo: Codable {
  let data: [Data]
  struct Data: Codable {
    let href: String
    let date: String
    let media: String
    let title: String
  }
}
