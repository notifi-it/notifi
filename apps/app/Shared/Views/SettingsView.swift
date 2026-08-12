import SwiftUI
import UserNotifications

/// Settings.
///
/// Geist replaces `Form` with hairline-ruled sections — `Form` brings grouped
/// backgrounds and system insets that fight a pure-black ground.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var strictSendFailed = false


    var body: some View {
        @Bindable var model = model

        GeistPage(scroll: .page) {
            GeistHeader(title: Copy.Settings.title)
        } content: {
            // The gutter sits on each block rather than on the stack, so the
            // rules between rows run the full width of the column while the
            // content they separate stays inside the margin.
            VStack(alignment: .leading, spacing: 0) {
                // MARK: Permissions
                //
                // One section for everything that grants or withholds: what the
                // OS lets notifi show (only when that needs fixing), what a
                // message may fetch, and what a sender may get away with.
                SectionLabel(text: Copy.Settings.sectionPermissions)
                    .geistGutter()

                // Only when something needs fixing. Granted permission is the
                // steady state, and a row confirming it daily is noise; the
                // system-settings door for the healthy case lives at the bottom
                // of the page instead.
                if model.notificationStatus != .authorized {
                    FieldRow(label: Copy.Settings.permission) {
                        Text(permissionText)
                            .font(.inco(.subheadline, weight: .medium))
                            .foregroundStyle(Theme.muted)
                    }
                    .geistGutter()
                    Hairline()

                    OutlineButton(title: Copy.Settings.openSystemSettings) {
                        model.openSystemNotificationSettings()
                    }
                    .padding(.top, 14)
                    .geistGutter()
                }

                // Only when it is wrong. A row that says "Delivery: fine" every
                // day trains the eye to skip the one day it does not.
                if model.pushDeliveryLooksBroken {
                    FieldRow(label: Copy.Settings.delivery) {
                        Text(Copy.Settings.deliveryBroken)
                            .font(.inco(.subheadline, weight: .medium))
                            .foregroundStyle(Theme.brandText)
                    }
                    .geistGutter()
                    Text(Copy.Settings.deliveryBrokenDetail)
                        .geistConsequence()
                        .geistGutter()
                    Hairline()
                }

                ToggleRow(
                    title: Copy.Settings.loadImages,
                    detail: Copy.Settings.loadImagesDetail,
                    isOn: $model.remoteImagesEnabled
                )
                .geistGutter()
                Hairline()

                // The switch reads the model and writes through the API, so it
                // shows what the server will actually do rather than what was
                // last tapped. A failed write leaves it where it was and says so.
                ToggleRow(
                    title: Copy.Settings.strictSend,
                    detail: Copy.Settings.strictSendDetail,
                    isOn: Binding(
                        get: { model.strictSend },
                        set: { wanted in
                            Task {
                                strictSendFailed = false
                                do {
                                    try await model.setStrictSend(wanted)
                                } catch {
                                    strictSendFailed = true
                                }
                            }
                        }
                    )
                )
                .geistGutter()

                if strictSendFailed {
                    InlineError(message: Copy.Settings.strictSendFailed)
                        .padding(.bottom, 12)
                        .geistGutter()
                }
                Hairline()

                // MARK: Appearance
                SectionLabel(text: Copy.Settings.sectionAppearance)
                    .geistGutter()

                SegmentedRow(
                    title: Copy.Settings.theme,
                    options: Appearance.allCases,
                    label: \.title,
                    selection: $model.appearance
                )
                .geistGutter()
                Hairline()

                // MARK: Support
                SectionLabel(text: Copy.Settings.sectionSupport)
                    .geistGutter()

                // Split by intent: report@ carries what is broken, and
                // feedback goes to the App Store review page, where it is
                // public and counts toward the rating.
                Link(destination: URL(string: "mailto:report@notifi.it")!) {
                    DisclosureRow {
                        Text(Copy.Settings.support)
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.geistRow)
                .geistGutter()
                Hairline()

                Link(destination: URL(string: "https://apps.apple.com/app/id1563961135?action=write-review")!) {
                    DisclosureRow {
                        Text(Copy.Settings.feedback)
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.geistRow)
                .geistGutter()
                Hairline()

                // MARK: About
                SectionLabel(text: Copy.Settings.sectionAbout)
                    .geistGutter()

                FieldRow(Copy.Settings.version, AppModel.appVersion)
                    .geistGutter()
                Hairline()

                // Sparkle only exists in the macOS build; iOS updates through the
                // App Store and does not link it.
                #if os(macOS)
                ToggleRow(
                    title: Copy.Settings.openAtLogin,
                    detail: Copy.Settings.openAtLoginDetail,
                    isOn: Binding(
                        get: { LoginItem.shared.opensAtLogin },
                        set: { LoginItem.shared.setOpensAtLogin($0) }
                    )
                )
                .geistGutter()
                Hairline()

                ToggleRow(
                    title: Copy.Settings.automaticUpdates,
                    detail: Copy.Settings.automaticUpdatesDetail,
                    isOn: Binding(
                        get: { Updater.shared.automaticallyChecks },
                        set: { Updater.shared.setAutomaticallyChecks($0) }
                    )
                )
                .geistGutter()
                Hairline()

                Button {
                    Updater.shared.checkForUpdates()
                } label: {
                    DisclosureRow {
                        Text(Copy.Settings.checkForUpdates)
                            .font(Theme.body)
                            .foregroundStyle(Updater.shared.canCheck ? Theme.fg : Theme.dim)
                    }
                    .padding(.vertical, Theme.rowPadV)
                }
                .buttonStyle(.geistRow)
                .disabled(!Updater.shared.canCheck)
                .geistGutter()
                Hairline()
                #endif

                // The door to the OS's own notification switches. Duplicated
                // from the Permissions section on purpose: up there it only
                // appears when permission is missing, and hiding the healthy
                // row took the only path to the system page with it.
                Button {
                    model.openSystemNotificationSettings()
                } label: {
                    DisclosureRow {
                        Text(Copy.Settings.openSystemSettings)
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.geistRow)
                .geistGutter()
                Hairline()

                Link(destination: URL(string: "https://notifi.it/privacy")!) {
                    DisclosureRow {
                        Text(Copy.Settings.privacyPolicy)
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.geistRow)
                .geistGutter()
                Hairline()

                // The site sits at the foot rather than in a row of its own: it
                // leaves the app, which is not what the rows above it do.
                Link(destination: URL(string: "https://notifi.it")!) {
                    HStack(spacing: 5) {
                        Text(Copy.Settings.website)
                            .font(Theme.metaSmall)
                        Image("akar-link-chain")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 11, height: 11)
                            // A bundle image with no label falls back to its own
                            // filename, so this read out as "notifi.it, akar link
                            // chain". The glyph only says the link leaves the app,
                            // which the link itself already says.
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Theme.muted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.geist)
                // 11pt text and an 11pt glyph, so the drawn target is about a
                // third of the minimum.
                .geistHitArea(expandedBy: 15)
                .padding(.top, 14)
                .padding(.bottom, 40)
                .geistGutter()
            }
        }
        .task {
            await model.refreshPermission()
            #if os(macOS)
            LoginItem.shared.refresh()
            Updater.shared.refresh()
            #endif
        }
    }

    private var permissionText: String {
        switch model.notificationStatus {
        case .authorized: Copy.Settings.permissionEnabled
        case .denied: Copy.Settings.permissionOff
        case .provisional: Copy.Settings.permissionProvisional
        case .ephemeral: Copy.Settings.permissionEphemeral
        case .notDetermined: Copy.Settings.permissionNotSet
        @unknown default: Copy.Settings.permissionUnknown
        }
    }

}
