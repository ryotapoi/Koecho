import Foundation
import os

private struct ReplacementRuleApplication {
  let matches: [ReplacementMatch]
  let result: String

  init?(rule: ReplacementRule, to text: String) {
    guard let regex = buildRegex(for: rule) else { return nil }
    let template = buildTemplate(for: rule)
    let range = NSRange(text.startIndex..., in: text)
    let matches = regex.matches(in: text, range: range)

    self.matches = matches.map { match in
      ReplacementMatch(
        range: match.range,
        replacement: regex.replacementString(
          for: match,
          in: text,
          offset: 0,
          template: template
        )
      )
    }
    result = regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
  }
}

public func applyReplacementRules(_ rules: [ReplacementRule], to text: String) -> String {
  rules.reduce(text) { result, rule in
    ReplacementRuleApplication(rule: rule, to: result)?.result ?? result
  }
}

/// Apply rules in registration order, mapping a UTF-16 insertion point through
/// each intermediate document. A point inside a match retains its relative
/// offset up to the replacement's end; a deletion maps it to the match's start.
/// A point inside a final extended grapheme cluster advances to its end.
public func applyReplacementRules(
  _ rules: [ReplacementRule], to text: String, insertionPoint: Int
) -> (text: String, insertionPoint: Int) {
  var result = text
  var point = insertionPoint
  for rule in rules {
    guard let application = ReplacementRuleApplication(rule: rule, to: result) else { continue }
    var shift = 0
    for match in application.matches {
      if point <= match.range.location { break }
      let replacementLength = match.replacement.utf16.count
      if point < NSMaxRange(match.range) {
        point = match.range.location + shift + min(point - match.range.location, replacementLength)
        shift = 0
        break
      }
      shift += replacementLength - match.range.length
    }
    point += shift
    result = application.result
  }
  return (result, characterBoundary(atOrAfter: point, in: result))
}

/// Find editable, non-overlapping occurrences in the current document.
/// Earlier registered rules own overlapping occurrences. Zero-width matches
/// remain supported by whole-document application, but have no clickable text.
public func findReplacementCandidates(_ rules: [ReplacementRule], in text: String)
  -> [ReplacementMatch]
{
  var candidates: [ReplacementMatch] = []
  for rule in rules {
    guard let application = ReplacementRuleApplication(rule: rule, to: text) else { continue }
    for match in application.matches where match.range.length > 0 {
      guard !candidates.contains(where: {
        NSIntersectionRange($0.range, match.range).length > 0
      }) else { continue }
      candidates.append(match)
    }
  }
  return candidates.sorted { $0.range.location < $1.range.location }
}

/// Apply one current-document match, using the same UTF-16 point mapping as
/// whole-document replacement. The caller must validate the match's snapshot.
public func applyReplacementMatch(
  _ match: ReplacementMatch, to text: String, insertionPoint: Int
) -> (text: String, insertionPoint: Int) {
  let application = applyReplacementMatchMapping(match, to: text, insertionPoint: insertionPoint)
  return (application.text, characterBoundary(atOrAfter: application.insertionPoint, in: application.text))
}

private func applyReplacementMatchMapping(
  _ match: ReplacementMatch, to text: String, insertionPoint: Int
) -> (text: String, insertionPoint: Int) {
  let result = (text as NSString).replacingCharacters(in: match.range, with: match.replacement)
  let point: Int
  if insertionPoint <= match.range.location {
    point = insertionPoint
  } else if insertionPoint < NSMaxRange(match.range) {
    point = match.range.location + min(insertionPoint - match.range.location, match.replacement.utf16.count)
  } else {
    point = insertionPoint + match.replacement.utf16.count - match.range.length
  }
  return (result, point)
}

/// Select fully contained occurrences, or one occurrence at the caret.
/// At an adjacent boundary the leftmost occurrence owns the caret.
public func replacementTargets(
  _ candidates: [ReplacementMatch], selection: NSRange
) -> [ReplacementMatch] {
  if selection.length > 0 {
    return candidates.filter {
      $0.range.location >= selection.location && NSMaxRange($0.range) <= NSMaxRange(selection)
    }
  }
  return candidates.sorted { $0.range.location < $1.range.location }.first {
    selection.location >= $0.range.location && selection.location <= NSMaxRange($0.range)
  }.map { [$0] } ?? []
}

/// Apply a validated, non-overlapping snapshot without searching generated text.
/// Descending edits preserve original ranges and map each UTF-16 point cumulatively.
public func applyReplacementMatches(
  _ matches: [ReplacementMatch], to text: String, insertionPoint: Int
) -> (text: String, insertionPoint: Int) {
  let application = matches.sorted { $0.range.location > $1.range.location }.reduce((text, insertionPoint)) {
    applyReplacementMatchMapping($1, to: $0.0, insertionPoint: $0.1)
  }
  return (application.0, characterBoundary(atOrAfter: application.1, in: application.0))
}

/// Preserve mapped coordinates until all edits finish: intermediate clusters
/// can change when a later replacement edits an adjacent character.
private func characterBoundary(atOrAfter point: Int, in text: String) -> Int {
  var boundary = 0
  for character in text {
    if boundary >= point { return boundary }
    boundary += character.utf16.count
  }
  return boundary
}

