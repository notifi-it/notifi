import SwiftUI

struct KeysView: View {
    @Environment(AppModel.self) private var model
    #if os(iOS)
    @State private var showingCreate = false
    #endif
    @State private var showingInfo = false
    @State private var hasLoaded = false

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
                IconButton(systemImage: "info.circle", label: Copy.Keys.aboutKeys, glass: true) {
                    showingInfo = true
                }
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
                        .background {
                            if key.isDefault {
                                StaticField(level: .raised, fillsScreen: false)
                            }
                        }
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
        .alert(Copy.Keys.aboutKeys, isPresented: $showingInfo) {
        } message: {
            Text(Copy.Keys.intro)
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

    var body: some View {
        DisclosureRow {
            HStack(spacing: 12) {
                if isFixture {
                    Image("BellLogo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(Theme.fg)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(key.name)
                            .font(.inco(.headline, weight: isFixture ? .bold : .medium))
                            .textCase(isFixture ? .uppercase : nil)
                            .tracking(isFixture ? 0.5 : 0)
                            .foregroundStyle(key.isRevoked ? Theme.read : Theme.fg)
                            .lineLimit(1)
                    }
                    HStack(spacing: 10) {
                        Text(key.maskedValue)
                            .font(Theme.meta)
                            .foregroundStyle(Theme.muted)
                        Text(sent)
                            .font(Theme.metaSmall)
                            .foregroundStyle(Theme.dim)
                        if let used = key.lastUsedDate {
                            Text(Copy.Keys.rowLastUsed(RelativeAge.agoString(since: used)))
                                .font(Theme.metaSmall)
                                .foregroundStyle(Theme.dim)
                        }
                    }
                }
            }
        }
        .padding(.vertical, isFixture ? 18 : 14)
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
