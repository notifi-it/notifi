import SwiftUI

// Shared primitives for the Geist system. Everything here is dark-only and
// monochrome; the only colour that appears is `Theme.brand` on an unread marker
// and `Theme.danger` on a destructive action.

// MARK: - Search

/// The inbox search input.
///
/// This is deliberately not `.searchable` — the system field brings its own
/// material, tint and placement, none of which match. Behaviour we do keep:
/// a clear button, submit-to-dismiss-keyboard, and a focus ring.
struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"
    /// Owned by the parent so the field can be dismissed from anywhere —
    /// scrolling, tapping a row, or tapping empty space.
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(focused.wrappedValue ? Theme.muted : Theme.dim)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Theme.body)
                .foregroundStyle(Theme.fg)
                .tint(Theme.brand)
                .focused(focused)
                .submitLabel(.search)
                .onSubmit { focused.wrappedValue = false }
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif

            if !text.isEmpty {
                Button {
                    text = ""
                    focused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.dim)
                        // Sized rather than outset: this one sits against the
                        // field's own tap area, so an expanded shape would start
                        // clearing the text when you meant to put the caret at
                        // the end of it. Full field height, 32 wide, which clears
                        // the 24pt floor without reaching the words.
                        .frame(width: 32, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.geist)
                .accessibilityLabel("Clear search")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 11)
        // Minimum, not fixed: the field's text scales with Dynamic Type, and a
        // hard height clipped it at the accessibility sizes.
        .frame(minHeight: 38)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
        // 2pt when focused, and `muted` rather than a half-opacity wash of it —
        // the old ring composited to 2.7:1 against the field it sat on, under the
        // 3:1 a focus indicator has to clear.
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(focused.wrappedValue ? Theme.muted : Theme.controlBorder,
                        lineWidth: focused.wrappedValue ? 2 : 1)
        )
        .animation(Theme.press, value: text.isEmpty)
        .animation(Theme.press, value: focused.wrappedValue)
    }
}

// MARK: - Small parts

/// A bordered mono chip. Used for links, key names and counts.
struct Chip: View {
    var text: String
    var color: Color = Theme.muted
    var border: Color = Theme.chip
    var trailingGlyph: String?

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
            if let trailingGlyph {
                Text(trailingGlyph)
            }
        }
        .font(Theme.label)
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(border, lineWidth: 1))
    }
}

/// An uppercase section rule — the only structural device in the system.
struct SectionLabel: View {
    var text: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 10) {
            Text(text.uppercased())
                .font(Theme.sectionLabel)
                .tracking(1.4)
                .foregroundStyle(Theme.dim)
            Hairline()
            if let trailing {
                Text(trailing)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
            }
        }
        // 34, not 22. Adjacent rows inside a section already sit 24pt apart
        // (12 above and below each), so at 22 the gap that separated two sections
        // was narrower than the gap between two rows of the same one — the label
        // and its rule were carrying the structure unaided.
        .padding(.top, 34)
        .padding(.bottom, 9)
    }
}

/// The solid light pill — the system's only filled control.
struct PillButton: View {
    var title: String
    var role: ButtonRole?
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.inco(.footnote, weight: .semibold))
                .foregroundStyle(role == .destructive ? Color.white : Theme.bg)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(role == .destructive ? Theme.danger : Theme.fg,
                            in: RoundedRectangle(cornerRadius: Theme.radius))
        }
        .buttonStyle(.geist)
    }
}

/// A glyph-only control, sized to sit in a header's trailing slot beside the
/// wordmark. The label is carried by `accessibilityLabel` rather than on screen.
struct IconButton: View {
    var systemImage: String
    var label: String
    var color: Color = Theme.fg
    /// Draws the glyph on a Liquid Glass circle. Only iOS/macOS 26 have the real
    /// material; older releases fall back to a filled circle rather than fake it.
    var glass: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .glassBackground(enabled: glass)
                // Drawn at 34 and tapped at 44. The disc cannot simply grow:
                // it sits in `GeistBrandRow`, whose height is fixed so the
                // trailing control cannot push one tab's title lower than
                // another's — the exact drift the header row exists to prevent.
                .geistHitArea(expandedBy: 5)
        }
        .buttonStyle(.geist)
        .accessibilityLabel(label)
    }
}

