struct YoutubeDLDumpInfo: Codable {
  let formats: [Format]

  let subtitles: [String: [Subtitle]]

  struct Subtitle: Codable, Hashable {
    let url: String
    let ext: String
  }

  struct Format: Codable, CustomStringConvertible {
    let format_id: String
    let url: String
    let manifest_url: String
    let width: Int?
    let height: Int?
    let vcodec: String
    let acodec: String?
    let `protocol`: YTBProtocol
    enum YTBProtocol: String, Codable, CustomStringConvertible {
      case m3u8_native
      case http_dash_segments

      var description: String { rawValue }

    }

    var description: String {
      "\(String(describing: Self.self))(formatID: \(format_id), width: \(width ?? 0), height: \(height ?? 0), vcodec: \(vcodec), acodec: \(acodec ?? "none"), protocol: \(`protocol`))"
    }
  }
}

import ExecutableDescription

struct YoutubeDL: Executable {
  static let executableName: String = "yt-dlp"
  static let alternativeExecutableNames: [String] = ["youtube-dl"]

  let arguments: [String]
}
