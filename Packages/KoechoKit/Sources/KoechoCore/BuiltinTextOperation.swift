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
    let lines = lineRanges(in: source)
    let range = clamped(selection, to: source.length)
    let targets = targetLines(for: range, in: lines)

    let transformed = NSMutableString(string: source)
    var selectionEnd = targets.last!.contentsEnd
    for line in targets.reversed() {
      let original = source.substring(with: NSRange(location: line.start, length: line.contentsEnd - line.start))
      let replacement = transformedLine(original, using: builtin)
      transformed.replaceCharacters(
        in: NSRange(location: line.start, length: line.contentsEnd - line.start),
        with: replacement
      )
      selectionEnd += (replacement as NSString).length - (original as NSString).length
    }

    let selectedRange = NSRange(location: targets[0].start, length: selectionEnd - targets[0].start)
    return BuiltinTextOperationResult(text: transformed as String, selection: selectedRange)
  }

  private struct LineRange {
    let start: Int
    let end: Int
    let contentsEnd: Int
  }

  private static func clamped(_ range: NSRange, to length: Int) -> NSRange {
    let location = max(0, min(range.location, length))
    let availableLength = length - location
    return NSRange(location: location, length: max(0, min(range.length, availableLength)))
  }

  private static func lineRanges(in text: NSString) -> [LineRange] {
    guard text.length > 0 else { return [LineRange(start: 0, end: 0, contentsEnd: 0)] }

    var ranges: [LineRange] = []
    var location = 0
    while location < text.length {
      var start = 0
      var end = 0
      var contentsEnd = 0
      text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
      ranges.append(LineRange(start: start, end: end, contentsEnd: contentsEnd))
      location = end
    }
    if let last = ranges.last, last.end == text.length, last.contentsEnd < last.end {
      ranges.append(LineRange(start: text.length, end: text.length, contentsEnd: text.length))
    }
    return ranges
  }

  private static func targetLines(for selection: NSRange, in lines: [LineRange]) -> [LineRange] {
    let lastOffset = selection.length > 0 ? selection.location + selection.length - 1 : selection.location
    let firstIndex = lines.firstIndex {
      selection.location >= $0.start && (selection.location < $0.end || $0.start == $0.end)
    } ?? lines.count - 1
    let lastIndex = lines.firstIndex { lastOffset >= $0.start && lastOffset < $0.end }
      ?? lines.count - 1
    return Array(lines[firstIndex...lastIndex])
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
