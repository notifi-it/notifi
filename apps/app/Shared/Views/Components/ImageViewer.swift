import SwiftUI

struct ImageViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    @State private var zoom: CGFloat = 1
    @State private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragged: CGSize = .zero

    private static let maxZoom: CGFloat = 8

    private static let tapZoom: CGFloat = 3

    private var scale: CGFloat { min(max(zoom * pinch, 1), Self.maxZoom) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(x: offset.width + dragged.width,
                                    y: offset.height + dragged.height)
                            .gesture(pan(in: proxy.size))
                            .gesture(magnify(in: proxy.size))
                            .onTapGesture(count: 2) { toggleZoom(in: proxy.size) }
                    case .failure:
                        message(Copy.Message.imageFailedToLoad)
                    default:
                        ProgressView().tint(Theme.dim)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) { closeButton }
        .onDisappear { reset() }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 400)
        #endif
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(Theme.body)
            .foregroundStyle(Theme.dim)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.fg)
                .frame(width: 34, height: 34)
                .background(Theme.surface.opacity(0.85), in: Circle())
                .overlay(Circle().stroke(Theme.controlBorder, lineWidth: 1))
                .geistHitArea(expandedBy: 5)
        }
        .buttonStyle(.geist)
        .accessibilityLabel(Copy.Common.close)
        .padding(.leading, Theme.gutter)
        .padding(.top, 12)
    }

    private func pan(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                dragged = value.translation
            }
            .onEnded { _ in
                offset = clamp(CGSize(width: offset.width + dragged.width,
                                      height: offset.height + dragged.height),
                               in: size)
                dragged = .zero
            }
    }

    private func magnify(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in pinch = value.magnification }
            .onEnded { _ in
                zoom = scale
                pinch = 1
                withAnimation(Theme.state) {
                    if zoom <= 1 { reset() } else { offset = clamp(offset, in: size) }
                }
            }
    }

    private func toggleZoom(in size: CGSize) {
        withAnimation(Theme.state) {
            if scale > 1 {
                reset()
            } else {
                zoom = Self.tapZoom
            }
        }
    }

    private func clamp(_ proposed: CGSize, in size: CGSize) -> CGSize {
        let limitX = max(0, (size.width * scale - size.width) / 2)
        let limitY = max(0, (size.height * scale - size.height) / 2)
        return CGSize(width: min(max(proposed.width, -limitX), limitX),
                      height: min(max(proposed.height, -limitY), limitY))
    }

    private func reset() {
        zoom = 1
        pinch = 1
        offset = .zero
        dragged = .zero
    }
}
