import SwiftUI

struct StageCell: View {
    let stage: Stage

    var body: some View {
        HStack {
            StageNumber(stage: stage, size: 34)
            Text(stage.localizedName)
        }
    }
}

struct StageCell_Previews: PreviewProvider {
    static var previews: some View {
        StageCell(stage: .example)
    }
}
