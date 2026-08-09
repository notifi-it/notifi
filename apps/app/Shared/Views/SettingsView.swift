import SwiftUI
import UserNotifications

/// Settings.
///
/// Geist replaces `Form` with hairline-ruled sections — `Form` brings grouped
/// backgrounds and system insets that fight a pure-black ground.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var testState: TestState = .idle
    @State private var testMessage: String?
    @State private var testFailed = false

    private enum TestState { case idle, sending }

    var body: some View {
        @Bindable var model = model

        GeistPage(scroll: .page) {
            GeistHeader(title: Copy.Settings.title)
        } content: {
            // The gutter sits on each block rather than on the stack, so the
            // rules between rows run the full width of the column while the
            // content they separate stays inside the margin.
            VStack(alignment: .leading, spacing: 0) {
                // MARK: Notifications
                SectionLabel(text: Copy.Settings.sectionNotifications)
                    .geistGutter()

                FieldRow(label: Copy.Settings.permission) {
                    Text(permissionText)
                        .font(.inco(.subheadline, weight: .medium))
                        .foregroundStyle(model.notificationStatus == .authorized
                                         ? Theme.fg : Theme.muted)
                }
                .geistGutter()
                Hairline()

                if model.notificationStatus != .authorized {
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

                // MARK: Appearance
                SectionLabel(text: Copy.Settings.sectionAppearance)
                    .geistGutter()

                SegmentedRow(
                    title: Copy.Settings.ground,
                    options: Appearance.allCases,
                    label: \.title,
                    selection: $model.appearance
                )
                .geistGutter()
                Hairline()

                Text(Copy.Settings.groundDetail)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .geistGutter()

                // MARK: Privacy
                SectionLabel(text: Copy.Settings.sectionPrivacy)
                    .geistGutter()

                ToggleRow(
                    title: Copy.Settings.loadImages,
                    detail: Copy.Settings.loadImagesDetail,
                    isOn: $model.remoteImagesEnabled
                )
                .geistGutter()
                Hairline()

                // MARK: Diagnostics
                SectionLabel(text: Copy.Settings.sectionDiagnostics)
                    .geistGutter()

                Button {
                    Task { await sendTest() }
                } label: {
                    HStack(spacing: 10) {
                        Text(Copy.Settings.sendTest)
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                        Spacer(minLength: 8)
                        if testState == .sending {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.muted)
                        } else {
                            Image(systemName: "paperplane")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.dim)
                        }
                    }
                    .padding(.vertical, Theme.rowPadV)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.geistRow)
                .disabled(testState == .sending)
                .geistGutter()

                if let testMessage {
                    Group {
                        if testFailed {
                            InlineError(message: testMessage).padding(.bottom, 12)
                        } else {
                            AnnouncedText(message: testMessage)
                                .padding(.bottom, 12)
                        }
                    }
                    .geistGutter()
                }
                Hairline()

                Text(Copy.Settings.sendTestDetail)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 10)
                    .geistGutter()

                // MARK: Support
                SectionLabel(text: Copy.Settings.sectionSupport)
                    .geistGutter()

                // Two mailboxes, split by intent, so a bug report is not
                // filed in the same queue as a greeting: report@ carries what
                // is broken, hello@ everything else.
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

                Link(destination: URL(string: "mailto:hello@notifi.it")!) {
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

                Text(Copy.Settings.keysAreDeviceBound)
                    .geistConsequence()
                    .padding(.top, 16)
                    .geistGutter()

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

    private func sendTest() async {
        testState = .sending
        testMessage = nil
        testFailed = false
        do {
            try await model.sendTestNotification()
            testMessage = Copy.Settings.testSent
        } catch NotifiError.identityMissing {
            testFailed = true
            testMessage = Copy.Settings.testNoDefaultKey
        } catch {
            testFailed = true
            testMessage = (error as? APIError)?.userMessage ?? Copy.Settings.testFailed
        }
        testState = .idle
    }
}
