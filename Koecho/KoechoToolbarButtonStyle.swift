import SwiftUI

struct KoechoToolbarButtonStyle: ButtonStyle {
  var isEmphasized = false
  var isPrimary = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .labelStyle(.titleAndIcon)
      .font(.caption)
      .lineLimit(1)
      .padding(.horizontal, 10)
      .frame(height: 28)
      .foregroundStyle(foregroundStyle)
      .background(background(configuration: configuration))
      .overlay(
        RoundedRectangle(cornerRadius: 7)
          .strokeBorder(borderStyle, lineWidth: 1)
      )
      .opacity(configuration.isPressed ? 0.72 : 1)
  }

  private var foregroundStyle: Color {
    if isPrimary { return .white }
    if isEmphasized { return .primary }
    return .secondary
  }

  private var borderStyle: Color {
    if isPrimary { return .clear }
    return Color.primary.opacity(0.08)
  }

  @ViewBuilder
  private func background(configuration: Configuration) -> some View {
    RoundedRectangle(cornerRadius: 7)
      .fill(backgroundStyle(configuration: configuration))
      .shadow(color: .black.opacity(isPrimary ? 0.18 : 0.04), radius: 3, y: 1)
  }

  private func backgroundStyle(configuration: Configuration) -> Color {
    if isPrimary {
      return configuration.isPressed ? Color.primary.opacity(0.82) : Color.primary
    }
    if isEmphasized {
      return configuration.isPressed ? Color.white.opacity(0.76) : Color.white.opacity(0.94)
    }
    return configuration.isPressed ? Color.primary.opacity(0.08) : Color.white.opacity(0.58)
  }
}

extension ButtonStyle where Self == KoechoToolbarButtonStyle {
  static func koechoToolbar(isEmphasized: Bool = false, isPrimary: Bool = false) -> Self {
    KoechoToolbarButtonStyle(isEmphasized: isEmphasized, isPrimary: isPrimary)
  }
}
