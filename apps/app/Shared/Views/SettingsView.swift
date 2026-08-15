import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var strictSendFailed = false

    var body: some View {
        @Bindable var model = model

        GeistPage(scroll: .page) {
            GeistHeader(title: Copy.Settings.title)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: Copy.Settings.sectionPermissions, isFirst: true)
                    .geistGutter()

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

                SectionLabel(text: Copy.Settings.sectionSupport)
                    .geistGutter()

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

                SectionLabel(text: Copy.Settings.sectionAbout)
                    .geistGutter()

                FieldRow(Copy.Settings.version, AppModel.appVersion)
                    .geistGutter()
                Hairline()

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

                Link(destination: URL(string: "https://notifi.it")!) {
                    HStack(spacing: 5) {
                        Text(Copy.Settings.website)
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
