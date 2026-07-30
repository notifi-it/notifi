import SwiftUI

#if os(macOS)
import AppKit
#endif

struct UnsupportedDeviceView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Unsupported Mac", systemImage: "exclamationmark.shield")
        } description: {
            Text("notifi requires a Mac with Apple silicon or a T2 chip. This Mac has no Secure Enclave, which notifi uses to protect your identity key.")
        } actions: {
            #if os(macOS)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderedProminent)
            #endif
        }
        .padding()
    }
}
