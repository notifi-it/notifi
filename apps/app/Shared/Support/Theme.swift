import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

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
    ///
    /// 4.9:1 on the ground and 4.6:1 on `surface`. It was #6E6E6E, which measured
    /// 4.1:1 and 3.9:1 — under the 4.5:1 floor for body text. That was easy to
    /// miss because this reads as a receding colour, but it carries every
    /// explanatory paragraph in the app, including the ones stating what happens
    /// to a key when the device is lost.
    static let dim = Color(white: 0.48)          // #7A7A7A
    /// Row separators and section rules.
    static let line = Color(white: 0.122)        // #1F1F1F
    /// Borders on chips and thumbnails — decoration, not a control boundary.
    static let chip = Color(white: 0.165)        // #2A2A2A

    /// The boundary of anything tappable: outlined buttons and text fields.
    ///
    /// Separate from `chip` because WCAG wants 3:1 on a control's boundary and
    /// nothing on a decorative one. At `chip`'s 1.5:1 an `OutlineButton` was
    /// distinguishable from the prose beside it only by its label — which on the
    /// key screen means a destructive action reading as a heading.
    static let controlBorder = Color(white: 0.38) // #616161
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

    /// The narrowest touch target the system ships. Controls drawn smaller than
    /// this keep their drawn size and widen their hit area instead.
    static let minTarget: CGFloat = 44

    /// Reading measure. Phones are already narrower than this, so it only bites
    /// on iPad, where a full-width `ScrollView` was running explanatory copy past
    /// 170 characters a line.
    static let measure: CGFloat = 620

    /// Height of the fade that closes a scrolling screen at the bottom, measured
    /// from the safe-area edge upward. Roughly two lines of body copy: enough that
    /// a row dissolves rather than being clipped mid-letter, short enough that a
    /// row sitting at rest under it is still readable.
    static let bottomFade: CGFloat = 72

    // MARK: Motion
    //
    // Three durations, and nothing outside them. Every animation in the app is
    // one of: a control acknowledging a press, a state changing in place, or a
    // screen arriving. Anything that does not fit one of those three does not
    // animate — the durations are named so a fourth is a decision rather than a
    // literal someone typed.
    //
    // 0.12 was already the app's de facto curve, at the search field and the
    // press styles below; these tokens name it rather than introduce anything.

    /// Press feedback. Fast enough to read as the control reacting rather than
    /// as an animation playing.
    static let press = Animation.easeOut(duration: 0.12)

    /// A state changing in place — a fill, a tint, a glyph swap.
    static let state = Animation.easeOut(duration: 0.2)

    /// One screen replacing another, or a block of content arriving. The top of
    /// the budget; past this it stops reading as motion and starts reading as
    /// waiting.
    static let reveal = Animation.easeOut(duration: 0.25)

    /// Whether the system is asking for less movement.
    ///
    /// Read directly from the platform rather than through the environment,
    /// because `SyncEngine` animates a `ModelContext` save from outside any view.
    /// Views that can see the environment should prefer
    /// `@Environment(\.accessibilityReduceMotion)`, which updates them when the
    /// setting changes mid-session.
    static var reduceMotion: Bool {
        #if os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #else
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

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

    /// Caps the reading measure and centres the column inside the screen.
    ///
    /// Applied outside `geistGutter()`, so the gutter stays a property of the
    /// column rather than of the window. No effect at phone widths — the column
    /// is already narrower than the cap there.
    func geistMeasure() -> some View {
        frame(maxWidth: Theme.measure, alignment: .leading)
            .frame(maxWidth: .infinity)
    }

    /// Widens a control's touch target without moving anything.
    ///
    /// SwiftUI hit-tests what a `.plain` button actually draws, so an 11pt label
    /// or a bare glyph ships a target a third of the required size. Growing the
    /// frame instead would push the surrounding layout around, and several of
    /// these sit in rows whose height is doing other work — so the drawn size
    /// stays and only the interaction shape grows.
    ///
    /// `pad` is per-site because it depends on what the control already draws.
    /// Keep expanded areas from overlapping another *control*; overlapping
    /// static text is fine, since nothing there competes for the tap.
    func geistHitArea(expandedBy pad: CGFloat) -> some View {
        contentShape(.interaction, Rectangle().inset(by: -pad))
    }

    /// The header block on every tab. Held in one place because applying it per
    /// view let the three drift apart — 14pt under Notifications against 8pt
    /// under Keys and Settings, which read as the tabs being misaligned.
    /// The Mac needs more room above the title than iOS does. On iOS a
    /// navigation bar sits over this block and supplies the separation; in the
    /// popover the title is the first thing under the window's own edge, and at
    /// 4pt it read as pinned to it.
    func geistPageHeader() -> some View {
        #if os(macOS)
        padding(.top, 18).padding(.bottom, 14)
        #else
        padding(.top, 4).padding(.bottom, 14)
        #endif
    }

    /// Fades scrolling content into the ground at the bottom edge.
    ///
    /// An overlay rather than a mask: masking the container would fade the tab
    /// bar and the safe-area chrome sitting in front of it too. Because the fade
    /// ends in `Theme.bg` and the screen behind it *is* `Theme.bg`, it is
    /// invisible wherever there is nothing scrolling under it — a short feed
    /// needs no special case.
    func geistBottomFade() -> some View {
        overlay(alignment: .bottom) { BottomFade() }
    }
}

/// See `geistBottomFade()`.
struct BottomFade: View {
    var body: some View {
        LinearGradient(
            // Hand-placed stops rather than a two-colour ramp. Linear alpha over
            // 72pt of pure black bands visibly on an OLED panel; weighting the
            // stops toward the bottom spreads the steps out where the eye is
            // looking and reads as smooth.
            stops: [
                .init(color: Theme.bg.opacity(0), location: 0),
                .init(color: Theme.bg.opacity(0.35), location: 0.4),
                .init(color: Theme.bg.opacity(0.75), location: 0.7),
                .init(color: Theme.bg, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: Theme.bottomFade)
        // The fade belongs to the screen, not the scroll view, so it has to cover
        // the home-indicator inset as well — otherwise content re-emerges at full
        // strength in the strip below it.
        .ignoresSafeArea(edges: .bottom)
        // Rows run underneath it and still have to answer a tap.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Press feedback for discrete controls.
///
/// Every control in the app was `.buttonStyle(.plain)`, which draws no pressed
/// state on iOS at all — so nothing acknowledged a touch until the action had
/// already finished. 0.96 is the whole effect; below 0.95 it reads as a flinch.
struct GeistPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration)
    }

    /// A nested view rather than the label directly, because `ButtonStyle` is not
    /// a `View` and cannot read `@Environment` itself. Under Reduce Motion the
    /// scale is dropped for a dim, which acknowledges the press without moving
    /// anything.
    private struct PressBody: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: Configuration

        var body: some View {
            configuration.label
                .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.96)
                .opacity(reduceMotion && configuration.isPressed ? 0.6 : 1)
                .animation(Theme.press, value: configuration.isPressed)
        }
    }
}

/// Press feedback for full-width rows.
///
/// A row that scales makes the whole screen look like it twitched, so rows dim
/// the way a system list row does instead.
struct GeistRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(Theme.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GeistPressStyle {
    static var geist: GeistPressStyle { GeistPressStyle() }
}

extension ButtonStyle where Self == GeistRowStyle {
    static var geistRow: GeistRowStyle { GeistRowStyle() }
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
