import SwiftUI

struct RestoreExplainerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 52))
                .foregroundStyle(.tint)

            Text("This looks like a new device")
                .font(.inco(.title2, weight: .bold))
                .multilineTextAlignment(.center)

            Text("Your old messages restored from a backup, but your keys did not. Keys are tied to the device they were created on and cannot be moved. Anything still sending to your old keys will now get a 401 — create fresh keys to keep receiving notifications.")
                .font(.inco(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Continue") {
                model.acknowledgeRestore()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: 480)
    }
}
