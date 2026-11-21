import SwiftUI

struct GeistPage<Header: View, Content: View>: View {
    enum Scroll {
        case content
        case page
    }

    var scroll: Scroll = .page
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var navigationBar: Visibility {
        sizeClass == .regular ? .automatic : .hidden
    }
    #endif

    var body: some View {
        scrollingContent
            .modifier(TopBar { pageHeader })
            .background(StaticField())
            #if os(iOS)
            .toolbar(navigationBar, for: .navigationBar)
            #endif
    }

    private var pageHeader: some View {
        header()
            .geistPageHeader()
            .geistGutter()
            .geistMeasure()
    }

    @ViewBuilder
    private var scrollingContent: some View {
        switch scroll {
        case .content:
            VStack(spacing: 0) { content() }
        case .page:
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .geistMeasure()
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.top, Theme.contentTop, for: .scrollContent)
            #if os(macOS)
            .geistBottomPlate()
            #endif
        }
    }
}

private struct TopBar<Bar: View>: ViewModifier {
    @ViewBuilder var bar: () -> Bar

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.safeAreaBar(edge: .top, spacing: 0, content: bar)
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                bar().frame(maxWidth: .infinity).background(.bar)
            }
        }
    }
}
