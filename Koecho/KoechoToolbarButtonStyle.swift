import SwiftUI

struct KoechoToolbarButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  var isEmphasized = false
  var isPrimary = false
  var isSelected = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .labelStyle(.titleAndIcon)
      .font(.caption.weight(isPrimary || isSelected || isEmphasized ? .bold : .regular))
      .lineLimit(1)
      .padding(.horizontal, isPrimary ? 12 : 10)
      .frame(height: 30)
      .foregroundStyle(foregroundStyle)
      .background(background(configuration: configuration))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(borderStyle, lineWidth: 1)
      )
      .opacity(configuration.isPressed ? 0.72 : 1)
  }

  private var foregroundStyle: Color {
    if isPrimary { return Color(nsColor: .windowBackgroundColor) }
    if isSelected { return Color(nsColor: .windowBackgroundColor) }
    if !isEnabled { return .secondary }
    if isEmphasized { return .primary }
    return .secondary
  }

  private var borderStyle: Color {
    if isPrimary || isSelected { return .clear }
    if isEmphasized && isEnabled { return Color.primary.opacity(0.10) }
    return Color.primary.opacity(0.08)
  }

  @ViewBuilder
  private func background(configuration: Configuration) -> some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(backgroundStyle(configuration: configuration))
      .shadow(color: shadowColor, radius: isEmphasized && isEnabled ? 4 : 3, y: 1)
  }

  private var shadowColor: Color {
    if isPrimary { return .black.opacity(0.18) }
    if isEmphasized && isEnabled { return .black.opacity(0.08) }
    return .black.opacity(0.04)
  }

  private func backgroundStyle(configuration: Configuration) -> Color {
    if isPrimary || isSelected {
      return configuration.isPressed ? Color.primary.opacity(0.72) : Color.primary.opacity(0.88)
    }
    if !isEnabled {
      return configuration.isPressed ? Color.primary.opacity(0.07) : Color.primary.opacity(0.05)
    }
    if isEmphasized {
      return configuration.isPressed
        ? Color(nsColor: .controlBackgroundColor).opacity(0.82)
        : Color(nsColor: .controlBackgroundColor).opacity(0.96)
    }
    return configuration.isPressed ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06)
  }
}

extension ButtonStyle where Self == KoechoToolbarButtonStyle {
  static func koechoToolbar(
    isEmphasized: Bool = false,
    isPrimary: Bool = false,
    isSelected: Bool = false
  ) -> Self {
    KoechoToolbarButtonStyle(
      isEmphasized: isEmphasized,
      isPrimary: isPrimary,
      isSelected: isSelected
    )
  }
}
