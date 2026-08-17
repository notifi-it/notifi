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
        VStack(spacing: 0) {
            header()
                .geistPageHeader()
                .geistGutter()
                .geistMeasure()
                .background(StaticField())

            scrollingContent
                .geistMeasure()
        }
        .background(StaticField())
        #if os(iOS)
        .toolbar(navigationBar, for: .navigationBar)
        #endif
    }

    @ViewBuilder
    private var scrollingContent: some View {
        switch scroll {
        case .content:
            VStack(spacing: 0) { content() }
        case .page:
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content() }
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.top, Theme.contentTop, for: .scrollContent)
            .contentMargins(.bottom, Theme.bottomPlate, for: .scrollContent)
            .geistTopFade()
            .geistBottomPlate()
        }
    }
}
