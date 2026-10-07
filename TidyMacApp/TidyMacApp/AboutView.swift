import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 17) {
            Image("TidyLeaf")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Tidy")
                    .font(.system(size: 25, weight: .bold))
                    .tracking(-0.7)
                    .foregroundStyle(TidyStyle.ink)

                Text("A little more room to breathe.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TidyStyle.muted)
            }

            Text("Tidy sorts loose files in a folder you choose into clear groups by file type. Review the plan before anything moves. Your files stay on your Mac, and you can undo your last sort while Tidy is open.")
                .font(.system(size: 13))
                .foregroundStyle(TidyStyle.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 340)

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(TidyStyle.green)
                .padding(.top, 2)
        }
        .padding(30)
        .frame(width: 420)
        .background(TidyStyle.paper)
    }
}
