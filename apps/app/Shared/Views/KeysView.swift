import SwiftUI

struct KeysView: View {
    @Environment(AppModel.self) private var model
    #if os(iOS)
    @State private var showingCreate = false
    #endif

    private var keys: [CachedKey] { model.sync?.keys ?? [] }
    private var activeKeys: [CachedKey] { keys.filter { !$0.isRevoked } }
    private var revokedKeys: [CachedKey] { keys.filter { $0.isRevoked } }

    var body: some View {
        List {
            if model.sync?.keysRefreshFailed == true {
                Text("Couldn't refresh keys. Showing the last known list.")
                    .font(.inco(.footnote))
                    .foregroundStyle(.secondary)
            }

            Section("Active") {
                if activeKeys.isEmpty {
                    Text("No active keys yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(activeKeys) { key in
                    NavigationLink(value: key) {
                        KeyRow(key: key)
                    }
                }
            }

            if !revokedKeys.isEmpty {
                Section("Revoked") {
                    ForEach(revokedKeys) { key in
                        NavigationLink(value: key) {
                            KeyRow(key: key)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Keys")
        .navigationDestination(for: CachedKey.self) { key in
            KeyDetailView(keyID: key.id)
        }
        .refreshable { await model.sync?.refreshKeys() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createKey()
                } label: {
                    Label("Create Key", systemImage: "plus")
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingCreate) {
            NavigationStack { CreateKeyView() }
                .environment(model)
        }
        #endif
        .task { await model.sync?.refreshKeys() }
    }

    private func createKey() {
        #if os(iOS)
        showingCreate = true
        #else
        model.presentingCreateKey = true
        #endif
    }
}

struct KeyRow: View {
    let key: CachedKey

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(key.name)
                .font(.inco(.headline, weight: .semibold))
            Text(key.maskedValue)
                .font(.inco(.subheadline))
                .foregroundStyle(.secondary)
            Text("\(key.sentCount) sent")
                .font(.inco(.caption))
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Key, \(key.name), ends \(key.prefix.suffix(4))\(key.isRevoked ? ", revoked" : "")")
    }
}
