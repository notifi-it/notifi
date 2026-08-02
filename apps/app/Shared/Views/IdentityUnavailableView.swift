import SwiftUI

struct IdentityUnavailableView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Can't unlock notifi", systemImage: "lock.trianglebadge.exclamationmark")
        } description: {
            Text("notifi could not read its identity key from the keychain. This usually clears once the device has been unlocked. Your messages and send keys are unaffected.")
        } actions: {
            Button("Try Again") { model.retryBootstrap() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
