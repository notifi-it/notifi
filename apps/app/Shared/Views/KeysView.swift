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
    private var defaultKey: CachedKey? { activeKeys.first { $0.isDefault } }
    // The default key sits above the count, so Active counts what is listed
    // under it rather than one more than the reader can see.
    private var otherActiveKeys: [CachedKey] { activeKeys.filter { !$0.isDefault } }

    private var subtitle: String {
        let n = activeKeys.count
        return n == 1 ? "1 active" : "\(n) active"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The gutter is applied per block rather than to the stack, so
                // the rules between rows can run the full width of the screen
                // while the content they separate stays inside the margin.
                Group {
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

                }
                .geistGutter()

                if let defaultKey {
                    NavigationLink(value: defaultKey) {
                        KeyRow(key: defaultKey, chipOnlyTitle: true)
                    }
                    .buttonStyle(.geistRow)
                    .geistGutter()
                    Hairline()
                }

                SectionLabel(text: "Active", trailing: "\(otherActiveKeys.count)")
                    .geistGutter()

                if otherActiveKeys.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No active keys yet")
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                        Text("A key is what a script sends with. Make one per source so you can revoke them separately.")
                            .font(Theme.metaSmall)
                            .foregroundStyle(Theme.dim)
                            .fixedSize(horizontal: false, vertical: true)
                        OutlineButton(title: "New key", fill: false) {
                            #if os(iOS)
                            showingCreate = true
                            #else
                            model.presentingCreateKey = true
                            #endif
                        }
                        .padding(.top, 2)
                    }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .geistGutter()
                    Hairline()
                } else {
                    ForEach(otherActiveKeys) { key in
                        NavigationLink(value: key) {
                            KeyRow(key: key)
                        }
                        .buttonStyle(.geistRow)
                        .geistGutter()
                        Hairline()
                    }
                }

                if !revokedKeys.isEmpty {
                    SectionLabel(text: "Revoked", trailing: "\(revokedKeys.count)")
                        .geistGutter()
                    ForEach(revokedKeys) { key in
                        NavigationLink(value: key) {
                            KeyRow(key: key)
                        }
                        .buttonStyle(.geistRow)
                        .geistGutter()
                        Hairline()
                    }
                }

                Text("A key is shown once, when it is created; notifi stores "
                     + "only the prefix. The default key can be copied again "
                     + "or regenerated from its detail page.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                    .geistGutter()
            }
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
    // The default key gets its own untitled block, where the chip is the only
    // label the row needs; repeating the name above it read as a duplicate.
    var chipOnlyTitle = false

    private var sent: String {
        key.sentCount == 1 ? "1 sent" : "\(key.sentCount) sent"
    }

    var body: some View {
        DisclosureRow {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if chipOnlyTitle {
                        Chip(text: "Default", color: Theme.fg,
                             border: Theme.muted.opacity(0.5))
                    } else {
                        Text(key.name)
                            .font(.inco(.headline, weight: .semibold))
                            .foregroundStyle(key.isRevoked ? Theme.read : Theme.fg)
                            .lineLimit(1)
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
