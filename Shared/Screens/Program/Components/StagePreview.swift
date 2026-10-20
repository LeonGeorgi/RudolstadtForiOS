import SwiftUI

struct StagePreview: View {
    let stage: Stage

    var body: some View {
        Group {
            if stage.hasLocation {
                StageMapView(stage: stage)
            } else {
                Label("stage.location.unknown", systemImage: "mappin.slash").padding()
            }
        }
    }
}

struct StagePreview_Previews: PreviewProvider {
    static var previews: some View {
        StagePreview(stage: .example)
            .frame(width: 400, height: 400)
    }
}
