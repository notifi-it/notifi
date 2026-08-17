import SwiftUI

struct RestoreExplainerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 52))
                .foregroundStyle(.tint)

            Text(Copy.Restore.title)
                .font(.inco(.title2, weight: .bold))
                .multilineTextAlignment(.center)

            Text(Copy.Restore.detail)
                .font(.inco(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(Copy.Common.continueAction) {
                model.acknowledgeRestore()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: 480)
    }
}
