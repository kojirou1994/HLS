// MARK: Best Variant
extension MasterPlaylist {

  public func findBestVariant(width: Int, codecs: String = "") -> Variant? {
    let widthFiltered = variants.filter { $0.streamInf.safeWidth == width }
    if widthFiltered.isEmpty {
      return variants.filter { $0.streamInf.safeWidth <= width }
        .max { $0.streamInf.safeWidth < $1.streamInf.safeWidth}
    }
    if let codecFiltered = widthFiltered.first(where: { $0.streamInf.codecs.starts(with: codecs) }) {
      return codecFiltered
    } else {
      return widthFiltered.first
    }
  }

}

extension HlsTag.StreamInf {
  @inlinable
  var safeWidth: UInt32 {
    resolution?.width ?? 0
  }
}
