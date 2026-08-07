import SwiftUI

/// One key. Keys are never deleted, so a revoked key stays visible with its
/// history intact.
///
/// The destructive action differs by key. The default key regenerates: its value
/// lives on the device, so it can be replaced and you are never left without one.
/// Every other key was shown once and is gone, so the only thing left to do with
/// it is revoke it.
struct KeyDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let keyID: Int

    @State private var showingRevokeConfirm = false
    @State private var showingRegenerateConfirm = false
    @State private var isRevoking = false
    @State private var isRegenerating = false
    @State private var errorMessage: String?
    @State private var copied = false
    @State private var isUpdatingCritical = false

    private var key: CachedKey? { model.sync?.keys.first { $0.id == keyID } }

    /// What "on" actually buys, which depends on how far the OS lets notifi go.
    /// Time Sensitive is the floor and is always available; Critical Alerts are
    /// the ceiling and are not, so the switch stays usable either way and the
    /// text says which one the user is getting.
    private var criticalDetail: String {
        switch model.criticalAlertStatus {
        case .enabled:
            return Copy.KeyDetail.criticalOn
        default:
            return Copy.KeyDetail.criticalTimeSensitive
        }
    }

    var body: some View {
        ScrollView {
            if let key {
                content(for: key).geistGutter().geistMeasure()
            } else {
                VStack(spacing: 10) {
                    Text(Copy.KeyDetail.notFound)
                        .font(.inco(.title3, weight: .bold))
                        .foregroundStyle(Theme.fg)
                    Text(Copy.KeyDetail.notFoundDetail)
                        .font(Theme.body)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 80)
                .frame(maxWidth: .infinity)
            }
        }
        // The ground is painted here rather than inherited: the TabView and
        // the List underneath both draw an opaque backdrop of their own, so a
        // background set once at the root never reaches the screen.
        .background(StaticField())
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) {
            GeistBackBar(label: Copy.Tabs.keys, dismiss: { dismiss() }, trailing: nil)
                .geistGutter()
                // Capped with the content rather than spanning the window, so on
                // iPad the back button stays on the column's leading edge instead
                // of drifting away from the screen it belongs to.
                .geistMeasure()
                // Same as the inbox header: opaque, but grainy rather than flat.
                .background(StaticField())
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        // Centred alerts, not confirmationDialog: the dialog anchors to its
        // source as a popover and reads as a stray tooltip. House rule — see
        // CLAUDE.md.
        .alert(
            key.map { Copy.KeyDetail.revokeTitle($0.name) } ?? Copy.KeyDetail.revokeTitleFallback,
            isPresented: $showingRevokeConfirm
        ) {
            Button(Copy.KeyDetail.revokeConfirm, role: .destructive) { Task { await revoke() } }
            Button(Copy.Common.cancel, role: .cancel) {}
        } message: {
            Text(Copy.KeyDetail.revokeMessage)
        }
        .alert(
            key.map { Copy.KeyDetail.regenerateTitle($0.name) } ?? Copy.KeyDetail.regenerateTitleFallback,
            isPresented: $showingRegenerateConfirm
        ) {
            Button(Copy.KeyDetail.regenerateConfirm, role: .destructive) { Task { await regenerate() } }
            Button(Copy.Common.cancel, role: .cancel) {}
        } message: {
            Text(Copy.KeyDetail.regenerateMessage)
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
                if key.isDefault {
                    Chip(text: Copy.Keys.chipDefault, color: Theme.fg, border: Theme.muted.opacity(0.5))
                }
                if key.isRevoked {
                    Chip(text: Copy.Keys.chipRevoked, color: Theme.dim)
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
            if key.isDefault, let full = model.defaultKeyValue {
                HStack(spacing: 9) {
                    OutlineButton(title: copied ? Copy.Common.copied : Copy.KeyDetail.copyKey) {
                        Clipboard.copy(full)
                        flash()
                    }
                    OutlineShareButton(title: Copy.KeyDetail.shareKey, item: full)
                }
                .padding(.top, 18)
                Text(Copy.KeyDetail.defaultKeyDetail)
                    .geistConsequence()
                    .padding(.top, 10)
            } else {
                Text(Copy.KeyDetail.shownOnceDetail)
                    .geistConsequence()
                    .padding(.top, 14)
            }

            SectionLabel(text: Copy.KeyDetail.sectionUsage)
            FieldRow(Copy.KeyDetail.fieldSent, "\(key.sentCount)")
            Hairline()
            FieldRow(Copy.KeyDetail.fieldCreated, key.createdDate.formatted(date: .abbreviated, time: .shortened))
            Hairline()
            FieldRow(Copy.KeyDetail.fieldLastUsed, key.lastUsedDate.map {
                $0.formatted(date: .abbreviated, time: .shortened)
            } ?? Copy.Common.never)
            Hairline()

            SectionLabel(text: Copy.KeyDetail.sectionLinks)

            ToggleRow(
                title: Copy.KeyDetail.openAnyLink,
                detail: Copy.KeyDetail.openAnyLinkDetail,
                isOn: Binding(
                    get: { model.allowsAnyLink(keyID: keyID) },
                    set: { model.setAllowsAnyLink($0, keyID: keyID) }
                )
            )
            Hairline()

            if !key.isRevoked {
                SectionLabel(text: Copy.KeyDetail.sectionAlerts)
                ToggleRow(
                    title: Copy.KeyDetail.criticalAlerts,
                    detail: criticalDetail,
                    isOn: Binding(
                        get: { key.isCritical },
                        set: { on in Task { await setCritical(on) } }
                    )
                )
                .disabled(isUpdatingCritical)
                Hairline()
            }

            if let errorMessage {
                InlineError(message: errorMessage).padding(.top, 16)
            }

            if key.isRevoked {
                Text(Copy.KeyDetail.revokedNotice)
                    .geistConsequence()
                    .padding(.top, 20)
            } else if key.isDefault {
                // No revoke here. Losing the default would leave the device with
                // no key it can hand out, so the only action is to replace it.
                SectionLabel(text: Copy.KeyDetail.sectionDanger)
                OutlineButton(title: isRegenerating ? Copy.KeyDetail.regenerating : Copy.KeyDetail.regenerate,
                              role: .destructive) {
                    showingRegenerateConfirm = true
                }
                .disabled(isRegenerating)
                Text(Copy.KeyDetail.regenerateDetail)
                    .geistConsequence()
                    .padding(.top, 10)
            } else {
                SectionLabel(text: Copy.KeyDetail.sectionDanger)
                OutlineButton(title: isRevoking ? Copy.KeyDetail.revoking : Copy.KeyDetail.revoke,
                              role: .destructive) {
                    showingRevokeConfirm = true
                }
                .disabled(isRevoking)
                Text(Copy.KeyDetail.revokeDetail)
                    .geistConsequence()
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

    private func regenerate() async {
        isRegenerating = true
        errorMessage = nil
        do {
            try await model.regenerateDefaultKey()
            copied = false
            // Failure announces itself through `InlineError`; success changed the
            // masked value in place and said nothing, so the only outcome a
            // VoiceOver user ever heard from a destructive action was the one that
            // did not happen. Posted the same way `AnnouncedText` does it.
            AccessibilityNotification.Announcement(
                Copy.KeyDetail.regeneratedAnnouncement
            ).post()
        } catch {
            errorMessage = (error as? APIError)?.userMessage
                ?? Copy.KeyDetail.regenerateFailed
        }
        isRegenerating = false
    }

    private func setCritical(_ critical: Bool) async {
        isUpdatingCritical = true
        errorMessage = nil
        do {
            let granted = try await model.setKeyCritical(id: keyID, critical: critical)
            // Only the case the row's own text cannot cover: the user turned
            // Critical Alerts off themselves, so the ceiling is lower than it
            // would otherwise be and nothing on screen would say why. Every other
            // standing is described by `criticalDetail` and needs no error.
            if critical, granted == .disabled {
                errorMessage = Copy.KeyDetail.criticalNotPermitted
            }
        } catch {
            errorMessage = (error as? APIError)?.userMessage
                ?? Copy.KeyDetail.criticalChangeFailed
        }
        isUpdatingCritical = false
    }

    private func revoke() async {
        guard let api = model.api else { return }
        isRevoking = true
        errorMessage = nil
        do {
            try await api.revokeKey(id: keyID)
            await model.sync?.refreshKeys()
            // See `regenerate()`: the success half of a destructive action has to
            // announce itself too.
            AccessibilityNotification.Announcement(Copy.KeyDetail.revokedAnnouncement).post()
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? Copy.KeyDetail.revokeFailed
        }
        isRevoking = false
    }
}
