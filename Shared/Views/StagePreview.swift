import SwiftUI

struct StagePreview: View {
    let stage: Stage
    
    var body: some View {
        StageMapView(stage: stage)
    }
}



struct StagePreview_Previews: PreviewProvider {
    static var previews: some View {
        StagePreview(stage: .example)
            .frame(width: 400, height: 400)
    }
}
