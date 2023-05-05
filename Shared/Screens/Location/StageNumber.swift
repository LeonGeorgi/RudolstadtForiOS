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

    var backgroundColor: Color {
        switch stage.stageType {
        case .festivalTicket:
            return Color(hue: 24/360, saturation: 0.6, brightness: 0.9)
        case .festivalAndDayTicket:
            return Color(hue: 116/360, saturation: 0.2, brightness: 0.7)
        default:
            return Color(hue: 35/360, saturation: 0.4, brightness: 0.8)
        }
    }

    var textColor: Color {
        switch stage.stageType {
        case .festivalTicket, .festivalAndDayTicket:
            return Color.white
        default:
            return Color.black
        }
    }

    var body: some View {
        if let stageNumber = stage.stageNumber {
            Text(String(stageNumber))
                    .frame(width: size, height: size)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .clipShape(Circle())
                    .overlay(
                            Circle()
                                    .stroke(Color.gray, lineWidth: 1)
                                    .opacity(0.3)
                    )
                    .font(font)
        } else {
            Image(systemName: "mappin.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(.cyan)
        }
    }
}
