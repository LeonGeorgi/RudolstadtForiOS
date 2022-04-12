import SwiftUI

struct StageCell: View {
    let stage: Stage

    var body: some View {
        HStack {
            if stage.stageNumber != nil {
                Text(String(stage.stageNumber!))
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
