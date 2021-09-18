import KwiftUtility

extension String {

  @usableFromInline
  internal func toInt() throws -> Int {
    guard let number = Int(self) else {
      throw HlsTagParseError.invalidNumber(self)
    }
    return number
  }

  @usableFromInline
  internal func toEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == String {
    guard let v = T(rawValue: self) else {
      throw HlsTagParseError.invalidEnumValue(self)
    }
    return v
  }

  @usableFromInline
  internal func toResolution() throws -> Resolution  {
    guard let v = Resolution(self) else {
      throw HlsTagParseError.invalidResolution(self)
    }
    return v
  }

}

extension Dictionary where Key == String, Value == String {
  
  @usableFromInline
  internal func get(_ key: String) throws -> String {
    guard let value = self[key] else {
      throw HlsTagParseError.noRequiredValue(key: key)
    }
    return value
  }

  @usableFromInline
  internal func get(_ key: String) throws -> Int {
    let str: String = try get(key)
    return try str.toInt()
  }

  @usableFromInline
  internal func get<T>(_ key: String) throws -> T where T: RawRepresentable, T.RawValue == String {
    let str: String = try get(key)
    return try str.toEnum()
  }
}