/// Find non-overlapping preview regions in the original UTF-16 coordinates.
/// A region's replacement is its final content after all registered rules,
/// including subsequent changes to only part of previously generated text.
public func findReplacementMatches(_ rules: [ReplacementRule], in text: String)
  -> [ReplacementMatch]
{
  var segments = [PreviewSegment(
    originalRange: NSRange(location: 0, length: text.utf16.count),
    units: Array(text.utf16), isReplacement: false)]
  var intermediateText = text
  for rule in rules {
    guard let application = ReplacementRuleApplication(rule: rule, to: intermediateText) else {
      continue
    }
    // All matches use the pre-rule coordinates, so edit from right to left.
    for match in application.matches.reversed() {
      replacePreviewSegment(match, in: &segments)
    }
    intermediateText = application.result
  }
  return segments.filter(\.isReplacement).map {
    ReplacementMatch(range: $0.originalRange, replacement: String(decoding: $0.units, as: UTF16.self))
  }
}

private struct PreviewSegment {
  let originalRange: NSRange
  var units: [UInt16]
  let isReplacement: Bool
}

/// Untouched text can be split exactly. Generated text keeps its original
/// region intact so partial later matches produce one final preview.
private func splitPreviewSegment(at position: Int, in segments: inout [PreviewSegment]) {
  var offset = 0
  for (index, segment) in segments.enumerated() {
    let local = position - offset
    if local > 0 && local < segment.units.count && !segment.isReplacement {
      segments.replaceSubrange(index...index, with: [
        PreviewSegment(
          originalRange: NSRange(location: segment.originalRange.location, length: local),
          units: Array(segment.units[..<local]), isReplacement: false),
        PreviewSegment(
          originalRange: NSRange(location: segment.originalRange.location + local,
            length: segment.originalRange.length - local),
          units: Array(segment.units[local...]), isReplacement: false),
      ])
      return
    }
    offset += segment.units.count
  }
}

private func replacePreviewSegment(_ match: ReplacementMatch, in segments: inout [PreviewSegment]) {
  let start = match.range.location
  let end = NSMaxRange(match.range)
  splitPreviewSegment(at: end, in: &segments)
  splitPreviewSegment(at: start, in: &segments)

  var offset = 0
  var first: Int?
  var last: Int?
  var regionStart = 0
  var insertionIndex = 0
  var originalPosition = 0
  for (index, segment) in segments.enumerated() {
    let segmentEnd = offset + segment.units.count
    if segmentEnd <= start {
      insertionIndex = index + 1
      originalPosition = NSMaxRange(segment.originalRange)
    }
    if (offset < end && segmentEnd > start)
      || (start == end && offset < start && segmentEnd > start)
    {
      if first == nil { first = index; regionStart = offset }
      last = index
    }
    offset = segmentEnd
  }

  guard let first, let last else {
    // A zero-width regex match at an existing boundary inserts new text.
    segments.insert(PreviewSegment(
      originalRange: NSRange(location: originalPosition, length: 0),
      units: Array(match.replacement.utf16), isReplacement: true), at: insertionIndex)
    return
  }
  var units = segments[first...last].flatMap(\.units)
  units.replaceSubrange((start - regionStart)..<(end - regionStart),
    with: match.replacement.utf16)
  let originalRange = NSRange(
    location: segments[first].originalRange.location,
    length: NSMaxRange(segments[last].originalRange) - segments[first].originalRange.location)
  segments.replaceSubrange(first...last, with: [PreviewSegment(
    originalRange: originalRange, units: units, isReplacement: true)])
}

/// Build an NSRegularExpression for the given rule. Returns nil for invalid or empty patterns.
private func buildRegex(for rule: ReplacementRule) -> NSRegularExpression? {
  let logger = Logger(subsystem: Logger.koechoSubsystem, category: "ReplacementRule")

  let regexPattern: String
  if rule.usesRegularExpression {
    guard !rule.pattern.isEmpty else { return nil }
    regexPattern = rule.pattern
  } else {
    // Filter non-empty, sort longest first to prevent shorter patterns from
    // consuming parts of longer ones (regex alternation is left-to-right).
    let nonEmpty = rule.patternTexts.filter { !$0.isEmpty }.sorted { $0.count > $1.count }
    guard !nonEmpty.isEmpty else { return nil }
    let alternatives = nonEmpty.map { pattern in
      let escaped = NSRegularExpression.escapedPattern(for: pattern)
      return rule.matchesWholeWord ? "\\b\(escaped)\\b" : escaped
    }
    regexPattern = alternatives.joined(separator: "|")
  }

  do {
    return try NSRegularExpression(pattern: regexPattern)
  } catch {
    logger.warning("Invalid regex pattern '\(regexPattern)': \(error.localizedDescription)")
    return nil
  }
}

private func buildTemplate(for rule: ReplacementRule) -> String {
  rule.usesRegularExpression
    ? rule.replacement
    : NSRegularExpression.escapedTemplate(for: rule.replacement)
}
