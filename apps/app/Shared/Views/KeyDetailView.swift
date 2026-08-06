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

    /// Without the entitlement the switch would quietly do nothing, so it is
    /// greyed out until Apple grants it. `.disabled` (turned off in system
    /// settings) still allows toggling: that sets the key's standing on the
    /// server, which starts working the moment the user flips it back on.
    private var criticalUnavailable: Bool {
        switch model.criticalAlertStatus {
        case .enabled, .disabled: return false
        default: return true
        }
    }

    private var criticalDetail: String {
        switch model.criticalAlertStatus {
        case .enabled:
            return "Sends from this key that ask for it will sound through "
                + "silent mode and Focus. Add critical=1 to the send."
        case .disabled:
            return "Turned off for notifi in system settings, so these will "
                + "arrive as ordinary notifications until you turn it back on."
        default:
            return "Not available yet — this needs an entitlement Apple has to "
                + "grant notifi. Sends asking for it arrive as ordinary "
                + "notifications in the meantime."
        }
    }

    var body: some View {
        ScrollView {
            if let key {
                content(for: key).geistGutter().geistMeasure()
            } else {
                VStack(spacing: 10) {
                    Text("Key not found")
                        .font(.inco(.title3, weight: .bold))
                        .foregroundStyle(Theme.fg)
                    Text("It may have been removed on another device.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 80)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) {
            GeistBackBar(label: "Keys", dismiss: { dismiss() }, trailing: nil)
                .geistGutter()
                // Capped with the content rather than spanning the window, so on
                // iPad the back button stays on the column's leading edge instead
                // of drifting away from the screen it belongs to.
                .geistMeasure()
                .background(Theme.bg)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        // Centred alerts, not confirmationDialog: the dialog anchors to its
        // source as a popover and reads as a stray tooltip. House rule — see
        // CLAUDE.md.
        .alert(
            key.map { "Revoke “\($0.name)”?" } ?? "Revoke this key?",
            isPresented: $showingRevokeConfirm
        ) {
            Button("Revoke", role: .destructive) { Task { await revoke() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anything still sending to it will be rejected.")
        }
        .alert(
            key.map { "Regenerate “\($0.name)”?" } ?? "Regenerate this key?",
            isPresented: $showingRegenerateConfirm
        ) {
            Button("Regenerate", role: .destructive) { Task { await regenerate() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current value stops working immediately, and anything "
                 + "still sending with it will be rejected.")
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
                    Chip(text: "Default", color: Theme.fg, border: Theme.muted.opacity(0.5))
                }
                if key.isRevoked {
                    Chip(text: "Revoked", color: Theme.dim)
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
                    OutlineButton(title: copied ? "Copied" : "Copy key") {
                        Clipboard.copy(full)
                        flash()
                    }
                    OutlineShareButton(title: "Share key", item: full)
                }
                .padding(.top, 18)
                Text("notifi keeps this one on your device, so you can copy it "
                     + "again whenever you need it, or regenerate it below.")
                    .geistConsequence()
                    .padding(.top, 10)
            } else {
                Text("The value was shown once, when you created this key. "
                     + "It is not stored on the device.")
                    .geistConsequence()
                    .padding(.top, 14)
            }

            SectionLabel(text: "Usage")
            FieldRow("Sent", "\(key.sentCount)")
            Hairline()
            FieldRow("Created", key.createdDate.formatted(date: .abbreviated, time: .shortened))
            Hairline()
            FieldRow("Last used", key.lastUsedDate.map {
                $0.formatted(date: .abbreviated, time: .shortened)
            } ?? "Never")
            Hairline()

            SectionLabel(text: "Links")

            ToggleRow(
                title: "Open any link",
                detail: "Off, only https links open. On, other schemes open too, "
                    + "including ones that launch other apps on this device.",
                isOn: Binding(
                    get: { model.allowsAnyLink(keyID: keyID) },
                    set: { model.setAllowsAnyLink($0, keyID: keyID) }
                )
            )
            Hairline()

            if !key.isRevoked {
                SectionLabel(text: "Alerts")
                ToggleRow(
                    title: "Critical Alerts",
                    detail: criticalDetail,
                    isOn: Binding(
                        get: { key.isCritical },
                        set: { on in Task { await setCritical(on) } }
                    )
                )
                .disabled(isUpdatingCritical || criticalUnavailable)
                Hairline()
            }

            if let errorMessage {
                InlineError(message: errorMessage).padding(.top, 16)
            }

            if key.isRevoked {
                Text("This key is revoked and no longer accepts sends.")
                    .geistConsequence()
                    .padding(.top, 20)
            } else if key.isDefault {
                // No revoke here. Losing the default would leave the device with
                // no key it can hand out, so the only action is to replace it.
                SectionLabel(text: "Danger")
                OutlineButton(title: isRegenerating ? "Regenerating…" : "Regenerate key",
                              role: .destructive) {
                    showingRegenerateConfirm = true
                }
                .disabled(isRegenerating)
                Text("Regenerating issues a new value and retires the old one. "
                     + "Anything still sending with the old value will be "
                     + "rejected.")
                    .geistConsequence()
                    .padding(.top, 10)
            } else {
                SectionLabel(text: "Danger")
                OutlineButton(title: isRevoking ? "Revoking…" : "Revoke key",
                              role: .destructive) {
                    showingRevokeConfirm = true
                }
                .disabled(isRevoking)
                Text("Revoking is permanent. Anything still sending to this key "
                     + "will be rejected.")
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
                "Key regenerated. The old value no longer works."
            ).post()
        } catch {
            errorMessage = (error as? APIError)?.userMessage
                ?? "Couldn't regenerate the key. Check your connection and try again."
        }
        isRegenerating = false
    }

    private func setCritical(_ critical: Bool) async {
        isUpdatingCritical = true
        errorMessage = nil
        do {
            let granted = try await model.setKeyCritical(id: keyID, critical: critical)
            // The switch moving is not evidence the OS agreed. Switching a key on
            // while notifi has no authorisation records the standing and delivers
            // nothing louder than an ordinary notification, so the refusal is said
            // out loud instead of being left to be discovered by a missed page.
            if critical, granted != .enabled {
                errorMessage = "This key is set to ask for Critical Alerts, but "
                    + "notifi is not allowed to sound through silent mode. Turn "
                    + "Critical Alerts on for notifi in system settings."
            }
        } catch NotifiError.criticalAlertsUnavailable {
            errorMessage = "Critical Alerts aren't available in this build yet, so "
                + "nothing was changed."
        } catch {
            errorMessage = (error as? APIError)?.userMessage
                ?? "Couldn't change Critical Alerts for this key. Check your connection and try again."
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
            AccessibilityNotification.Announcement("Key revoked.").post()
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? "Couldn't revoke the key. Check your connection and try again."
        }
        isRevoking = false
    }
}
