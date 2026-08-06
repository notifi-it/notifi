import SwiftUI

/// Create a key.
///
/// Two phases. Naming is deliberately plain; the reveal is the important one,
/// because the value is shown exactly once and never again.
struct CreateKeyView: View {
    /// Set when the screen is shown in place rather than presented. The Mac
    /// shows it inside the popover — a sheet there is drawn by AppKit as a
    /// panel sliding over part of the window, which in a 486pt popover reads as
    /// a second window that got stuck halfway.
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
            .geistMeasure()
            .padding(.bottom, 40)
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .interactiveDismissDisabled(isRevealed)
        // A centred alert, not confirmationDialog — the dialog anchors to its
        // source as a popover and reads as a stray tooltip. House rule — see
        // CLAUDE.md.
        .alert(
            "Haven't copied it?",
            isPresented: $showingCloseConfirm
        ) {
            if case let .revealed(response) = phase {
                Button("Copy and close") {
                    Clipboard.copy(response.key)
                    finish()
                }
                Button("Close and revoke", role: .destructive) {
                    Task { await revokeAndClose(response) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This key will never be shown again.")
        }
    }

    // MARK: Phase 1 — name it

    private var entryForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer(minLength: 8)
                Button("Cancel") { close() }
                    .font(Theme.body)
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.geist)
                    .geistHitArea(expandedBy: 13)
            }
            .padding(.top, 14)
            .padding(.bottom, 22)

            Text("New key".uppercased())
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
                // Minimum, not fixed — the field's text scales with Dynamic Type.
                .frame(minHeight: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(nameFocused ? Theme.muted : Theme.controlBorder,
                                lineWidth: nameFocused ? 2 : 1)
                )
                // The field is titled by the section rule above it, which is not
                // something VoiceOver can associate. Without this it announced the
                // prompt — an example of a key name, offered as the name of the
                // field itself.
                .accessibilityLabel("Key name")

            if isReserved {
                Text("“default” is reserved — your device already has one.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 8)
            }

            if let errorMessage {
                InlineError(message: errorMessage).padding(.top, 12)
            }

            // Enabled whenever a request is not already in flight, rather than
            // whenever the name happens to be valid. A disabled button announces
            // "dimmed" and says nothing about what is missing, so an empty field
            // left the flow with no way to ask what was wrong — validation now
            // happens on the tap and says it.
            PillButtonWide(title: phase == .creating ? "Creating…" : "Create key",
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

    // MARK: Phase 2 — the one and only reveal

    private func revealScreen(_ response: CreateKeyResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Holds the space the naming phase gives its Cancel button, so the
            // title does not jump up the screen between the two phases.
            Color.clear
                .frame(height: 22)
                .padding(.top, 14)
                .padding(.bottom, 22)

            Text("Copy your key now".uppercased())
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
                // The value is on screen in plain text and selectable, so
                // withholding it from VoiceOver hid it from one set of users
                // only — and the copy claiming it was hidden for security was
                // not true of the screen it was describing.
                .accessibilityLabel("Your new key")
                .accessibilityValue(response.key)

            HStack(spacing: 9) {
                OutlineButton(title: hasCopied ? "Copied" : "Copy") {
                    Clipboard.copy(response.key)
                    withAnimation(Theme.press) { hasCopied = true }
                }
                OutlineShareButton(title: "Share", item: response.key)
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

    /// How the naming form gives way to the reveal.
    ///
    /// The two phases are different screens in the same sheet, and swapping them
    /// on the same frame read as a glitch rather than as arriving somewhere. The
    /// scale is small on purpose — this is a step forward in one flow, not a new
    /// context — and never `scale(0)`, which collapses the layout on the way in.
    /// Under Reduce Motion the crossfade stays and the scale goes; a hard cut
    /// would be its own jarring change.
    private var phaseTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
    }

    private var isNameValid: Bool { validationProblem == nil }

    /// What to say when the name will not do, phrased as the thing to do next
    /// rather than as what went wrong. `nil` means the name is fine.
    private var validationProblem: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Enter a name for this key." }
        if trimmed.count > 64 { return "Use 64 characters or fewer." }
        if isReserved { return "Choose another name — “default” is your device's own key." }
        return nil
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
            withAnimation(Theme.reveal) { phase = .revealed(response) }
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? "Couldn't create the key. Check your connection and try again."
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
                        .stroke(enabled ? Color.clear : Theme.controlBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.geist)
        .disabled(!enabled)
    }
}
