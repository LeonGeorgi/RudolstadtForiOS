import SwiftUI

struct ProgramItemText: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .padding(.vertical, 4)
    }
}

struct ProgramItemText_Previews: PreviewProvider {
    static var previews: some View {
        ProgramItemText(title: "Example")
    }
}
