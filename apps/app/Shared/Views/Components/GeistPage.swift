import SwiftUI

/// The scaffold under Notifications, Keys and Settings.
///
/// The three tabs are built on different containers — the Inbox is a `List`, for
/// its swipe actions and pull-to-refresh, and the other two are `ScrollView`s —
/// and every piece of shared geometry used to be written out once per screen.
/// They drifted twice over. Keys and Settings capped their column at
/// `Theme.measure` and centred it while the Inbox ran the full width of the
/// window, so on an iPad the three titles sat 107pt apart horizontally; and the
/// Inbox held its header outside its scroll view while the other two kept theirs
/// inside one, which put its title 10pt higher than the others.
///
/// So the header is pinned here for all three, in the same structural place, and
/// the only thing a screen chooses is whether its content brings a scroll
/// container of its own. The titles line up by construction rather than by two
/// numbers being kept equal.
///
/// Everything that decides *where* content lands is held here. What stays with a
/// screen is what only that screen has: its rows, and the Inbox's search field.
struct GeistPage<Header: View, Content: View>: View {
    /// Whether `content` is already a scroll container.
    ///
    /// The Inbox's `List` is one and has to stay one — that is what buys it swipe
    /// actions and pull-to-refresh. Keys and Settings hand over plain stacks and
    /// get wrapped in a `ScrollView` here, so the header above them is the same
    /// header in the same place either way.
    enum Scroll {
        /// The content is its own scroll container.
        case content
        /// The content is a plain stack and this page supplies the scroll view.
        case page
    }

    var scroll: Scroll = .page
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Hidden wherever it would be empty: the screen's own header already holds
    /// the title and its controls, so the bar would only add a strip above them.
    ///
    /// Shown on a regular width, where the Inbox puts its search field in it —
    /// and shown on all three tabs rather than only that one, because the bar
    /// carries a safe-area inset whether or not it draws anything. Hiding it on
    /// the two tabs without a field is what put their titles 10pt below the
    /// Inbox's on an iPad.
    private var navigationBar: Visibility {
        sizeClass == .regular ? .automatic : .hidden
    }
    #endif

    var body: some View {
        VStack(spacing: 0) {
            header()
                .geistPageHeader()
                // The gutter is applied to the header and not to the content,
                // because the content blocks carry their own: that is what lets
                // the rules between rows run the full width of the column while
                // the text they separate stays inside the margin.
                .geistGutter()
                // Measured before the backing goes on, so the title lands on the
                // column's edge while the ground and the rule below still run the
                // full width of the window — they are the screen's chrome, not
                // part of the column.
                .geistMeasure()
                // The static runs under the header too. It stays opaque — rows
                // have to disappear behind it rather than showing through — but a
                // flat ground here left a smooth band across the top of an
                // otherwise grainy screen.
                .background(StaticField())
                .overlay(alignment: .bottom) {
                    // iOS only. The popover's own frame already bounds the top of
                    // the Mac screen a few points up; a full-strength rule here
                    // read as a second border rather than as the app's chrome.
                    #if os(iOS)
                    Hairline(color: Theme.chromeRuleColor, weight: Theme.chromeRule)
                    #endif
                }

            scrollingContent
                .geistMeasure()
        }
        // The ground is painted here rather than inherited: the TabView and the
        // List underneath both draw an opaque backdrop of their own, so a
        // background set once at the root never reaches the screen.
        .background(StaticField())
        #if os(iOS)
        .toolbar(navigationBar, for: .navigationBar)
        #endif
    }

    @ViewBuilder
    private var scrollingContent: some View {
        switch scroll {
        case .content:
            // The scroll container is the caller's, and so are the content
            // margins that hold the fades open — a `List`'s insets can only be
            // set on the list itself. See `MessageFeed`. The stack is still
            // needed: a screen can put a banner above its feed, and the Inbox
            // does when the socket is down.
            VStack(spacing: 0) { content() }
        case .page:
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content() }
            }
            .scrollContentBackground(.hidden)
            // Room under the pinned header for the fade that dissolves rows as
            // they pass beneath it, and under the last row for the tab bar to
            // float over. The same two margins `MessageFeed` sets on its list,
            // for the same reasons, because these screens now scroll under the
            // same header it does.
            .contentMargins(.top, Theme.topFade, for: .scrollContent)
            .contentMargins(.bottom, Theme.bottomFade, for: .scrollContent)
            .geistTopFade()
            .geistBottomFade()
        }
    }
}
