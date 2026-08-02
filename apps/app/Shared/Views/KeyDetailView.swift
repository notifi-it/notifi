import SwiftUI

struct KeyDetailView: View {
    @Environment(AppModel.self) private var model
    let keyID: Int

    @State private var showingRevokeConfirm = false
    @State private var isRevoking = false
    @State private var errorMessage: String?

    private var key: CachedKey? { model.sync?.keys.first { $0.id == keyID } }

    var body: some View {
        Form {
            if let key {
                Section {
                    LabeledContent("Name", value: key.name)
                    LabeledContent("Key") {
                        Text(key.maskedValue)
                            .font(.inco(.body))
                    }
                    Button("Copy Masked Value") { Clipboard.copy(key.maskedValue) }
                    if key.name.lowercased() == "default", let full = model.defaultKeyValue {
                        Button("Copy Full Key") { Clipboard.copy(full) }
                    }
                }

                Section("Usage") {
                    LabeledContent("Sent", value: "\(key.sentCount)")
                    LabeledContent("Created", value: key.createdDate.formatted(date: .abbreviated, time: .shortened))
                    if let last = key.lastUsedDate {
                        LabeledContent("Last used", value: last.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        LabeledContent("Last used", value: "Never")
                    }
                }

                if key.isRevoked {
                    Section {
                        Text("This key is revoked and no longer accepts sends.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Button("Revoke Key", role: .destructive) {
                            showingRevokeConfirm = true
                        }
                        .disabled(isRevoking)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            } else {
                ContentUnavailableView("Key not found", systemImage: "key.slash")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(key?.name ?? "Key")
        .confirmationDialog(
            "Revoke this key? Anything still sending to it will start getting 401.",
            isPresented: $showingRevokeConfirm,
            titleVisibility: .visible
        ) {
            Button("Revoke", role: .destructive) { Task { await revoke() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func revoke() async {
        guard let api = model.api else { return }
        isRevoking = true
        defer { isRevoking = false }
        do {
            try await api.revokeKey(id: keyID)
            await model.sync?.refreshKeys()
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? "Couldn't revoke the key."
        }
    }
}
