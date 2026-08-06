import SwiftUI

/// Keys.
///
/// A key is a bearer send-token shown exactly once at creation. This screen only
/// ever holds the prefix, so the design leans on the name and the send count
/// rather than the value.
struct KeysView: View {
    @Environment(AppModel.self) private var model
    #if os(iOS)
    @State private var showingCreate = false
    #endif

    private var keys: [CachedKey] { model.sync?.keys ?? [] }
    private var activeKeys: [CachedKey] { keys.filter { !$0.isRevoked } }
    private var revokedKeys: [CachedKey] { keys.filter { $0.isRevoked } }

    private var subtitle: String {
        let n = activeKeys.count
        return n == 1 ? "1 active" : "\(n) active"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GeistHeader(title: "Keys", subtitle: subtitle) {
                    #if os(iOS)
                    IconButton(systemImage: "plus", label: "New key", glass: true) {
                        showingCreate = true
                    }
                    #else
                    PillButton(title: "New key") { model.presentingCreateKey = true }
                    #endif
                }
                .geistPageHeader()

                if model.sync?.keysRefreshFailed == true {
                    InlineError(message: "Couldn't refresh keys. Showing the last known list.")
                        .padding(.top, 14)
                }

                SectionLabel(text: "Active", trailing: "\(activeKeys.count)")

                if activeKeys.isEmpty {
                    Text("No active keys yet.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.muted)
                        .padding(.vertical, 14)
                    Hairline()
                } else {
                    ForEach(activeKeys) { key in
                        NavigationLink(value: key) {
                            KeyRow(key: key)
                        }
                        .buttonStyle(.geistRow)
                        Hairline()
                    }
                }

                if !revokedKeys.isEmpty {
                    SectionLabel(text: "Revoked", trailing: "\(revokedKeys.count)")
                    ForEach(revokedKeys) { key in
                        NavigationLink(value: key) {
                            KeyRow(key: key)
                        }
                        .buttonStyle(.geistRow)
                        Hairline()
                    }
                }

                Text("Your default key stays on this device, so you can copy it "
                     + "again or regenerate it. Every other key is shown once, "
                     + "when you create it — after that notifi only stores the "
                     + "prefix, and the only thing left to do is revoke it.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
            }
            .geistGutter()
            .geistMeasure()
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .navigationDestination(for: CachedKey.self) { key in
            KeyDetailView(keyID: key.id)
        }
        .refreshable { await model.sync?.refreshKeys() }
        .task { await model.sync?.refreshKeys() }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCreate) {
            NavigationStack { CreateKeyView() }.environment(model)
        }
        #endif
    }
}

private struct KeyRow: View {
    let key: CachedKey

    private var sent: String {
        key.sentCount == 1 ? "1 sent" : "\(key.sentCount) sent"
    }

    var body: some View {
        DisclosureRow {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(key.name)
                        .font(.inco(.headline, weight: .semibold))
                        .foregroundStyle(key.isRevoked ? Theme.read : Theme.fg)
                        .lineLimit(1)
                    if key.isDefault {
                        Chip(text: "Default", color: Theme.fg,
                             border: Theme.muted.opacity(0.5))
                    }
                    if key.isRevoked {
                        Chip(text: "Revoked", color: Theme.dim)
                    }
                }
                HStack(spacing: 10) {
                    Text(key.maskedValue)
                        .font(Theme.meta)
                        .foregroundStyle(Theme.muted)
                    Text(sent)
                        .font(Theme.metaSmall)
                        .foregroundStyle(Theme.dim)
                }
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Key, \(key.name), ends \(key.prefix.suffix(4))"
            + (key.isRevoked ? ", revoked" : "")
        )
    }
}
