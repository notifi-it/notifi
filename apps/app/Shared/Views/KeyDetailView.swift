import SwiftUI

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
    @State private var copiedCurl = false
    @State private var isUpdatingCritical = false

    private var key: CachedKey? { model.sync?.keys.first { $0.id == keyID } }

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
        .background(StaticField())
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) {
            GeistBackBar(label: Copy.Tabs.keys, dismiss: { dismiss() }, trailing: nil)
                .geistGutter()
                .geistMeasure()
                .background(StaticField())
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
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

            if !key.isDefault {
                Text(Copy.KeyDetail.shownOnceDetail)
                    .geistConsequence()
                    .padding(.top, 10)
            }

            Text(key.maskedValue)
                .font(.inco(.subheadline, weight: .regular))
                .foregroundStyle(Theme.muted)
                .textSelection(.enabled)
                .padding(.top, key.isDefault ? 8 : 14)

            if key.isDefault, let full = model.defaultKeyValue {
                HStack(spacing: 9) {
                    OutlineButton(title: copied ? Copy.Common.copied : Copy.KeyDetail.copyKey) {
                        Clipboard.copySensitive(full)
                        flash()
                    }
                    OutlineButton(title: copiedCurl ? Copy.Common.copied : Copy.KeyDetail.copyCurl) {
                        Clipboard.copySensitive(sendCommand(key: full))
                        flashCurl()
                    }
                    #if os(iOS)
                    OutlineShareButton(title: Copy.KeyDetail.shareKey, item: full)
                    #endif
                }
                .padding(.top, 18)
                Text(Copy.KeyDetail.defaultKeyDetail)
                    .geistConsequence()
                    .padding(.top, 10)
            }

            Link(destination: examplesURL(for: key)) {
                HStack(spacing: 5) {
                    Text(Copy.KeyDetail.examplesLink)
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

    private func examplesURL(for key: CachedKey) -> URL {
        if key.isDefault, let full = model.defaultKeyValue {
            return URL(string: "https://notifi.it/?key=\(full)#send")!
        }
        return URL(string: "https://notifi.it/#send")!
    }

    private func flash() {
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.2)) { copied = false }
        }
    }

    private func flashCurl() {
        withAnimation(.easeOut(duration: 0.15)) { copiedCurl = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.2)) { copiedCurl = false }
        }
    }

    private func sendCommand(key: String) -> String {
        """
        curl -X POST "\(model.baseURL.absoluteString)/send" \\
          -H "Content-Type: application/json" \\
          -d '{"key":"\(key)","title":"Deploy finished","message":"web is live"}'
        """
    }

    private func regenerate() async {
        isRegenerating = true
        errorMessage = nil
        do {
            try await model.regenerateDefaultKey()
            copied = false
            AccessibilityNotification.Announcement(
                Copy.KeyDetail.regeneratedAnnouncement
            ).post()
            Haptics.success()
        } catch {
            errorMessage = (error as? APIError)?.userMessage
                ?? Copy.KeyDetail.regenerateFailed
        }
        isRegenerating = false
    }

    private func setCritical(_ isCritical: Bool) async {
        isUpdatingCritical = true
        errorMessage = nil
        do {
            let granted = try await model.setKeyCritical(id: keyID, isCritical: isCritical)
            if isCritical, granted == .disabled {
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
            AccessibilityNotification.Announcement(Copy.KeyDetail.revokedAnnouncement).post()
            Haptics.success()
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? Copy.KeyDetail.revokeFailed
        }
        isRevoking = false
    }
}
