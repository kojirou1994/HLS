import KwiftUtility

extension String {

  func toInt() throws -> Int {
    guard let number = Int(self) else {
      throw HlsTagParseError.invalidNumber(self)
    }
    return number
  }

  func toEnum<T>() throws -> T where T: RawRepresentable, T.RawValue == String, T: CaseIterable {
    guard let v = T(rawValue: self) else {
      throw HlsTagParseError.invalidEnumValue(self)
    }
    return v
  }

  func toResolution() throws -> Resolution  {
    guard let v = Resolution(self) else {
      throw HlsTagParseError.invalidResolution(self)
    }
    return v
  }

}

extension Dictionary where Key == String, Value == String {

  func get(_ key: String) throws -> String {
    guard let value = self[key] else {
      throw HlsTagParseError.noRequiredValue(key: key)
    }
    return value
  }

  func get(_ key: String) throws -> Int {
    let str: String = try get(key)
    return try str.toInt()
  }

  func get<T>(_ key: String) throws -> T where T: RawRepresentable, T.RawValue == String, T: CaseIterable {
    let str: String = try get(key)
    return try str.toEnum()
  }
}

extension Resolution: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.size < rhs.size
  }
}

extension Optional: Comparable where Wrapped: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.none, .none): return true
    case (.some, .none): return false
    case (.none, .some): return true
    case let (.some(l), .some(r)): return l < r
    }
  }
}
