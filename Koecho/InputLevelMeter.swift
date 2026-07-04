import SwiftUI

struct InputLevelMeter: View {
  let level: Float

  var body: some View {
    HStack(spacing: 2) {
      Text("Input Level")
        .font(.caption)
        .foregroundStyle(.secondary)
      GeometryReader { geometry in
        RoundedRectangle(cornerRadius: 2)
          .fill(levelColor.color)
          .frame(width: geometry.size.width * CGFloat(level))
          .animation(.linear(duration: 0.1), value: level)
      }
      .frame(height: 6)
      .background(
        RoundedRectangle(cornerRadius: 2)
          .fill(.quaternary)
      )
    }
  }

  private var levelColor: InputLevelMeterLevelColor {
    InputLevelMeterLogic.levelColor(for: level)
  }
}

enum InputLevelMeterLogic {
  static func levelColor(for level: Float) -> InputLevelMeterLevelColor {
    if level > 0.9 { .red } else if level > 0.7 { .yellow } else { .green }
  }
}

enum InputLevelMeterLevelColor: Equatable {
  case green
  case yellow
  case red

  var color: Color {
    switch self {
    case .green:
      .green
    case .yellow:
      .yellow
    case .red:
      .red
    }
  }
}

// MARK: - Previews

#Preview("Active") {
  InputLevelMeter(level: 0.6)
    .frame(width: 200, height: 20)
}

#Preview("Silent") {
  InputLevelMeter(level: 0.0)
    .frame(width: 200, height: 20)
}
