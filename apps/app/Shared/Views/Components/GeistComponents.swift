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
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(focused.wrappedValue ? Theme.muted.opacity(0.5) : Theme.chip, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: text.isEmpty)
        .animation(.easeOut(duration: 0.12), value: focused.wrappedValue)
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
        .padding(.top, 22)
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
        .buttonStyle(.plain)
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
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
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
    var fill: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.inco(.footnote, weight: .semibold))
                .foregroundStyle(color)
                .frame(maxWidth: fill ? .infinity : nil)
                .padding(.horizontal, fill ? 0 : 14)
                .padding(.vertical, 11)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.chip, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.chip, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Theme.brand)
                .frame(width: Theme.controlWidth, alignment: .trailing)
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
        .padding(.horizontal, Theme.gutter)
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
    }
}

// MARK: - Screen chrome

/// The header every screen shares: wordmark, an optional trailing control, then a
/// large title with a count beside it.
struct GeistHeader<Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark(size: 17)
                Spacer(minLength: 8)
                trailing
            }
            .frame(height: Theme.headerBarHeight)
            .padding(.bottom, Theme.headerBarGap)

            HStack(alignment: .firstTextBaseline, spacing: 11) {
                Text(title)
                    .font(Theme.screenTitle)
                    .foregroundStyle(Theme.fg)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.meta)
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
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
