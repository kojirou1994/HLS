public enum HlsTagParseError: Error {
    case noRequiredValue(key: String)
    case invalidNumber(String)
    case invalidenumValue(String)
    case unsupportedTag(String)
}
