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
    /// Whether a key list has been seen at all. The first refresh runs on appear,
    /// and until it lands `keys` is empty for the same reason it is empty when
    /// there are none — so the screen was answering "no active keys yet" to a
    /// question it had not asked the server yet.
    @State private var hasLoaded = false

    private var keys: [CachedKey] { model.sync?.keys ?? [] }
    private var activeKeys: [CachedKey] { keys.filter { !$0.isRevoked } }
    private var revokedKeys: [CachedKey] { keys.filter { $0.isRevoked } }
    private var defaultKey: CachedKey? { activeKeys.first { $0.isDefault } }
    // The default key sits above the count, so Active counts what is listed
    // under it rather than one more than the reader can see.
    private var otherActiveKeys: [CachedKey] { activeKeys.filter { !$0.isDefault } }

    private var criticalKeys: [CachedKey] { activeKeys.filter(\.isCritical) }

    /// The count of keys that can sound through silent mode is the one fact a
    /// pager's key list should not make you go two screens to find, so it joins
    /// the active count rather than living only on the detail page.
    private var subtitle: String {
        let active = Copy.Keys.active(activeKeys.count)
        guard !criticalKeys.isEmpty else { return active }
        return Copy.Keys.criticalSummary(active, "\(criticalKeys.count)")
    }

    var body: some View {
        GeistPage(scroll: .page) {
            GeistHeader(title: Copy.Keys.title, subtitle: subtitle) {
                // One control on both platforms. The Mac used to carry a text
                // pill here while iOS had the disc, which drifted the two
                // headers apart for no reason either screen owns.
                IconButton(systemImage: "plus", label: Copy.Keys.newKey, glass: true) {
                    #if os(iOS)
                    showingCreate = true
                    #else
                    model.presentingCreateKey = true
                    #endif
                }
            }
        } content: {
            // The gutter is applied per block rather than to the stack, so the
            // rules between rows can run the full width of the column while the
            // content they separate stays inside the margin.
            VStack(alignment: .leading, spacing: 0) {
                if model.sync?.keysRefreshFailed == true {
                    InlineError(message: Copy.Keys.refreshFailed)
                        .padding(.top, 14)
                        .geistGutter()
                }

                if let defaultKey {
                    NavigationLink(value: defaultKey) {
                        KeyRow(key: defaultKey, chipOnlyTitle: true)
                    }
                    .buttonStyle(.geistRow)
                    .geistGutter()
                    Hairline()
                }

                SectionLabel(text: Copy.Keys.sectionActive, trailing: "\(otherActiveKeys.count)")
                    .geistGutter()

                if otherActiveKeys.isEmpty && !hasLoaded && keys.isEmpty {
                    // Nothing is claimed while the answer is still in flight. A
                    // spinner would be the other option; at the length of a key
                    // refresh it reads as the screen being slow rather than busy.
                    Color.clear.frame(height: 1)
                } else if otherActiveKeys.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        // Not "no active keys": the default key is listed
                        // directly above this, so a screen claiming there are
                        // none was contradicting the row above it. What is
                        // actually empty is everything past the default.
                        Text(Copy.Keys.emptyTitle)
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                        // No button under it. The plus in the header makes a key
                        // from every state this screen can be in, and a second
                        // control that appears only while the list is empty is
                        // one the reader has to learn twice.
                        Text(Copy.Keys.emptyDetail)
                            .font(Theme.metaSmall)
                            .foregroundStyle(Theme.dim)
                            .fixedSize(horizontal: false, vertical: true)
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
                    SectionLabel(text: Copy.Keys.sectionRevoked, trailing: "\(revokedKeys.count)")
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

                // The footnote about keys being shown once is gone. It was the
                // last thing on the screen and it explained a rule that only
                // matters at the moment a key is created — which is its own
                // sheet, and says so there.
            }
        }
        .navigationDestination(for: CachedKey.self) { key in
            KeyDetailView(keyID: key.id)
        }
        .refreshable { await model.sync?.refreshKeys() }
        .task {
            await model.sync?.refreshKeys()
            hasLoaded = true
        }
        #if os(iOS)
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
        Copy.Keys.sent(key.sentCount)
    }

    var body: some View {
        DisclosureRow {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if chipOnlyTitle {
                        Chip(text: Copy.Keys.chipDefault, color: Theme.fg,
                             border: Theme.muted.opacity(0.5))
                    } else {
                        Text(key.name)
                            .font(.inco(.headline, weight: .semibold))
                            .foregroundStyle(key.isRevoked ? Theme.read : Theme.fg)
                            .lineLimit(1)
                    }
                    if key.isRevoked {
                        Chip(text: Copy.Keys.chipRevoked, color: Theme.dim)
                    }
                    // Which keys can sound through silent mode is the defining
                    // attribute of a pager, and it was visible only on the key's
                    // own screen. Revoked keys do not carry it: they send nothing
                    // at all, so saying how loudly would be a lie.
                    if key.isCritical && !key.isRevoked {
                        Chip(text: Copy.Keys.chipCritical, color: Theme.brandText,
                             border: Theme.brandText.opacity(0.45))
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
            Copy.Keys.rowLabel(key.name, String(key.prefix.suffix(4)))
            + (key.isRevoked ? Copy.Keys.rowLabelRevoked : "")
            + (key.isCritical && !key.isRevoked ? Copy.Keys.rowLabelCritical : "")
        )
    }
}
