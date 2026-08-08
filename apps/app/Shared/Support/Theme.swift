import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// The Geist design system: monochrome, hairline rules.
// Brand red appears in exactly two places — the wordmark dot and the unread marker.
//
// Two grounds, one system. Every token below is a pair, and the light half is
// derived from the dark half's *contrast ratio* rather than from its lightness:
// each value was picked to land on the same side of the same WCAG floor against
// the light ground that its dark twin holds against the dark one. Reading the
// two columns as "inverted" is what drifts them apart — the ratios are the
// contract, the numbers are just what satisfies it.

enum Theme {
    // MARK: Colour

    /// The ground. Dark is Apple's near-black (#1C1C1E), not pure black — the
    /// same charcoal the Watch app icon and system dark surfaces sit on. Pure
    /// black made the app read as a hole punched in the home screen. Light is
    /// #FAFAFA rather than #FFF for the same reason in reverse: paper, not a
    /// blown-out panel, and it leaves `surface` somewhere to go.
    static let bg = grey(light: 0.98, dark: 0.11)
    /// Primary text and the app's only full-strength value.
    static let fg = grey(light: 0.102, dark: 0.929)
    /// Titles of messages that have been read. ~8.5:1 on either ground.
    ///
    /// It was 0.42/0.561, within two hundredths of `dim` — so a read row drew its
    /// title and its timestamp in what the eye took for one colour, and the row
    /// lost the step between the thing being said and when it was said. A read
    /// title still steps back from `fg`; it steps back to somewhere `dim` is not.
    static let read = grey(light: 0.28, dark: 0.72)
    /// Body copy and secondary labels. ~7:1 on either ground.
    static let muted = grey(light: 0.36, dark: 0.631)
    /// Timestamps and anything that should recede completely.
    ///
    /// 4.75:1 on the dark ground, 4.65:1 on the light one, and it clears 4.5:1
    /// on `surface` in both. Dark was #6E6E6E, which measured 4.1:1 — under the
    /// floor for body text. That was easy to miss because this reads as a
    /// receding colour, but it carries every explanatory paragraph in the app,
    /// including the ones stating what happens to a key when the device is lost.
    /// The light half is #707070 for the identical reason: #787878 measures
    /// 4.2:1 and is the obvious-looking choice.
    static let dim = grey(light: 0.44, dark: 0.54)
    /// Glyph marks that stand for a property of a row — a link, an image — as
    /// opposed to text that is read.
    ///
    /// Well below `dim`, which is the floor for anything with words in it. These
    /// carry meaning but are not read, so they answer to the 3:1 WCAG asks of
    /// non-text content rather than the 4.5:1 it asks of body copy, and can sit
    /// back further than any label is allowed to. This sits at roughly that 3:1
    /// on either ground and has nowhere further to go — one more step and the
    /// mark stops being reliably visible at all. Do not set text in this.
    static let mark = grey(light: 0.63, dark: 0.355)
    /// Row separators and section rules.
    static let line = grey(light: 0.878, dark: 0.20)
    /// Borders on chips and thumbnails — decoration, not a control boundary.
    static let chip = grey(light: 0.82, dark: 0.235)

    /// The boundary of anything tappable: outlined buttons and text fields.
    ///
    /// Separate from `chip` because WCAG wants 3:1 on a control's boundary and
    /// nothing on a decorative one. At `chip`'s 1.5:1 an `OutlineButton` was
    /// distinguishable from the prose beside it only by its label — which on the
    /// key screen means a destructive action reading as a heading. Light is
    /// #8C8C8C at 3.2:1; #949494, which looks like the natural mirror, is 2.9:1.
    static let controlBorder = grey(light: 0.55, dark: 0.44)
    /// One step off the ground, for inset fields. Light steps *down* from its
    /// ground where dark steps up — the direction that reads as recessed
    /// depends on which way the light is coming from.
    static let surface = grey(light: 0.945, dark: 0.15)

