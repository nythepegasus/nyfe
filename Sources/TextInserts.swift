import Foundation

// MARK: - InsertError

enum InsertError: Swift.Error, CustomStringConvertible {
  case couldNotLocateTag(String, inFilePath: String, file: String = #fileID, function: String = #function, line: UInt = #line)
  case missingStartEnd(String, inFilePath: String, file: String = #fileID, function: String = #function, line: UInt = #line)

  // MARK: Public

  public var description: String {
    switch self {
    case .couldNotLocateTag(let tag, inFilePath: let filePath, let file, let function, let l):
      return """
        \(filePath) \(file) \(function) \(l)
        Could not locate
        `
        // \(tag): <#add any comment#>
        // \(tag):end
        `

        in file path: \(filePath)
        """

    case .missingStartEnd(let tag, inFilePath: let filePath, let file, let function, let l):
      return """
        \(filePath) \(file) \(function) \(l)
        Should have a start and an end tag of format:
        `
        // \(tag): <#add any comment#>
        // \(tag):end
        `

        This is missing from file path: \(filePath)
        """
    }
  }
}

extension File {
  /// Used to insert text inbetween tags
  ///
  /// ```swift
  /// // tag:<#some comment#>
  ///  this lines
  ///  will be removed and replaced
  ///  with content.
  /// // tag:end
  /// ```
  /// The text will be inserted inbetween tags
  /// - Parameters:
  ///   - substitute: the test to insert inbetween the tags
  ///   - tag: the tag to look for in the document. Lines inbetween `// tag:<#comment#>` and `// tag:end` will be replaced with the content
  /// - Throws: when tags cannot be found or the file is not readable as an utf8 string
  /// - warning: this is a rather low performant option that reads all content and writes it back, do not use on large files.
  public func insert(_ substitute: String, inbetween tag: String) throws {
    let content = try readAsString()
    let alteredContent = try content.insert(substitute, inbetween: tag, filePath: path(relativeTo: .current))
    if let data = alteredContent.data(using: .utf8) { try write(data) }
  }
  /// Similar to ``insert(_,inbetween:)`` but instead of throwing the tag is appended to the file
  public func insertOrAddTags(_ substitute: String, inbetween tag: String, prefixForTag: String = "") throws {
    var content = try readAsString()
    do {
      _ = try content.content(for: tag, filePath: path)
      // there is content
    } catch {
      // first append the tags
      content.append(
        contentsOf: """


          \(prefixForTag)\(begin(tag: tag))
          \(prefixForTag)\(end(tag: tag))

          """)
    }
    let alteredContent = try content.insert(substitute, inbetween: tag, filePath: path(relativeTo: .current))
    if let data = alteredContent.data(using: .utf8) { try write(data) }
  }

  public func removeAll(inbetween tag: String) throws {
    let content = try readAsString()
    try write(try content.removeAll(inbetween: tag, filePath: path(relativeTo: .current)))
  }
}

extension String {

  // MARK: Public

  public func removeAll(inbetween tag: String, filePath: String) throws -> String {
    var components = components(separatedBy: "\n")
    guard
      let firstIndex = (components.firstIndex { $0.contains(begin(tag: tag)) }),
      let lastIndex = (components.firstIndex { $0.contains(end(tag: tag)) })
    else {
      throw InsertError.couldNotLocateTag(tag, inFilePath: filePath)
    }

    let startContent = components[firstIndex]
    let endContent = components[lastIndex]

    components.removeSubrange(firstIndex..<(lastIndex + 1))

    let substituteWithTagsAndSpaces = [
      startContent,
      endContent,
    ]
    components.insert(contentsOf: substituteWithTagsAndSpaces, at: firstIndex)
    return components.joined(separator: "\n")
  }

  /// Makes a new string with the substitute inbetween the tag maintaining the spacing of the first tag.
  public func insert(_ substitute: String, inbetween tag: String, filePath: String) throws -> String {
    var components = components(separatedBy: "\n")
    guard
      let firstIndex = (components.firstIndex { $0.contains(begin(tag: tag)) }),
      let lastIndex = (components.firstIndex { $0.contains(end(tag: tag)) })
    else {
      throw InsertError.couldNotLocateTag(tag, inFilePath: filePath)
    }
    guard firstIndex != lastIndex else {
      throw InsertError.missingStartEnd(tag, inFilePath: filePath)
    }

    let startContent = components[firstIndex]
    // swift-format-ignore
    let startSpaces = startContent.distance(from: startContent.startIndex, to: startContent.firstIndex(of: "/")!)
    let endContent = components[lastIndex]

    components.removeSubrange(firstIndex..<(lastIndex + 1))

    let spaces = String(repeating: " ", count: .init(startSpaces))
    let substituteWithTagsAndSpaces = [
      startContent,
      substitute
        .components(separatedBy: "\n")
        .map { $0.isEmpty ? $0 : spaces + $0 }
        .joined(separator: "\n"),
      endContent,
    ]
    components.insert(contentsOf: substituteWithTagsAndSpaces, at: firstIndex)
    return components.joined(separator: "\n")
  }

  public func isClean(for tags: [String]) -> Bool {
    let components = components(separatedBy: "\n")

    var result = true
    for tag in tags {
      guard
        let firstIndex = (components.firstIndex { $0.contains(begin(tag: tag)) }),
        let lastIndex = (components.firstIndex { $0.contains(end(tag: tag)) })
      else {
        result = false
        break
      }

      let distance = firstIndex.distance(to: lastIndex)

      guard distance <= 2 else {
        result = false
        break
      }
    }
    return result
  }

  public func content(for tag: String, filePath: String) throws -> String {
    let separator = "\n"
    let components = components(separatedBy: separator)

    guard
      let firstIndex = (components.firstIndex { $0.contains(begin(tag: tag)) }),
      let lastIndex = (components.firstIndex { $0.contains(end(tag: tag)) })
    else {
      throw InsertError.couldNotLocateTag(tag, inFilePath: filePath)
    }
    guard firstIndex.distance(to: lastIndex) > 1 else {
      throw InsertError.couldNotLocateTag(tag, inFilePath: filePath)
    }

    return components[(firstIndex + 1)...(lastIndex - 1)].joined(separator: separator)
  }

}

// MARK: Private

private func begin(tag: String) -> String {
  "// \(tag):"
}

private func end(tag: String) -> String {
  begin(tag: tag) + "end"
}
