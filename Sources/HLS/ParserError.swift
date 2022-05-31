public enum HlsTagParseError: Error {
  case noRequiredValue(key: String)
  case invalidNumber(String)
  case invalidEnumValue(String)
  case invalidResolution(String)
  case unsupportedTag(String)
}
