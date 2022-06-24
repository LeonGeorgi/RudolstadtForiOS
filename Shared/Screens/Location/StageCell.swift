import SwiftUI

struct StageCell: View {
    let stage: Stage
    @EnvironmentObject var settings: UserSettings

    var body: some View {
        HStack {
            if let stageNumber = stage.getAdjustedStageNumber(stageNumberType: settings.stageNumberType) {
                Text(String(stageNumber))
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(.infinity)
            }
            Text(stage.localizedName)
        }
    }
}

struct StageCell_Previews: PreviewProvider {
    static var previews: some View {
        StageCell(stage: .example)
    }
}
