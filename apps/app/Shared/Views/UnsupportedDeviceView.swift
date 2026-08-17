import SwiftUI

#if os(macOS)
import AppKit
#endif

struct UnsupportedDeviceView: View {
    var body: some View {
        ContentUnavailableView {
            Label(Copy.Unsupported.title, systemImage: "exclamationmark.shield")
        } description: {
            Text(Copy.Unsupported.detail)
        } actions: {
            #if os(macOS)
            Button(Copy.Common.quit) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderedProminent)
            #endif
        }
        .padding()
    }
}
