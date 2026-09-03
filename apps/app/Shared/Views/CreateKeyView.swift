import SwiftUI

struct CreateKeyView: View {
    var onClose: (() -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private enum Phase: Equatable {
        case entering
        case creating
        case revealed(CreateKeyResponse)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.entering, .entering), (.creating, .creating): return true
            case let (.revealed(a), .revealed(b)): return a.id == b.id
            default: return false
            }
        }
    }

    @State private var phase: Phase = .entering
    @State private var name = ""
    @State private var errorMessage: String?
    @State private var hasCopied = false
    @State private var showingCloseConfirm = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch phase {
                case .entering, .creating:
                    entryForm.transition(phaseTransition)
                case let .revealed(response):
                    revealScreen(response).transition(phaseTransition)
                }
            }
            .geistGutter()
            .padding(.bottom, 40)
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .interactiveDismissDisabled(isRevealed)
        .alert(
            Copy.CreateKey.leaveTitle,
            isPresented: $showingCloseConfirm
        ) {
            if case let .revealed(response) = phase {
                Button(Copy.CreateKey.leaveCopyAndClose) {
                    Clipboard.copySensitive(response.key)
                    finish()
                }
                Button(Copy.CreateKey.leaveCloseAndRevoke, role: .destructive) {
                    Task { await revokeAndClose(response) }
                }
            }
            Button(Copy.Common.cancel, role: .cancel) {}
        } message: {
            Text(Copy.CreateKey.leaveMessage)
        }
    }

    private var entryForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer(minLength: 8)
                Button(Copy.Common.cancel) { close() }
                    .font(Theme.body)
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.geist)
                    .geistHitArea(expandedBy: 13)
            }
            .padding(.top, 14)
            .padding(.bottom, 22)

            Text(Copy.CreateKey.title.uppercased())
                .font(Theme.screenTitle)
                .tracking(Theme.screenTitleTracking)
                .foregroundStyle(Theme.fg)

            Text(Copy.CreateKey.intro)
                .font(Theme.body)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            SectionLabel(text: Copy.CreateKey.sectionName)

            TextField("", text: $name, prompt:
                Text(Copy.CreateKey.namePrompt).foregroundStyle(Theme.dim))
                .textFieldStyle(.plain)
                .font(.inco(.body, weight: .medium))
                .foregroundStyle(Theme.fg)
                .tint(Theme.brand)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { if isNameValid { Task { await create() } } }
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .padding(.horizontal, 13)
                .frame(minHeight: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(nameFocused ? Theme.muted : Theme.controlBorder,
                                lineWidth: nameFocused ? 2 : 1)
                )
                .accessibilityLabel(Copy.CreateKey.nameLabel)

            if trimmedCount >= 48 {
                HStack {
                    Spacer(minLength: 8)
                    Text(Copy.CreateKey.charCount("\(trimmedCount)", "64"))
                        .font(Theme.metaSmall)
                        .foregroundStyle(trimmedCount >= 64 ? Theme.danger : Theme.dim)
                }
                .padding(.top, 8)
            }

            if isReserved {
                Text(Copy.CreateKey.nameReserved)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 8)
            } else if isNameTaken {
                Text(Copy.CreateKey.nameTaken)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 8)
            }

            if let errorMessage {
                InlineError(message: errorMessage).padding(.top, 12)
            }

            PillButtonWide(title: phase == .creating ? Copy.CreateKey.creating : Copy.CreateKey.create,
                           enabled: phase != .creating) {
                guard let problem = validationProblem else {
                    Task { await create() }
                    return
                }
                errorMessage = problem
                nameFocused = true
            }
            .padding(.top, 22)
        }
        .onAppear { nameFocused = true }
    }

    private func revealScreen(_ response: CreateKeyResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 22)
                .padding(.top, 14)
                .padding(.bottom, 22)

            Text(Copy.CreateKey.revealTitle.uppercased())
                .font(Theme.screenTitle)
                .tracking(Theme.screenTitleTracking)
                .foregroundStyle(Theme.fg)

            Text(Copy.CreateKey.revealDetail)
                .font(Theme.body)
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)

            Text(response.key.map(String.init).joined(separator: "\u{200B}"))
                .font(.inco(.subheadline, weight: .medium))
                .foregroundStyle(Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.chip, lineWidth: 1))
                .padding(.top, 22)
                .accessibilityLabel(Copy.CreateKey.revealLabel)
                .accessibilityValue(response.key)

            HStack(spacing: 9) {
                OutlineButton(title: hasCopied ? Copy.Common.copied : Copy.Common.copy) {
                    Clipboard.copySensitive(response.key)
                    withAnimation(Theme.press) { hasCopied = true }
                }
                OutlineShareButton(title: Copy.Common.share, item: response.key)
            }
            .padding(.top, 14)

            Text(Copy.CreateKey.revealWarning)
                .font(Theme.metaSmall)
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            PillButtonWide(title: Copy.Common.done, enabled: true) { attemptClose() }
                .padding(.top, 22)
        }
    }

    private var phaseTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
    }

    private var isNameValid: Bool { validationProblem == nil }

    private var trimmedCount: Int {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var validationProblem: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return Copy.CreateKey.validationEmpty }
        if trimmed.count > 64 { return Copy.CreateKey.validationTooLong }
        if isReserved { return Copy.CreateKey.validationReserved }
        if isNameTaken { return Copy.CreateKey.validationTaken }
        return nil
    }

    private var isReserved: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "device"
    }

    private var isNameTaken: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }
        return (model.sync?.keys ?? [])
            .contains { !$0.isRevoked && $0.name.lowercased() == trimmed }
    }

    private var isRevealed: Bool {
        if case .revealed = phase { return true }
        return false
    }

    private func create() async {
        guard let api = model.api else { return }
        errorMessage = nil
        nameFocused = false
        phase = .creating
        AccessibilityNotification.Announcement(Copy.CreateKey.creating).post()
        do {
            let response = try await api.createKey(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            await model.sync?.refreshKeys()
            Haptics.success()
            withAnimation(Theme.reveal) { phase = .revealed(response) }
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? Copy.CreateKey.createFailed
            phase = .entering
        }
    }

    private func revokeAndClose(_ response: CreateKeyResponse) async {
        try? await model.api?.revokeKey(id: response.id)
        await model.sync?.refreshKeys()
        close()
    }

    private func attemptClose() {
        if hasCopied { finish() } else { showingCloseConfirm = true }
    }

    private func finish() {
        let shouldPrompt = model.notificationStatus == .notDetermined
        close()
        if shouldPrompt {
            Task { await model.requestNotificationPermission() }
        }
    }
}

private struct PillButtonWide: View {
    var title: String
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.inco(.footnote, weight: .semibold))
                .foregroundStyle(enabled ? Theme.bg : Theme.dim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(enabled ? Theme.fg : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(enabled ? Color.clear : Theme.controlBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.geist)
        .disabled(!enabled)
    }
}
