import SwiftUI

struct KeysView: View {
    @Environment(AppModel.self) private var model
    #if os(iOS)
    @State private var showingCreate = false
    #endif
    @State private var hasLoaded = false

    private var keys: [CachedKey] { model.sync?.keys ?? [] }
    private var activeKeys: [CachedKey] { keys.filter { !$0.isRevoked } }
    private var revokedKeys: [CachedKey] { keys.revokedUnderUnusedNames }
    private var defaultKey: CachedKey? { activeKeys.first { $0.isDefault } }
    private var otherActiveKeys: [CachedKey] { activeKeys.filter { !$0.isDefault } }

    private var criticalKeys: [CachedKey] { activeKeys.filter(\.isCritical) }

    private var refreshFailed: Bool { model.sync?.keysRefreshFailed == true }

    private var subtitle: String {
        let active = Copy.Keys.active(activeKeys.count)
        guard !criticalKeys.isEmpty else { return active }
        return Copy.Keys.criticalSummary(active, "\(criticalKeys.count)")
    }

    var body: some View {
        GeistPage(scroll: .page) {
            GeistHeader(title: Copy.Keys.title, subtitle: subtitle) {
                IconButton(systemImage: "plus", label: Copy.Keys.newKey, glass: true) {
                    #if os(iOS)
                    showingCreate = true
                    #else
                    model.presentingCreateKey = true
                    #endif
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if refreshFailed {
                    InlineError(message: Copy.Keys.refreshFailed)
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

                SectionLabel(text: Copy.Keys.sectionActive,
                             trailing: "\(otherActiveKeys.count)",
                             isFirst: !refreshFailed && defaultKey == nil)
                    .geistGutter()

                if otherActiveKeys.isEmpty && !hasLoaded && keys.isEmpty {
                    Color.clear.frame(height: 1)
                } else if otherActiveKeys.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Keys.emptyTitle)
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
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

                Link(destination: URL(string: "https://notifi.it/#api")!) {
                    HStack(spacing: 5) {
                        Text(Copy.Keys.docsLink)
                            .font(Theme.metaSmall)
                        Image("akar-link-chain")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 11, height: 11)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Theme.muted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.geist)
                .geistHitArea(expandedBy: 15)
                .padding(.top, 14)
                .padding(.bottom, 40)
                .geistGutter()
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
                    if let used = key.lastUsedDate {
                        Text(Copy.Keys.rowLastUsed(Copy.Age.ago(RelativeAge.string(since: used))))
                            .font(Theme.metaSmall)
                            .foregroundStyle(Theme.dim)
                    }
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