extension View {
    /// Backs the view with Liquid Glass where the OS has it, and a plain fill
    /// where it does not.
    @ViewBuilder
    func glassBackground(enabled: Bool = true, in shape: some Shape = Circle()) -> some View {
        if enabled {
            if #available(iOS 26.0, macOS 26.0, *) {
                glassEffect(.regular, in: shape)
            } else {
                background(shape.fill(Theme.chip.opacity(0.6)))
            }
        } else {
            self
        }
    }
}

/// An outlined control. The default for anything that is not the primary action.
struct OutlineButton: View {
    var title: String
    var color: Color = Theme.fg
    /// Destructive controls take the destructive colour on their border as well as
    /// their label. The border was always `controlBorder`, so "Revoke key" drew the
    /// same grey box as "Copy key" with red words inside it — the one difference
    /// between an irreversible action and a clipboard one being a hue applied to
    /// the smallest part of the control.
    var role: ButtonRole?
    var fill: Bool = true
    var action: () -> Void

    private var tint: Color { role == .destructive ? Theme.danger : color }
    /// `danger` measures 5.36:1 on the ground, well past the 3:1 a control boundary
    /// has to clear, so the destructive border is the full colour rather than a
    /// wash of it.
    private var border: Color { role == .destructive ? Theme.danger : Theme.controlBorder }

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.inco(.footnote, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: fill ? .infinity : nil)
                .padding(.horizontal, fill ? 0 : 14)
                .padding(.vertical, 11)
                // The drawn box is about 37pt. Everything in the app that is not a
                // row or a glyph is one of these, so the shortfall was the app's
                // primary control missing the target floor everywhere at once.
                .frame(minHeight: Theme.minTarget)
                .contentShape(Rectangle())
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(border, lineWidth: 1))
        }
        .buttonStyle(.geist)
    }
}

/// A share control drawn like `OutlineButton`.
struct OutlineShareButton<Item: Transferable>: View {
    var title: String
    var item: Item

    var body: some View {
        ShareLink(item: item, preview: SharePreview(title)) {
            Text(title)
                .font(.inco(.footnote, weight: .semibold))
                .foregroundStyle(Theme.fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                // Sits beside an `OutlineButton` wherever it appears, so it takes
                // the same target floor as well as the same box.
                .frame(minHeight: Theme.minTarget)
                .contentShape(Rectangle())
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.controlBorder, lineWidth: 1))
        }
        .buttonStyle(.geist)
    }
}

/// A key/value line. Replaces `LabeledContent`, which brings system styling.
struct FieldRow<Trailing: View>: View {
    var label: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(Theme.body)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 12)
    }
}

/// The right-hand value of a `FieldRow`. A named type rather than a modified
/// `Text`, so the convenience initialiser below has a concrete `Trailing` to
/// constrain against.
struct FieldValue: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.inco(.subheadline, weight: .medium))
            .foregroundStyle(Theme.fg)
            .multilineTextAlignment(.trailing)
    }
}

extension FieldRow where Trailing == FieldValue {
    init(_ label: String, _ value: String) {
        self.init(label: label) { FieldValue(value) }
    }
}

/// A labelled switch. A switch sits hard against its own label, which puts it at
/// a different distance from the edge on every row. Detached and given the shared
/// control column, the switches line up with each other and with the values in the
/// `FieldRow`s around them.
struct ToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.fg)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(Theme.metaSmall)
                        .foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            // The title goes into the `Toggle`, not just the label beside it.
            // `Toggle("")` with `labelsHidden()` draws the same switch but names
            // it the empty string, so VoiceOver announced "switch, off" with no
            // way to tell which of the three this was — two of them being link
            // policy and Critical Alerts. `labelsHidden()` still keeps the label
            // off screen, so the row looks exactly as it did.
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Theme.brand)
                .frame(width: Theme.controlWidth, alignment: .trailing)
                // A small switch draws about 26pt tall, and the row's own tap area
                // does not reach it — the switch is the only thing here that
                // answers a touch, so what the row is padded to is beside the
                // point. Expanded rather than grown, because the row's height is
                // shared with every other settings row.
                .geistHitArea(expandedBy: 9)
                .accessibilityHint(detail ?? "")
        }
        .padding(.vertical, Theme.rowPadV)
    }
}

