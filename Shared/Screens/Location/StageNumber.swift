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

    private var defaultFont: Font {
        .system(size: size * 0.46, weight: .semibold, design: .rounded)
    }

    private var ringWidth: CGFloat {
        max(1, size * 0.06)
    }

    var body: some View {
        if let stageNumber = stage.stageNumber {
            Text(String(stageNumber))
                .font(font ?? defaultFont)
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    backgroundColor.opacity(0.82),
                                    backgroundColor.opacity(1.0),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.65), lineWidth: ringWidth)
                        .blur(radius: ringWidth * 0.25)
                )
                .overlay(
                    Circle()
                        .stroke(.black.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: size * 0.2, y: size * 0.1)
        } else {
            Image(systemName: "mappin")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.82),
                                    Color.blue.opacity(0.95),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.65), lineWidth: ringWidth)
                        .blur(radius: ringWidth * 0.25)
                )
                .shadow(color: .black.opacity(0.2), radius: size * 0.2, y: size * 0.1)
        }
    }
}
