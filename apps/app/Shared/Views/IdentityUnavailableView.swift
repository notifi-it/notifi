import SwiftUI

struct IdentityUnavailableView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label(Copy.Identity.title, systemImage: "lock.trianglebadge.exclamationmark")
        } description: {
            Text(Copy.Identity.detail)
        } actions: {
            Button(Copy.Common.tryAgain) { model.retryBootstrap() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
