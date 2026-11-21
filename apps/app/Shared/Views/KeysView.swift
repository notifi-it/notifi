import SwiftUI

struct KeysView: View {
    @Environment(AppModel.self) private var model
    #if os(iOS)
    @State private var showingCreate = false
    #endif
    @State private var hasLoaded = false
    #if os(macOS)
    @Environment(\.isReaderWindow) private var isReader
    #endif

    private var keys: [CachedKey] { model.sync?.keys ?? [] }
    private var activeKeys: [CachedKey] { keys.filter { !$0.isRevoked } }
    private var revokedKeys: [CachedKey] { keys.revokedUnderUnusedNames }
    private var orderedActiveKeys: [CachedKey] {
        activeKeys.filter(\.isDefault) + activeKeys.filter { !$0.isDefault }
    }

    private var criticalKeys: [CachedKey] { activeKeys.filter(\.isCritical) }


    private var docsURL: URL {
        guard let full = model.defaultKeyValue else {
            return URL(string: "https://notifi.it/#api")!
        }
        return URL(string: "https://notifi.it/?key=\(full)#api")!
    }

    var body: some View {
        GeistPage(scroll: .page) {
            GeistHeader(title: Copy.Keys.title) {
                IconButton(systemImage: "plus", label: Copy.Keys.newKey, glass: true) {
                    #if os(iOS)
                    showingCreate = true
                    #else
                    if isReader {
                        model.readerPresentingCreateKey = true
                    } else {
                        model.presentingCreateKey = true
                    }
                    #endif
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: Copy.Keys.sectionActive,
                             trailing: "\(orderedActiveKeys.count)",
                             isFirst: true)
                    .geistGutter()

                if !hasLoaded && keys.isEmpty {
                    Color.clear.frame(height: 1)
                } else {
                    ForEach(orderedActiveKeys) { key in
                        NavigationLink(value: key) {
                            KeyRow(key: key, isFixture: key.isDefault)
                        }
                        .buttonStyle(.geistRow)
                        .geistGutter()
                        .hoverHighlight()
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
                        .hoverHighlight()
                        Hairline()
                    }
                }

                Link(destination: docsURL) {
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
                .geistHitArea(expandedBy: 17)
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
    var isFixture = false

    private var sent: String {
        Copy.Keys.sent(key.sentCount)
    }

    private var stats: String {
        let count = key.sentCount.formatted()
        guard let used = key.lastUsedDate else { return count }
        return Copy.Keys.rowStats(count, RelativeAge.string(since: used))
    }

    var body: some View {
        DisclosureRow {
            HStack(spacing: 10) {
                Text(key.name)
                    .font(.inco(.headline, weight: isFixture ? .bold : .medium))
                    .foregroundStyle(key.isRevoked ? Theme.read : Theme.fg)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if isFixture {
                    Image(systemName: "lock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                        .accessibilityHidden(true)
                }
                if key.isCritical && !key.isRevoked {
                    Image(systemName: "bolt")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                        .accessibilityHidden(true)
                }
                Text(stats)
                    .font(Theme.meta)
                    .monospacedDigit()
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.vertical, Theme.rowPadV)
        .frame(minHeight: Theme.minTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Copy.Keys.rowLabel(key.name, String(key.prefix.suffix(4)))
            + (key.isRevoked ? Copy.Keys.rowLabelRevoked : "")
            + (key.isCritical && !key.isRevoked ? Copy.Keys.rowLabelCritical : "")
        )
        .accessibilityValue(
            [sent, key.lastUsedDate.map { Copy.Keys.rowLastUsed(RelativeAge.agoString(since: $0)) }]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
    }
}
