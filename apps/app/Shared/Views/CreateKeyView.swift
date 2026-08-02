import SwiftUI

/// Create a key.
///
/// Two phases. Naming is deliberately plain; the reveal is the important one,
/// because the value is shown exactly once and never again.
struct CreateKeyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

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
                case .entering, .creating: entryForm
                case let .revealed(response): revealScreen(response)
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
        .confirmationDialog(
            "Haven't copied it? This key will never be shown again.",
            isPresented: $showingCloseConfirm,
            titleVisibility: .visible
        ) {
            if case let .revealed(response) = phase {
                Button("Copy and Close") {
                    Clipboard.copy(response.key)
                    finish()
                }
                Button("Close and Revoke", role: .destructive) {
                    Task { await revokeAndClose(response) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Phase 1 — name it

    private var entryForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BrandMark(size: 17)
                Spacer(minLength: 8)
                Button("Cancel") { dismiss() }
                    .font(Theme.body)
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
            }
            .padding(.top, 14)
            .padding(.bottom, 22)

            Text("New key")
                .font(Theme.screenTitle)
                .foregroundStyle(Theme.fg)

            Text("A name only you see. It shows up on the key list and in filters.")
                .font(Theme.body)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            SectionLabel(text: "Name")

            TextField("", text: $name, prompt:
                Text("e.g. Grafana alerts").foregroundStyle(Theme.dim))
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
                .frame(height: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(nameFocused ? Theme.muted.opacity(0.5) : Theme.chip, lineWidth: 1)
                )

            if isReserved {
                Text("“default” is reserved — your device already has one.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 8)
            }

            if let errorMessage {
                InlineError(message: errorMessage).padding(.top, 12)
            }

            PillButtonWide(title: phase == .creating ? "Creating…" : "Create key",
                           enabled: isNameValid && phase != .creating) {
                Task { await create() }
            }
            .padding(.top, 22)
        }
        .onAppear { nameFocused = true }
    }

    // MARK: Phase 2 — the one and only reveal

    private func revealScreen(_ response: CreateKeyResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BrandMark(size: 17)
                Spacer(minLength: 0)
            }
            .padding(.top, 14)
            .padding(.bottom, 22)

            Text("Copy your key now")
                .font(Theme.screenTitle)
                .foregroundStyle(Theme.fg)

            Text("This is the only time it is shown.")
                .font(Theme.body)
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)

            Text(response.key)
                .font(.inco(.subheadline, weight: .medium))
                .foregroundStyle(Theme.fg)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.chip, lineWidth: 1))
                .padding(.top, 22)
                .accessibilityLabel("Your new key")
                .accessibilityValue("Hidden for security. Use Copy.")

            HStack(spacing: 9) {
                OutlineButton(title: hasCopied ? "Copied" : "Copy") {
                    Clipboard.copy(response.key)
                    withAnimation(.easeOut(duration: 0.15)) { hasCopied = true }
                }
                ShareLink(item: response.key) {
                    Text("Share")
                        .font(.inco(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.fg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.chip, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)

            Text("This key lives and dies with this device. If you lose the device, "
                 + "the key stops working and cannot be recovered.")
                .font(Theme.metaSmall)
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            PillButtonWide(title: "Done", enabled: true) { attemptClose() }
                .padding(.top, 22)
        }
    }

    // MARK: Logic

    private var isNameValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 64 && !isReserved
    }

    private var isReserved: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "default"
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
        do {
            let response = try await api.createKey(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            await model.sync?.refreshKeys()
            phase = .revealed(response)
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? "Couldn't create the key."
            phase = .entering
        }
    }

    private func revokeAndClose(_ response: CreateKeyResponse) async {
        try? await model.api?.revokeKey(id: response.id)
        await model.sync?.refreshKeys()
        dismiss()
    }

    private func attemptClose() {
        if hasCopied { finish() } else { showingCloseConfirm = true }
    }

    private func finish() {
        let shouldPrompt = model.notificationStatus == .notDetermined
        dismiss()
        if shouldPrompt {
            Task { await model.requestNotificationPermission() }
        }
    }
}

/// A full-width version of the filled pill, with a disabled state.
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
                        .stroke(enabled ? Color.clear : Theme.chip, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
