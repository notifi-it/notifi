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
    // A revoked key whose name a live key now carries is not listed: regenerating
    // the default retires one and mints another under the same name, and showing
    // both put "default" in Active and in Revoked at once. Live keys are never
    // merged this way — two of them can share a name, and each is revoked from its
    // own row, so hiding one would leave a working key with no way to turn it off.
    private var revokedKeys: [CachedKey] { keys.revokedUnderUnusedNames }
    // The default leads the list. Not `sorted(by:)` — a boolean predicate is
    // not a strict weak ordering, and Swift's sort is allowed to misbehave on
    // one.
    private var orderedActiveKeys: [CachedKey] {
        activeKeys.filter(\.isDefault) + activeKeys.filter { !$0.isDefault }
    }

    private var criticalKeys: [CachedKey] { activeKeys.filter(\.isCritical) }

    /// Read twice: the banner is a block, so whether it is up decides whether
    /// the section label below it is the one opening the screen.
    private var refreshFailed: Bool { model.sync?.keysRefreshFailed == true }

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
                // What a key is, said once at the top rather than only while
                // the list is empty — the reader who needs it most is the one
                // who has not made a key yet, but it stays true afterwards.
                // Prose, not metadata: Karla in muted, the same treatment
                // consequence copy gets, because a sentence set in the mono
                // metadata font reads as terminal output.
                Text(Copy.Keys.intro)
                    .font(Theme.body)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)
                    .geistGutter()

                if refreshFailed {
                    InlineError(message: Copy.Keys.refreshFailed)
                        .geistGutter()
                }

                SectionLabel(text: Copy.Keys.sectionActive,
                             trailing: "\(orderedActiveKeys.count)",
                             isFirst: !refreshFailed)
                    .geistGutter()

                if !hasLoaded && keys.isEmpty {
                    // Nothing is claimed while the answer is still in flight. A
                    // spinner would be the other option; at the length of a key
                    // refresh it reads as the screen being slow rather than busy.
                    Color.clear.frame(height: 1)
                } else {
                    ForEach(orderedActiveKeys) { key in
                        NavigationLink(value: key) {
                            KeyRow(key: key, isFixture: key.isDefault)
                        }
                        .buttonStyle(.geistRow)
                        .geistGutter()
                        // Applied outside the gutter, so the patch runs the full
                        // width of the column rather than reading as a card
                        // floating inside the margins.
                        .background {
                            if key.isDefault {
                                StaticField(level: .raised, fillsScreen: false)
                            }
                        }
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

                // The docs sit at the foot for the same reason the site does in
                // Settings: the link leaves the app, which is not what the rows
                // above it do. It goes to the API section because the keys
                // listed here are used from scripts, and that is where the
                // sending side is written up.
                Link(destination: URL(string: "https://notifi.it/#api")!) {
                    HStack(spacing: 5) {
                        Text(Copy.Keys.docsLink)
                            .font(Theme.metaSmall)
                        Image("akar-link-chain")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 11, height: 11)
                            // The glyph only says the link leaves the app, which
                            // the link itself already says — same reasoning as
                            // the Settings foot link.
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
    // The default key is part of the product rather than something the reader
    // made, and the row says so — uppercase name, the bell leading, a raised
    // ground — instead of carrying a chip that labels it.
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
                        // A pager key that has gone quiet is the one worth
                        // investigating, so staleness sits on the row rather than
                        // a tap away. A never-used key adds nothing here — its
                        // zero sent count already reads as silence.
                        if let used = key.lastUsedDate {
                            Text(Copy.Keys.rowLastUsed(Copy.Age.ago(RelativeAge.string(since: used))))
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
    }
}