/// A tappable row that pushes somewhere, with a chevron.
struct DisclosureRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            content
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.dim)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Empty states

/// The "nothing matched" state. The existing app has no equivalent — a search
/// that matches nothing currently renders a blank list with no explanation.
struct NoResultsView: View {
    var query: String
    var scopeNote: String?
    var onClear: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("No matches")
                .font(.inco(.title3, weight: .bold))
                .foregroundStyle(Theme.fg)

            Text(query.isEmpty
                 ? "Nothing here with that filter."
                 : "Nothing matching “\(query)”.")
                .font(Theme.body)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            if let scopeNote {
                Text(scopeNote)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .multilineTextAlignment(.center)
            }

            OutlineButton(title: "Clear", fill: false, action: onClear)
                .padding(.top, 6)
        }
        .frame(maxWidth: 320)
        .geistGutter()
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
}

/// Inline error copy. Used wherever an API call can fail.
struct InlineError: View {
    var message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("!")
                .font(.inco(.caption, weight: .bold))
                .foregroundStyle(Theme.danger)
                .accessibilityHidden(true)
            Text(message)
                .font(Theme.body)
                .foregroundStyle(Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.danger.opacity(0.3), lineWidth: 1)
        )
        // An error inserted into the tree is silent: VoiceOver announces it only
        // if focus happens to land on it, so someone who just tapped Send heard
        // nothing at all and had no way to tell failure from still-working.
        .onAppear { AccessibilityNotification.Announcement(message).post() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error. \(message)")
    }
}

/// Non-error status copy that appears in response to an action.
///
/// Same problem as `InlineError` and the same fix — the success half of a result
/// has to announce itself too, or the only outcome a VoiceOver user ever hears
/// is the failure.
struct AnnouncedText: View {
    var message: String
    var font: Font = Theme.metaSmall
    var color: Color = Theme.dim

    var body: some View {
        Text(message)
            .font(font)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { AccessibilityNotification.Announcement(message).post() }
    }
}

// MARK: - Screen chrome

/// The header every screen shares: a large title with a count under it, and any
/// screen control on the same line.
///
/// The title and the control share a row rather than stacking, so the screen
/// starts with the thing it is rather than with a bar above it. `.firstTextBaseline`
/// would sit the control on the title's baseline, which drops it well below the
/// cap height of a title this large; centring on the title line keeps the two
/// optically level whether or not there is a subtitle under it.
struct GeistHeader<Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(Theme.screenTitle)
                    .foregroundStyle(Theme.fg)
                    // A 28pt face that scales with Dynamic Type inside a 30pt
                    // frame: without these two the title simply overflowed it at
                    // the accessibility sizes, and "KEYS" lost its own descenderless
                    // top. The Inbox builds its own header and has always set both,
                    // which is why "NOTIFICATIONS" survived where the shared header
                    // did not. The frame stays fixed so the three tabs' titles sit
                    // on the same line as each other.
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: Theme.headerBarHeight, alignment: .leading)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.meta)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 8)
            trailing
                // Minimum, not fixed. `IconButton` draws a 34pt glyph frame, so a
                // hard 30 clipped 2pt off the top and bottom of the disc at the
                // default text size, before Dynamic Type came into it. The title
                // beside it keeps its own fixed frame and is top-aligned, so
                // letting this one grow does not move the title.
                .frame(minHeight: Theme.headerBarHeight)
        }
    }
}

extension GeistHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// A back bar for pushed screens.
struct GeistBackBar: View {
    var label: String = "Notifications"
    var dismiss: () -> Void
    var trailing: AnyView?

    var body: some View {
        HStack(spacing: 7) {
            // Glyph only. `label` still names the destination for VoiceOver, and
            // `chevron.backward` rather than `.left` so it mirrors in right-to-left
            // languages, as the system's own back button does.
            IconButton(systemImage: "chevron.backward",
                       label: "Back to \(label)",
                       glass: true,
                       action: dismiss)

            Spacer(minLength: 8)
            if let trailing { trailing }
        }
        .padding(.vertical, 10)
    }
}
