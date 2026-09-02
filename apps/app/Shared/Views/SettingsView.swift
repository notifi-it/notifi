import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context

    @State private var strictSendFailed = false
    @State private var confirmingDeleteAll = false

    var body: some View {
        @Bindable var model = model

        GeistPage(scroll: .page) {
            GeistHeader(title: Copy.Settings.title)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: Copy.Settings.sectionPermissions, isFirst: true)
                    .geistGutter()

                GeistGroup {
                    if model.notificationStatus != .authorized {
                        FieldRow(label: Copy.Settings.permission) {
                            Text(permissionText)
                                .font(.inco(.subheadline, weight: .medium))
                                .foregroundStyle(Theme.muted)
                        }
                        .geistGutter()

                        OutlineButton(title: Copy.Settings.openSystemSettings) {
                            model.openSystemNotificationSettings()
                        }
                        .padding(.bottom, 14)
                        .geistGutter()
                        RowRule()
                    }

                    #if os(macOS)
                    if !model.notificationsStayVisible {
                        LabeledRow(title: Copy.Settings.stayVisible, detail: Copy.Settings.stayVisibleDetail) {
                            OutlineButton(title: Copy.Settings.stayVisibleEnable, fill: false, compact: true) {
                                model.openSystemNotificationSettings()
                            }
                        }
                        .geistGutter()
                        RowRule()
                    }
                    #endif

                    ToggleRow(
                        title: Copy.Settings.loadImages,
                        detail: Copy.Settings.loadImagesDetail,
                        isOn: $model.remoteImagesEnabled
                    )
                    .geistGutter()
                    RowRule()

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
                            .geistBannerTransition()
                    }
                }
                .animation(Theme.state, value: strictSendFailed)

                SectionLabel(text: Copy.Settings.sectionApplication)
                    .geistGutter()

                GeistGroup {
                    SegmentedRow(
                        title: Copy.Settings.theme,
                        options: Appearance.allCases,
                        label: \.title,
                        selection: $model.appearance
                    )
                    .geistGutter()
                    RowRule()

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
                    RowRule()

                    ToggleRow(
                        title: Copy.Settings.installUpdatesAutomatically,
                        detail: Copy.Settings.installUpdatesAutomaticallyDetail,
                        isOn: Binding(
                            get: { Updater.shared.automaticallyInstalls },
                            set: { Updater.shared.setAutomaticallyInstalls($0) }
                        )
                    )
                    .geistGutter()
                    RowRule()

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
                    RowRule()
                    #endif

                    Button {
                        model.openSystemNotificationSettings()
                    } label: {
                        DisclosureRow {
                            Text(Copy.Settings.openSystemSettings)
                                .font(Theme.body)
                                .foregroundStyle(Theme.fg)
                        }
                        .padding(.vertical, Theme.rowPadV)
                    }
                    .buttonStyle(.geistRow)
                    .geistGutter()
                    RowRule()

                    Button {
                        confirmingDeleteAll = true
                    } label: {
                        DisclosureRow {
                            Text(Copy.Settings.deleteAll)
                                .font(Theme.body)
                                .foregroundStyle(Theme.danger)
                        }
                        .padding(.vertical, Theme.rowPadV)
                    }
                    .buttonStyle(.geistRow)
                    .geistGutter()
                }

                SectionLabel(text: Copy.Settings.sectionAbout)
                    .geistGutter()

                GeistGroup {
                    #if os(macOS)
                    Link(destination: URL(string: "https://apps.apple.com/app/id1563961135")!) {
                        DisclosureRow {
                            Text(Copy.Settings.iosApp)
                                .font(Theme.body)
                                .foregroundStyle(Theme.fg)
                        }
                        .padding(.vertical, Theme.rowPadV)
                    }
                    .buttonStyle(.geistRow)
                    .geistGutter()
                    RowRule()
                    #else
                    Link(destination: URL(string: "https://notifi.it/#download")!) {
                        DisclosureRow {
                            Text(Copy.Settings.macApp)
                                .font(Theme.body)
                                .foregroundStyle(Theme.fg)
                        }
                        .padding(.vertical, Theme.rowPadV)
                    }
                    .buttonStyle(.geistRow)
                    .geistGutter()
                    RowRule()
                    #endif

                    Link(destination: URL(string: "https://notifi.it/privacy")!) {
                        DisclosureRow {
                            Text(Copy.Settings.privacyPolicy)
                                .font(Theme.body)
                                .foregroundStyle(Theme.fg)
                        }
                        .padding(.vertical, Theme.rowPadV)
                    }
                    .buttonStyle(.geistRow)
                    .geistGutter()
                    RowRule()

                    Link(destination: URL(string: "https://notifi.it")!) {
                        DisclosureRow {
                            Text(Copy.Settings.website)
                                .font(Theme.body)
                                .foregroundStyle(Theme.fg)
                        }
                        .padding(.vertical, Theme.rowPadV)
                    }
                    .buttonStyle(.geistRow)
                    .geistGutter()
                    RowRule()

                    FieldRow(Copy.Settings.version, AppModel.appVersion)
                        .geistGutter()
                }

                SectionLabel(text: Copy.Settings.sectionSupport)
                    .geistGutter()

                GeistGroup {
                    Link(destination: URL(string: "mailto:report@notifi.it")!) {
                        DisclosureRow {
                            Text(Copy.Settings.support)
                                .font(Theme.body)
                                .foregroundStyle(Theme.fg)
                        }
                        .padding(.vertical, Theme.rowPadV)
                    }
                    .buttonStyle(.geistRow)
                    .geistGutter()
                    RowRule()

                    Link(destination: URL(string: "https://apps.apple.com/app/id1563961135?action=write-review")!) {
                        DisclosureRow {
                            Text(Copy.Settings.feedback)
                                .font(Theme.body)
                                .foregroundStyle(Theme.fg)
                        }
                        .padding(.vertical, Theme.rowPadV)
                    }
                    .buttonStyle(.geistRow)
                    .geistGutter()
                }
                .padding(.bottom, 40)
            }
        }
        .alert(Copy.Settings.deleteAllTitle, isPresented: $confirmingDeleteAll) {
            Button(Copy.Settings.deleteAllConfirm, role: .destructive) { deleteAllMessages() }
            Button(Copy.Common.cancel, role: .cancel) {}
        } message: {
            Text(Copy.Settings.deleteAllMessage)
        }
        .task {
            await model.refreshPermission()
            #if os(macOS)
            LoginItem.shared.refresh()
            Updater.shared.refresh()
            #endif
        }
    }

    private func deleteAllMessages() {
        let all = (try? context.fetch(FetchDescriptor<Message>())) ?? []
        for message in all {
            context.delete(message)
        }
        try? context.save()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        model.sync?.reconcileNotifications()
        Haptics.success()
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
