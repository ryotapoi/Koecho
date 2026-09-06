import Foundation

public struct BuiltinTextOperationResult: Equatable, Sendable {
  public let text: String
  public let selection: NSRange

  public init(text: String, selection: NSRange) {
    self.text = text
    self.selection = selection
  }
}

public enum BuiltinTextOperation {
  public static func apply(
    to text: String,
    selection: NSRange,
    builtin: BuiltinScript
  ) -> BuiltinTextOperationResult {
    let source = text as NSString
    let range = clamped(selection, to: source.length)
    var selectionStart = 0
    var selectionEnd = 0
    source.getLineStart(
      &selectionStart,
      end: nil,
      contentsEnd: &selectionEnd,
      for: range
    )
    var targetLocation = range.length > 0 ? range.location + range.length - 1 : range.location

    let transformed = NSMutableString(string: source)
    while true {
      var lineStart = 0
      var contentsEnd = 0
      source.getLineStart(
        &lineStart,
        end: nil,
        contentsEnd: &contentsEnd,
        for: NSRange(location: targetLocation, length: 0)
      )

      let original = source.substring(with: NSRange(location: lineStart, length: contentsEnd - lineStart))
      let replacement = transformedLine(original, using: builtin)
      transformed.replaceCharacters(
        in: NSRange(location: lineStart, length: contentsEnd - lineStart),
        with: replacement
      )
      selectionEnd += (replacement as NSString).length - (original as NSString).length

      guard lineStart > selectionStart else { break }
      targetLocation = lineStart - 1
    }

    let selectedRange = NSRange(location: selectionStart, length: selectionEnd - selectionStart)
    return BuiltinTextOperationResult(text: transformed as String, selection: selectedRange)
  }

  private static func clamped(_ range: NSRange, to length: Int) -> NSRange {
    let location = max(0, min(range.location, length))
    let availableLength = length - location
    return NSRange(location: location, length: max(0, min(range.length, availableLength)))
  }

  private static func transformedLine(_ line: String, using builtin: BuiltinScript) -> String {
    switch builtin.feature {
    case .increaseIndent:
      return String(repeating: " ", count: builtin.indentationWidth!.rawValue) + line
    case .decreaseIndent:
      let width = builtin.indentationWidth!.rawValue
      let leadingSpaces = line.prefix { $0 == " " }.count
      return String(line.dropFirst(min(width, leadingSpaces)))
    case .blockQuote:
      return "> " + line
    }
  }
}
