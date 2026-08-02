import SwiftUI

/// One key. Revoke is the only destructive action — keys are never deleted, so a
/// revoked key stays visible with its history intact.
struct KeyDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let keyID: Int

    @State private var showingRevokeConfirm = false
    @State private var isRevoking = false
    @State private var errorMessage: String?
    @State private var copied = false

    private var key: CachedKey? { model.sync?.keys.first { $0.id == keyID } }

    var body: some View {
        ScrollView {
            if let key {
                content(for: key).geistGutter()
            } else {
                VStack(spacing: 10) {
                    Text("Key not found")
                        .font(.inco(.title3, weight: .bold))
                        .foregroundStyle(Theme.fg)
                    Text("It may have been removed on another device.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 80)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) {
            GeistBackBar(label: "Keys", dismiss: { dismiss() }, trailing: nil)
                .geistGutter()
                .background(Theme.bg)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .confirmationDialog(
            "Revoke this key? Anything still sending to it will start getting 401.",
            isPresented: $showingRevokeConfirm,
            titleVisibility: .visible
        ) {
            Button("Revoke", role: .destructive) { Task { await revoke() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func content(for key: CachedKey) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(key.name)
                    .font(.inco(.title, weight: .bold))
                    .foregroundStyle(Theme.fg)
                    .fixedSize(horizontal: false, vertical: true)
                if key.isRevoked {
                    Chip(text: "Revoked", color: Theme.dim)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 6)

            Text(key.maskedValue)
                .font(.inco(.subheadline, weight: .regular))
                .foregroundStyle(Theme.muted)
                .textSelection(.enabled)
                .padding(.top, 8)

            // Only the default key's value is retrievable — it is the one kept in
            // the Keychain. Every other key was shown once at creation and is gone,
            // so there is nothing here worth copying.
            if key.name.lowercased() == "default", let full = model.defaultKeyValue {
                OutlineButton(title: copied ? "Copied" : "Copy key") {
                    Clipboard.copy(full)
                    flash()
                }
                .padding(.top, 18)
            } else {
                Text("The value was shown once, when you created this key. "
                     + "It is not stored on the device.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }

            SectionLabel(text: "Usage")
            FieldRow("Sent", "\(key.sentCount)")
            Hairline()
            FieldRow("Created", key.createdDate.formatted(date: .abbreviated, time: .shortened))
            Hairline()
            FieldRow("Last used", key.lastUsedDate.map {
                $0.formatted(date: .abbreviated, time: .shortened)
            } ?? "Never")
            Hairline()

            if let errorMessage {
                InlineError(message: errorMessage).padding(.top, 16)
            }

            if key.isRevoked {
                Text("This key is revoked and no longer accepts sends.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20)
            } else {
                SectionLabel(text: "Danger")
                OutlineButton(title: isRevoking ? "Revoking…" : "Revoke key",
                              color: Theme.danger) {
                    showingRevokeConfirm = true
                }
                .disabled(isRevoking)
                Text("Revoking is permanent. Anything still sending to this key "
                     + "will start getting 401.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }

            Spacer(minLength: 40)
        }
        .padding(.bottom, 40)
    }

    private func flash() {
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.2)) { copied = false }
        }
    }

    private func revoke() async {
        guard let api = model.api else { return }
        isRevoking = true
        errorMessage = nil
        do {
            try await api.revokeKey(id: keyID)
            await model.sync?.refreshKeys()
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? "Couldn't revoke the key."
        }
        isRevoking = false
    }
}
