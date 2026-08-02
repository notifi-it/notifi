import SwiftUI

struct CreateKeyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case entering
        case creating
        case revealed(CreateKeyResponse)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.entering, .entering), (.creating, .creating): return true
            case let (.revealed(a), .revealed(b)): return a.id == b.id
            default: return false
            }
        }
    }

    private static let caption = "This key lives and dies with this device. If you lose the device, the key stops working and cannot be recovered."

    @State private var phase: Phase = .entering
    @State private var name = ""
    @State private var errorMessage: String?
    @State private var hasCopied = false
    @State private var showingCloseConfirm = false

    var body: some View {
        content
            .navigationTitle("Create Key")
            .interactiveDismissDisabled(isRevealed)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .entering, .creating:
            entryForm
        case let .revealed(response):
            revealScreen(response)
        }
    }

    private var entryForm: some View {
        Form {
            Section("Name") {
                TextField("e.g. Grafana alerts", text: $name)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }
            if isReserved {
                Text("“default” is reserved — your device already has one.")
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { Task { await create() } }
                    .disabled(!isNameValid || phase == .creating)
            }
        }
    }

    private func revealScreen(_ response: CreateKeyResponse) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Copy your key now")
                    .font(.inco(.title3, weight: .bold))

                Text(response.key)
                    .font(.inco(.body))
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement()
                    .accessibilityLabel("Send key for \(response.name)")
                    .accessibilityValue("Hidden for security. Use Copy.")

                HStack {
                    Button {
                        Clipboard.copy(response.key)
                        hasCopied = true
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)

                    ShareLink(item: response.key) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded { hasCopied = true })
                }

                Text(Self.caption)
                    .font(.inco(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Done") { attemptClose() }
                    .padding(.top)
            }
            .padding()
        }
        .confirmationDialog(
            "Haven't copied it? This key will never be shown again.",
            isPresented: $showingCloseConfirm,
            titleVisibility: .visible
        ) {
            Button("Copy and Close") {
                Clipboard.copy(response.key)
                finish()
            }
            Button("Close and Revoke", role: .destructive) {
                Task {
                    try? await model.api?.revokeKey(id: response.id)
                    await model.sync?.refreshKeys()
                    finish()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var isNameValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 64 && !isReserved
    }

    private var isReserved: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "default"
    }

    private var isRevealed: Bool {
        if case .revealed = phase { return true }
        return false
    }

    private func create() async {
        guard let api = model.api else { return }
        errorMessage = nil
        phase = .creating
        do {
            let response = try await api.createKey(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            await model.sync?.refreshKeys()
            phase = .revealed(response)
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? "Couldn't create the key."
            phase = .entering
        }
    }

    private func attemptClose() {
        if hasCopied {
            finish()
        } else {
            showingCloseConfirm = true
        }
    }

    private func finish() {
        let shouldPrompt = model.notificationStatus == .notDetermined
        dismiss()
        if shouldPrompt {
            Task { await model.requestNotificationPermission() }
        }
    }
}
