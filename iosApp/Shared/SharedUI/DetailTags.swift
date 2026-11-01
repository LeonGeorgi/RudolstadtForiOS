import SwiftUI

struct DetailTags<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { content }
            VStack(alignment: .leading, spacing: 4) { content }
        }
    }
}

struct DetailTag: View {
    enum Appearance {
        case inline
        case overImage
    }

    let title: String
    let systemImage: String
    let appearance: Appearance

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(appearance == .overImage ? Color.white : Color.primary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        appearance == .overImage
                            ? Color(white: 0.24).opacity(0.92)
                            : Color.secondary.opacity(0.10)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        appearance == .overImage
                            ? Color.white.opacity(0.18)
                            : Color.primary.opacity(0.08),
                        lineWidth: 0.5
                    )
            }
            .fixedSize()
    }
}
