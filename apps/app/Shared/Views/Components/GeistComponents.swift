import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = Copy.Common.search
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(focused.wrappedValue ? Theme.muted : Theme.dim)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                #if os(macOS)
                .font(.inco(.body, weight: .medium))
                #else
                .font(Theme.body)
                #endif
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
                        .frame(width: 32, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.geist)
                .accessibilityLabel(Copy.Components.clearSearch)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 38)
        .background(Theme.surface)
        #if os(macOS)
        .overlay(
            Rectangle()
                .stroke(Theme.fg, lineWidth: focused.wrappedValue ? 3 : 2)
        )
        #else
        .overlay(
            Rectangle()
                .stroke(focused.wrappedValue ? Theme.muted : Theme.controlBorder,
                        lineWidth: focused.wrappedValue ? 2 : 1)
        )
        #endif
        .animation(Theme.press, value: text.isEmpty)
        .animation(Theme.press, value: focused.wrappedValue)
    }
}

struct Chip: View {
    var text: String
    var color: Color = Theme.muted
    var border: Color = Theme.chip
    var trailingGlyph: String?
    var trailingSymbol: String?
    var trailingSymbolColor: Color = Theme.dim

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
            if let trailingGlyph {
                Text(trailingGlyph)
            }
            if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .imageScale(.small)
                    .foregroundStyle(trailingSymbolColor)
            }
        }
        .font(Theme.label)
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(border, lineWidth: 1))
    }
}

struct SectionLabel: View {
    var text: String
    var trailing: String?
    var isFirst = false

    var body: some View {
        HStack(spacing: 10) {
            Text(text.uppercased())
                .font(Theme.sectionLabel)
                .tracking(1.4)
                .foregroundStyle(Theme.read)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
            }
        }
        .padding(.top, isFirst ? 0 : 34)
        .padding(.bottom, 9)
    }
}

struct GeistGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            StaticField(level: .raised, fillsScreen: false)
                .clipShape(RoundedRectangle(cornerRadius: Theme.blockRadius))
        )
        .padding(.horizontal, Theme.groupInset)
    }
}

struct RowRule: View {
    var body: some View {
        Hairline()
            .padding(.leading, Theme.gutter)
    }
}

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

struct IconButton: View {
    var systemImage: String
    var label: String
    var color: Color = Theme.fg
    var glass: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .glassBackground(enabled: glass)
                .geistHitArea(expandedBy: 5)
        }
        .buttonStyle(.geist)
        .accessibilityLabel(label)
    }
}

extension View {
    @ViewBuilder
    func glassBackground(enabled: Bool = true, in shape: some Shape = Circle()) -> some View {
        if enabled {
            #if os(macOS)
            background(shape.fill(Theme.chip.opacity(0.6)))
            #else
            if #available(iOS 26.0, *) {
                glassEffect(.regular, in: shape)
            } else {
                background(shape.fill(Theme.chip.opacity(0.6)))
            }
            #endif
        } else {
            self
        }
    }
}

struct OutlineButton: View {
    var title: String
    var color: Color = Theme.fg
    var role: ButtonRole?
    var fill: Bool = true
    var action: () -> Void

    private var tint: Color { role == .destructive ? Theme.danger : color }
    private var border: Color { role == .destructive ? Theme.danger : Theme.controlBorder }

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.inco(.footnote, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: fill ? .infinity : nil)
                .padding(.horizontal, fill ? 0 : 14)
                .padding(.vertical, 11)
                .frame(minHeight: Theme.minTarget)
                .contentShape(Rectangle())
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(border, lineWidth: 1))
        }
        .buttonStyle(.geist)
    }
}

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
                .frame(minHeight: Theme.minTarget)
                .contentShape(Rectangle())
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.controlBorder, lineWidth: 1))
        }
        .buttonStyle(.geist)
    }
}

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

struct ToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.fg)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Button {
                        showingDetail = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.dim)
                    }
                    .buttonStyle(.geist)
                    .geistHitArea(expandedBy: 12)
                    .accessibilityHidden(true)
                    .popover(isPresented: $showingDetail, arrowEdge: .bottom) {
                        Text(detail)
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(idealWidth: 280, maxWidth: 280)
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Theme.brand)
                .frame(width: Theme.controlWidth, alignment: .trailing)
                .geistHitArea(expandedBy: 9)
                .accessibilityHint(detail ?? "")
        }
        .padding(.vertical, Theme.rowPadV)
        .onChange(of: isOn) { Haptics.selection() }
    }
}

struct SegmentedRow<Option: Hashable>: View {
    let title: String
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(Theme.body)
                .foregroundStyle(Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    let isSelected = option == selection
                    Button {
                        withAnimation(Theme.state) { selection = option }
                    } label: {
                        Text(label(option))
                            .font(.inco(.caption, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Theme.fg : Theme.dim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(isSelected ? Theme.surface : Color.clear)
                    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)

                    if index < options.count - 1 {
                        Rectangle()
                            .fill(Theme.controlBorder)
                            .frame(width: 1)
                            .accessibilityHidden(true)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(Theme.controlBorder, lineWidth: 1)
            }
            .frame(width: Theme.controlWidth + 32, alignment: .trailing)
            .geistHitArea(expandedBy: 8)
        }
        .padding(.vertical, Theme.rowPadV)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

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

struct NoResultsView: View {
    var query: String
    var scopeNote: String?
    var onClear: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(Copy.Components.noMatches)
                .font(.inco(.title3, weight: .bold))
                .foregroundStyle(Theme.fg)

            Text(query.isEmpty
                 ? Copy.Components.noMatchesDetail
                 : Copy.Components.noMatchesQuery(query))
                .font(Theme.body)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            if let scopeNote {
                Text(scopeNote)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .multilineTextAlignment(.center)
            }

            OutlineButton(title: Copy.Common.clear, fill: false, action: onClear)
                .padding(.top, 6)
        }
        .frame(maxWidth: 320)
        .geistGutter()
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
}

struct InlineError: View {
    var message: String
    var followsAction: Bool = true

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
        .onAppear {
            AccessibilityNotification.Announcement(message).post()
            if followsAction { Haptics.error() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Components.errorLabel(message))
    }
}

struct AnnouncedText: View {
    var message: String
    var font: Font = Theme.metaSmall
    var color: Color = Theme.dim

    var body: some View {
        Text(message)
            .font(font)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear {
                AccessibilityNotification.Announcement(message).post()
                Haptics.success()
            }
    }
}

struct GeistHeader<Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title.uppercased())
                    .font(Theme.screenTitle)
                    .tracking(Theme.screenTitleTracking)
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: Theme.headerBarHeight, alignment: .leading)
                ZStack(alignment: .leading) {
                    Color.clear.frame(width: 0, height: Theme.headerSubtitleHeight)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.meta)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(height: Theme.headerSubtitleHeight, alignment: .leading)
            }
            Spacer(minLength: 8)
            HStack(spacing: Theme.headerActionSpacing) {
                trailing
            }
                .frame(minHeight: Theme.headerBarHeight)
        }
    }
}

extension GeistHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct GeistBackBar: View {
    var label: String = Copy.Tabs.inbox
    var dismiss: () -> Void
    var trailing: AnyView?

    var body: some View {
        HStack(spacing: 7) {
            IconButton(systemImage: "chevron.backward",
                       label: Copy.Components.backTo(label),
                       glass: true,
                       action: dismiss)

            Spacer(minLength: 8)
            if let trailing { trailing }
        }
        .geistPageHeader()
    }
}
