import SwiftUI

// The Geist design system: pure black, monochrome, hairline rules.
// Brand red appears in exactly two places — the wordmark dot and the unread marker.
// Dark only; there is no light palette by design.

enum Theme {
    // MARK: Colour

    /// The ground. Pure black, not a near-black — the hairlines do the separating.
    static let bg = Color.black
    /// Primary text and the app's only "bright" value.
    static let fg = Color(white: 0.929)          // #EDEDED
    /// Titles of messages that have been read.
    static let read = Color(white: 0.561)        // #8F8F8F
    /// Body copy and secondary labels.
    static let muted = Color(white: 0.631)       // #A1A1A1
    /// Timestamps and anything that should recede completely.
    static let dim = Color(white: 0.431)         // #6E6E6E
    /// Row separators and section rules.
    static let line = Color(white: 0.122)        // #1F1F1F
    /// Borders on chips, thumbnails and inputs.
    static let chip = Color(white: 0.165)        // #2A2A2A
    /// One step up from the ground, for inset fields.
    static let surface = Color(white: 0.043)     // #0B0B0B

    /// #BC2122. Unread marker and the wordmark dot — nothing else.
    /// 3.4:1 on black: fine for a dot (WCAG wants 3:1 for non-text), never for text.
    static let brand = Color(red: 0.737, green: 0.129, blue: 0.133)

    /// The brand red, lifted for use as *text* on black.
    ///
    /// `brand` itself is 3.4:1 against the ground — fine for a dot, which only has
    /// to clear the 3:1 non-text floor, but under the 4.5:1 that body text needs.
    /// This sits at roughly 5:1 while staying the same hue.
    static let brandText = Color(red: 0.859, green: 0.290, blue: 0.294)

    /// Destructive actions. Deliberately lighter than `brand` so a delete never
    /// reads as an unread marker.
    static let danger = Color(red: 0.898, green: 0.282, blue: 0.302)

    // MARK: Metrics

    static let gutter: CGFloat = 20

    /// The logo row above every tab title. Fixed, because its trailing control
    /// differs per tab — the "New key" pill on Keys, the overflow menu on
    /// Notifications, nothing on Settings — and a taller control was pushing
    /// that tab's title further down than the others.
    static let headerBarHeight: CGFloat = 30

    /// Gap between the logo row and the title beneath it.
    static let headerBarGap: CGFloat = 20
    static let rowGap: CGFloat = 13

    /// Vertical padding on every settings row, so rows carrying a switch, a
    /// value and a disclosure all stand the same height.
    static let rowPadV: CGFloat = 12

    /// Width of the control column on the right of a settings row. Switches and
    /// values share it, so their edges form a line rather than following the
    /// length of each label.
    static let controlWidth: CGFloat = 88
    static let radius: CGFloat = 6
    static let thumb: CGFloat = 42

    // MARK: Type
    //
    // Inconsolata carries every label, number and title; Karla carries message
    // bodies only. Both come through `Font.inco` / `Font.karla`, which are already
    // wired to Dynamic Type via `relativeTo:`.
    //
    // Inconsolata is a variable font (wght 100–900). `.weight()` selects along that
    // axis, so the weights below are real instances, not synthesised.

    static var title: Font { .inco(.headline, weight: .semibold) }
    static var titleUnread: Font { .inco(.headline, weight: .bold) }
    static var body: Font { .karla(.subheadline) }
    static var meta: Font { .inco(.caption, weight: .medium) }
    static var metaSmall: Font { .inco(.caption2, weight: .regular) }
    static var label: Font { .inco(.caption2, weight: .medium) }
    static var screenTitle: Font { .inco(.title, weight: .bold) }
    static var sectionLabel: Font { .inco(.caption2, weight: .semibold) }
}

extension View {
    /// Standard horizontal inset for every screen in the system.
    func geistGutter() -> some View { padding(.horizontal, Theme.gutter) }

    /// The header block on every tab. Held in one place because applying it per
    /// view let the three drift apart — 14pt under Notifications against 8pt
    /// under Keys and Settings, which read as the tabs being misaligned.
    func geistPageHeader() -> some View {
        padding(.top, 4).padding(.bottom, 14)
    }
}

/// A one-pixel rule. `Divider()` picks up system colours and insets we do not want.
struct Hairline: View {
    var color: Color = Theme.line
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
