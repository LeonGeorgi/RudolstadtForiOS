import SwiftUI

struct StageNumber: View {
    let stage: Stage
    let size: CGFloat
    let font: Font?

    init(stage: Stage, size: CGFloat, font: Font? = nil) {
        self.stage = stage
        self.size = size
        self.font = font
    }

    static func baseColor(for stageType: StageType) -> Color {
        switch stageType {
        case .festivalTicket:
            return .stageType1
        case .festivalAndDayTicket:
            return .stageType2
        case .other, .unknown:
            return .stageType3
        }
    }

    var backgroundColor: Color {
        Self.baseColor(for: stage.stageType)
    }

    var textColor: Color {
        stage.stageType == .other ? .black : .white
    }

    private var usesLightText: Bool {
        stage.stageType != .other
    }

    private var defaultFont: Font {
        .system(
            size: size * (usesCompactBadge ? 0.56 : 0.46),
            weight: usesCompactBadge ? .heavy : .semibold,
            design: .rounded
        )
    }

    private var usesCompactBadge: Bool {
        size <= 20
    }

    private var outerStrokeWidth: CGFloat {
        max(1, size * 0.06)
    }

    private var innerStrokeWidth: CGFloat {
        max(1, size * 0.03)
    }

    private var badgeShadow: ShadowStyle {
        ShadowStyle(
            color: .black.opacity(0.12),
            radius: size * 0.06,
            y: size * 0.04
        )
    }

    private func compactFill(_ fillColor: Color) -> some ShapeStyle {
        LinearGradient(
            colors: [
                fillColor.opacity(0.95),
                fillColor.opacity(0.8),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func regularFill(_ fillColor: Color) -> some ShapeStyle {
        LinearGradient(
            colors: [
                fillColor.opacity(0.78),
                fillColor,
                fillColor.opacity(0.84),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func badgeFace(fillColor: Color) -> some View {
        if usesCompactBadge {
            Circle()
                .fill(compactFill(fillColor))
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: outerStrokeWidth)
                )
                .overlay(
                    Circle()
                        .frame(width: size * 0.34, height: size * 0.34)
                        .foregroundStyle(.white.opacity(0.14))
                        .offset(x: -size * 0.16, y: -size * 0.16)
                )
                .shadow(color: badgeShadow.color, radius: badgeShadow.radius, y: badgeShadow.y)
        } else {
            Circle()
                .fill(regularFill(fillColor))
                .overlay(alignment: .topLeading) {
                    Circle()
                        .frame(width: size * 0.34, height: size * 0.34)
                        .foregroundStyle(.white.opacity(0.18))
                        .offset(x: size * 0.12, y: size * 0.1)
                }
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.24), lineWidth: outerStrokeWidth)
                )
                .overlay(
                    Circle()
                        .inset(by: size * 0.08)
                        .stroke(.white.opacity(0.12), lineWidth: innerStrokeWidth)
                )
                .shadow(color: badgeShadow.color, radius: badgeShadow.radius, y: badgeShadow.y)
        }
    }

    var body: some View {
        if let stageNumber = stage.stageNumber {
            Text(String(stageNumber))
                .font(font ?? defaultFont)
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(width: size, height: size)
                .shadow(
                    color: usesLightText ? .black.opacity(0.22) : .white.opacity(0.22),
                    radius: usesCompactBadge ? 0.6 : 1,
                    y: usesCompactBadge ? 0.4 : 0.6
                )
                .background(badgeFace(fillColor: backgroundColor))
        } else {
            Image(systemName: "mappin")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(badgeFace(fillColor: .blue))
        }
    }
}

private struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}