    /// Unread marker and the wordmark dot — nothing else.
    ///
    /// Dark is #C82A2A rather than the artwork's #BC2122: the latter measured
    /// 3.4:1 on pure black and only 2.7:1 once the ground was lifted to `bg`,
    /// under the 3:1 WCAG wants for a non-text mark. On the light ground the
    /// artwork red is the right one — it measures 6:1 there, and using the
    /// lifted dark value instead would put the app's one accent at 4.4:1 and
    /// visibly pinker than the icon beside it. Never use either for text.
    static let brand = rgb(light: (0.737, 0.129, 0.133), dark: (0.784, 0.160, 0.165))

    /// The brand red, adjusted for use as *text* on its ground.
    ///
    /// `brand` clears the 3:1 a dot has to clear but not the 4.5:1 that text
    /// does — on dark. On light the artwork red already clears both, so this
    /// darkens only slightly, to hold the same relationship to `brand` that the
    /// dark pair has. Both sit at roughly 5:1 at their ground's own hue.
    static let brandText = rgb(light: (0.659, 0.114, 0.118), dark: (0.859, 0.290, 0.294))

    /// The red for text that sits *under* something already set in `brandText` —
    /// the preview under an urgent title, the body under an urgent heading.
    ///
    /// Paler and less saturated rather than darker. On a dark ground a receding
    /// colour is normally a dimmer one, but a dimmer red just reads as a browner
    /// red, and two reds that differ only in mud look like a mistake. Washing the
    /// saturation out instead keeps the pair legible as one voice at two volumes.
    /// The light half is not the same hue moved: on paper, pale reads as absent,
    /// so it softens toward the ground from the other side.
    static let brandDim = rgb(light: (0.784, 0.365, 0.361), dark: (0.925, 0.596, 0.588))

    /// Destructive actions. Deliberately further from `brand` than it looks, so
    /// a delete never reads as an unread marker: lighter on the dark ground,
    /// warmer and darker on the light one.
    static let danger = rgb(light: (0.701, 0.133, 0.149), dark: (0.898, 0.282, 0.302))

    /// Resolves per appearance, so a single token serves both grounds.
    ///
    /// The pair is built at the platform colour layer rather than read from an
    /// `@Environment(\.colorScheme)` because these are `static let`s consumed by
    /// `Hairline`, `MacMenuBar` and the notification-service
    /// extension — several of which have no view environment to read.
    private static func grey(light: Double, dark: Double) -> Color {
        pair(light: (light, light, light), dark: (dark, dark, dark))
    }

    private static func rgb(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        pair(light: light, dark: dark)
    }

