import SwiftUI

struct StageNumber: View {
    @Environment(\.colorScheme) private var colorScheme
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

    static func baseColor(for stage: Stage, colorScheme: ColorScheme = .light) -> Color {
        if let category = stage.admissionCategory {
            return .festivalCategory(tintHex: category.tintHex, darkTintHex: category.darkTintHex,
                                     colorScheme: colorScheme)
        }
        if let category = stage.mapCategory {
            return .festivalCategory(tintHex: category.tintHex, darkTintHex: category.darkTintHex,
                                     colorScheme: colorScheme)
        }
        if stage.displayCode == nil { return .festivalCategory(colorScheme: colorScheme) }
        return baseColor(for: stage.stageType)
    }

    private var backgroundColor: Color {
        return Self.baseColor(for: stage, colorScheme: colorScheme)
    }

    private var defaultFont: Font {
        .system(size: size * (size <= 20 ? 0.56 : 0.46), weight: .semibold, design: .rounded)
    }

    var body: some View {
        Group {
            if let code = stage.displayCode {
                Text(code)
                    .font(font ?? defaultFont)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            } else {
                PlaceSymbol(systemName: stage.mapCategory?.systemImageName ?? "mappin", circleDiameter: size)
            }
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background {
            Group {
                if #available(iOS 16.0, macOS 13.0, *) {
                    Circle().fill(backgroundColor.gradient)
                } else {
                    Circle().fill(backgroundColor)
                }
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.65 : 0.35),
                    radius: max(1.5, size * 0.08), x: 0, y: max(1, size * 0.05))
        }
        .overlay {
            Circle().strokeBorder(colorScheme == .dark ? Color.black : Color.white,
                                  lineWidth: max(1, size * 0.05))
        }
    }
}

struct PlaceSymbol: View {
    let systemName: String
    let circleDiameter: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .font(.system(size: circleDiameter, weight: .semibold))
            .frame(width: circleDiameter * 0.54, height: circleDiameter * 0.54)
    }
}

#if DEBUG
@MainActor
private struct StageNumberPreviewShowcase: View {
    private var stages: [Stage] {
        Array(PreviewMockData.festivalData.stages.prefix(4)) + [stageWithoutNumber]
    }

    private var stageWithoutNumber: Stage {
        Stage(
            id: 9999,
            germanName: "Preview Ort",
            englishName: "Preview Location",
            germanDescription: nil,
            englishDescription: nil,
            stageNumber: nil,
            latitude: 50.72,
            longitude: 11.34,
            area: .example,
            stageType: .other
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(stages) { stage in
                HStack(spacing: 18) {
                    StageNumber(stage: stage, size: 18)
                    StageNumber(stage: stage, size: 30)
                    StageNumber(stage: stage, size: 44)

                    Text(stage.localizedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
    }
}

struct StageNumber_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        StageNumberPreviewShowcase()
            .previewMockEnvironment(suiteName: "StageNumberPreview")
            .previewLayout(.sizeThatFits)
    }
}
#endif
