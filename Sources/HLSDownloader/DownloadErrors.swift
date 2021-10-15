import Foundation

public enum HlsDownloaderError: Error {
  case invalidSegmentContentType
  case invalidEncryptKeyLength
}

public struct DownloadError: Error {
  public let url: URL
  public let error: Error
}

public enum HlsDownloadError: Error {
  case noValidStream
}
