import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationView {
            Text("more.title")
                    .navigationBarTitle("more.title")
        }
    }
}

struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        MoreView()
    }
}