    private static func pair(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        #if os(iOS)
        Color(UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #endif
    }

    // MARK: Metrics

    static let gutter: CGFloat = 20

    /// The two rules that bound the screen's chrome — under the page header and
    /// above the tab bar.
    ///
    /// Heavier and at full strength on the Mac. The popover is a small panel with
    /// a window border of its own a few points away, and a rule in `line` read as
    /// part of that border rather than as the app dividing itself up; a phone
    /// screen is the whole display and has no competing edge.
    #if os(macOS)
    static let chromeRule: CGFloat = 3
    static let chromeRuleColor = fg
    #else
    static let chromeRule: CGFloat = 2
    static let chromeRuleColor = line
    #endif

    /// The corner on a message block. Larger than `radius`, which is for controls
    /// — a chip and a block of content the size of a paragraph do not read as the
    /// same curve at the same number.
    static let blockRadius: CGFloat = 10

    /// Air above the first band, so the feed does not open hard against the rule
    /// under the header. The Mac needs it: with no fade there, the label was
    /// sitting on the line.
    #if os(macOS)
    static let firstBandTop: CGFloat = 16
    #else
    static let firstBandTop: CGFloat = 2
    #endif

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
    /// from the safe-area edge upward. Enough that a row dissolves rather than
    /// being clipped mid-letter, short enough that a row sitting at rest under it
    /// is still readable.
    ///
    /// It lives entirely below the floating tab bar. Running it up through the
    /// bar dimmed the rows either side of it and read as a smear; confined to the
    /// strip underneath, it only does the job it exists for, which is stopping a
    /// row from being clipped mid-letter at the screen edge.
    static let bottomFade: CGFloat = 44

    /// Height of the fade that closes a screen at the top, under a header that
    /// stays put while the feed moves beneath it.
    ///
    /// Shorter than its bottom twin, which is sized to clear the floating tab
    /// bar as well as to dissolve a row. This one only has to take a line of
    /// type out of the picture before the header's edge cuts it: longer and the
    /// gap it holds open under the count reads as a hole between the title and
    /// the feed.
    static let topFade: CGFloat = 24

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

    /// The age on an unread feed row. Paired with `meta` the way `titleUnread` is
    /// paired with `title`: the weight is the half of the unread signal that
    /// survives a colour filter, and the red is the half that carries at a glance.
    static var metaUnread: Font { .inco(.caption, weight: .semibold) }
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

    /// Copy stating what happens to something that cannot be undone.
    ///
    /// One treatment, in one place, because these sentences were each written at
    /// `metaSmall` in `dim` — the faintest token the system has, the one carrying
    /// footnotes and captions. That put "cannot be recovered" and "will be
    /// rejected" at the bottom of the reading order on the screens where they are
    /// the point. `body` in `muted` is a step up from a footnote and a step below
    /// the row it explains, which is where a consequence belongs.
    func geistConsequence() -> some View {
        font(Theme.body)
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Fades scrolling content into the ground at the bottom edge.
    ///
    /// An overlay rather than a mask: masking the container would fade the tab
    /// bar and the safe-area chrome sitting in front of it too. Because the fade
    /// ends in the ground the screen is already painted on, it is invisible
    /// wherever there is nothing scrolling under it — a short feed needs no
    /// special case.
    ///
    /// iOS only. The Mac draws a hard edge instead: the popover has a window
    /// border of its own to end against, where a phone screen runs to the glass
    /// and needs something to end into.
    @ViewBuilder
    func geistBottomFade() -> some View {
        #if os(macOS)
        self
        #else
        overlay(alignment: .bottom) { GroundFade(edge: .bottom) }
        #endif
    }

    /// Fades scrolling content into the ground as it goes under a pinned header.
    ///
    /// Only for screens whose header stays put — the Inbox and search. On Keys
    /// and Settings the header scrolls away with the content, so there is
    /// nothing passing beneath it to dissolve.
    ///
    /// The strip this covers is held open under the header by a matching top
    /// content margin, so at rest the first row sits clear of it and the fade
    /// reads as space rather than as a dimmed row.
    /// iOS only, for the same reason as the bottom — see above.
    @ViewBuilder
    func geistTopFade() -> some View {
        #if os(macOS)
        self
        #else
        overlay(alignment: .top) { GroundFade(edge: .top) }
        #endif
    }
}

/// See `geistBottomFade()` and `geistTopFade()`.
///
/// Draws the ground itself rather than a ramp of flat `Theme.bg`. The screens
/// this sits on are painted with `StaticField`, and an opaque flat end to the
/// gradient is a smooth band laid across a grainy screen — the same reason the
/// Inbox header carries the static through instead of a plain fill. Masking the
/// texture keeps the grain running to the edge and only takes the content out.
struct GroundFade: View {
    /// Not named `Edge`: SwiftUI has one, and shadowing it inside this type
    /// makes `ignoresSafeArea(edges:)` below read as taking this enum.
    enum Side { case top, bottom }
    let edge: Side

    var body: some View {
        StaticField()
            .frame(height: edge == .top ? Theme.topFade : Theme.bottomFade)
            .mask {
                LinearGradient(
                    // Hand-placed stops rather than an even ramp. Linear alpha
                    // over this distance bands visibly on an OLED panel;
                    // weighting the stops toward the opaque end spreads the
                    // steps out where the eye is looking and reads as smooth.
                    stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white.opacity(0.35), location: 0.4),
                        .init(color: .white.opacity(0.75), location: 0.7),
                        .init(color: .white, location: 1)
                    ],
                    // The stops run from clear to solid, and each edge points
                    // that run at itself: the solid end is always the one
                    // against the screen's own edge or its header.
                    startPoint: edge == .top ? .bottom : .top,
                    endPoint: edge == .top ? .top : .bottom
                )
            }
            // The bottom fade belongs to the screen, not the scroll view, so it
            // has to cover the home-indicator inset as well — otherwise content
            // re-emerges at full strength in the strip below it. The top one has
            // a header above it and no inset to reach into.
            .ignoresSafeArea(edges: edge == .bottom ? .bottom : [])
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

extension View {
    /// The bell's ring: the same damped swing `BellAnimator` plays in the menu
    /// bar, as keyframes — thrown hard to one side, then each return swing a
    /// little smaller until it settles. Every bell answers an arrival with this
    /// one motion; two bells swinging differently read as two apps.
    ///
    /// Peaks and half-swing timing are read off `BellAnimator`'s angle table
    /// (15ms a frame, ~15 frames a half-swing) — change one and the other must
    /// follow. Pivot at the crown, the way a real bell swings.
    func bellSwing(trigger: Int) -> some View {
        keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, angle in
            view.rotationEffect(.degrees(angle), anchor: .top)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-20, duration: 0.11)
                CubicKeyframe(18, duration: 0.225)
                CubicKeyframe(-16, duration: 0.225)
                CubicKeyframe(14, duration: 0.225)
                CubicKeyframe(-13, duration: 0.225)
                CubicKeyframe(12, duration: 0.225)
                CubicKeyframe(-10, duration: 0.225)
                CubicKeyframe(8, duration: 0.225)
                CubicKeyframe(-6, duration: 0.225)
                CubicKeyframe(4, duration: 0.225)
                CubicKeyframe(-2, duration: 0.225)
                CubicKeyframe(0, duration: 0.225)
            }
        }
    }

    /// The clapper's half of the ring: the same pivot and rhythm as `bellSwing`,
    /// held still for a beat and thrown half again as far — the loose part of a
    /// real bell trails the body and overshoots it. Apply to a `*Clapper` layer
    /// drawn over its `*Body`; the generator crops both by the same box, so the
    /// two stay one bell at every angle.
    func clapperSwing(trigger: Int) -> some View {
        keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, angle in
            view.rotationEffect(.degrees(angle), anchor: .top)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0, duration: 0.06)
                CubicKeyframe(-30, duration: 0.11)
                CubicKeyframe(27, duration: 0.225)
                CubicKeyframe(-24, duration: 0.225)
                CubicKeyframe(20, duration: 0.225)
                CubicKeyframe(-18, duration: 0.225)
                CubicKeyframe(15, duration: 0.225)
                CubicKeyframe(-12, duration: 0.225)
                CubicKeyframe(9, duration: 0.225)
                CubicKeyframe(-6, duration: 0.225)
                CubicKeyframe(3, duration: 0.225)
                CubicKeyframe(0, duration: 0.225)
            }
        }
    }
}

/// A one-pixel rule. `Divider()` picks up system colours and insets we do not want.
struct Hairline: View {
    var color: Color = Theme.line
    /// The rules bounding the screen's chrome are heavier than the ones between
    /// two rows. A separator inside a list says "next item"; those say "different
    /// part of the app", and at one pixel they said it in the same voice.
    var weight: CGFloat = 1
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: weight)
            .accessibilityHidden(true)
    }
}
