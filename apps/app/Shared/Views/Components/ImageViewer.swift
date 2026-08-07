import SwiftUI

/// An attached image, on its own, with nothing else on the screen.
///
/// The detail page shows the image at the width of the reading column, which is
/// the right size for reading past it and the wrong size for looking at it —
/// most of what gets attached to a notification is a chart or a screenshot, and
/// those carry the point in text small enough that the column-width version is
/// unreadable. This is where you go to read it.
///
/// Pure black ground, unlike the detail page it opens from: the haze there is a
/// property of the message, and a coloured ground under someone else's image
/// changes what the image looks like.
struct ImageViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    /// Committed zoom, and the live pinch on top of it. Held apart so a pinch
    /// that starts on an already-zoomed image continues from where it was
    /// instead of snapping back to 1.
    @State private var zoom: CGFloat = 1
    @State private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragged: CGSize = .zero

    /// Below 8 a dense screenshot still cannot be read on a phone, and there is
    /// no cost to allowing it — the image simply gets soft, which is a fact
    /// about the image the reader is entitled to see.
    private static let maxZoom: CGFloat = 8

    /// What a double tap goes to. Not the maximum: a double tap is a request to
    /// see more, and landing at the far end leaves nowhere to go and everything
    /// off screen.
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
        // The zoom is a way of looking, not a setting. Reopening the same image
        // starts fitted, which is also what the reader is expecting to see.
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
                // Black on black would vanish against a dark photograph, and
                // white on white against a light one. A surface fill with the
                // control border holds against both.
                .background(Theme.surface.opacity(0.85), in: Circle())
                .overlay(Circle().stroke(Theme.controlBorder, lineWidth: 1))
                .geistHitArea(expandedBy: 5)
        }
        .buttonStyle(.geist)
        .accessibilityLabel(Copy.Common.close)
        .padding(.leading, Theme.gutter)
        .padding(.top, 12)
    }

    /// Panning is only offered once there is something off screen to pan to.
    /// A drag at fit size would otherwise slide the image around inside a frame
    /// it already fits in, which reads as the view coming loose.
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
                // Zooming back out can leave the image parked off centre with
                // nothing under the finger to bring it back, so the clamp runs
                // on zoom as well as on pan.
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

    /// Keeps the image's own edges from travelling inside the frame.
    ///
    /// Approximate on purpose: it bounds by the frame rather than by the
    /// image's laid-out size, which `scaledToFit` does not report. The error is
    /// in the generous direction — a little more travel than strictly needed —
    /// which is invisible in use, where the alternative is arithmetic that
    /// pretends to a precision it does not have.
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
