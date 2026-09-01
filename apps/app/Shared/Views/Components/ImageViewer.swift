import SwiftUI

struct ImageViewer: View {
    let url: URL
    var saveState: ImageSaveState = .idle
    var onDownload: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var zoom: CGFloat = 1
    @State private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragged: CGSize = .zero
    @State private var pinched: CGSize = .zero
    @State private var fitted: CGSize = .zero

    private static let maxZoom: CGFloat = 8

    private static let tapZoom: CGFloat = 3

    private static let decelerationRate: CGFloat = 0.998

    private static let resistance: CGFloat = 0.55

    private var scale: CGFloat { min(max(zoom * pinch, 1), Self.maxZoom) }

    private var settle: Animation { reduceMotion ? Theme.state : Theme.settle }

    private var translation: CGSize {
        CGSize(width: offset.width + dragged.width + pinched.width,
               height: offset.height + dragged.height + pinched.height)
    }

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
                            .onGeometryChange(for: CGSize.self) { $0.size } action: { fitted = $0 }
                            .scaleEffect(scale)
                            .offset(x: translation.width, y: translation.height)
                            .gesture(SimultaneousGesture(pan(in: proxy.size), magnify(in: proxy.size)))
                            .onTapGesture(count: 2) { location in
                                toggleZoom(at: location, in: proxy.size)
                            }
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
        .overlay(alignment: .topTrailing) { downloadControl }
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

    @ViewBuilder
    private var downloadControl: some View {
        if let onDownload {
            VStack(alignment: .trailing, spacing: 8) {
                Button(action: onDownload) {
                    downloadGlyph
                        .frame(width: 34, height: 34)
                        .background(Theme.surface.opacity(0.85), in: Circle())
                        .overlay(Circle().stroke(Theme.controlBorder, lineWidth: 1))
                        .geistHitArea(expandedBy: 5)
                }
                .buttonStyle(.geist)
                .disabled(saveState == .saving)
                .accessibilityLabel(saveStatus?.text ?? Copy.Message.downloadImage)

                if let status = saveStatus {
                    Text(status.text)
                        .font(Theme.metaSmall)
                        .foregroundStyle(status.tint)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 9)
                        .background(Theme.surface.opacity(0.85),
                                    in: RoundedRectangle(cornerRadius: 6))
                        .transition(.opacity)
                }
            }
            .animation(Theme.state, value: saveState)
            .padding(.trailing, Theme.gutter)
            .padding(.top, 12)
        }
    }

    private var saveStatus: (text: String, tint: Color)? {
        switch saveState {
        case .idle: return nil
        case .saving: return (Copy.Message.savingImage, Theme.muted)
        case .saved(let text): return (text, Theme.fg)
        case .failed(let text): return (text, Theme.danger)
        }
    }

    @ViewBuilder
    private var downloadGlyph: some View {
        switch saveState {
        case .saving:
            ProgressView().controlSize(.small).tint(Theme.dim)
        case .saved:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.fg)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.danger)
        case .idle:
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.fg)
        }
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
                dragged = resisted(value.translation, in: size)
            }
            .onEnded { value in
                guard scale > 1 else { return }
                let released = CGSize(width: offset.width + dragged.width,
                                      height: offset.height + dragged.height)
                let projected = CGSize(
                    width: released.width + Self.project(value.velocity.width),
                    height: released.height + Self.project(value.velocity.height)
                )
                withAnimation(settle) {
                    dragged = .zero
                    offset = clamp(projected, in: size)
                }
            }
    }

    private func magnify(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let previous = scale
                pinch = value.magnification
                let anchor = anchorPoint(value.startAnchor)
                pinched = CGSize(width: pinched.width + anchor.x * (previous - scale),
                                 height: pinched.height + anchor.y * (previous - scale))
            }
            .onEnded { _ in
                let settled = scale
                let combined = CGSize(width: offset.width + pinched.width,
                                      height: offset.height + pinched.height)
                zoom = settled
                pinch = 1
                withAnimation(settle) {
                    pinched = .zero
                    if settled <= 1 { reset() } else { offset = clamp(combined, in: size) }
                }
            }
    }

    private func toggleZoom(at location: CGPoint, in size: CGSize) {
        withAnimation(settle) {
            if scale > 1 {
                reset()
            } else {
                let anchor = CGPoint(x: location.x - fitted.width / 2,
                                     y: location.y - fitted.height / 2)
                zoom = Self.tapZoom
                offset = clamp(CGSize(width: anchor.x * (1 - Self.tapZoom),
                                      height: anchor.y * (1 - Self.tapZoom)), in: size)
            }
        }
    }

    private func anchorPoint(_ unit: UnitPoint) -> CGPoint {
        CGPoint(x: (unit.x - 0.5) * fitted.width, y: (unit.y - 0.5) * fitted.height)
    }

    private func limits(in size: CGSize) -> CGSize {
        CGSize(width: max(0, (fitted.width * scale - size.width) / 2),
               height: max(0, (fitted.height * scale - size.height) / 2))
    }

    private func clamp(_ proposed: CGSize, in size: CGSize) -> CGSize {
        let limit = limits(in: size)
        return CGSize(width: min(max(proposed.width, -limit.width), limit.width),
                      height: min(max(proposed.height, -limit.height), limit.height))
    }

    private func resisted(_ translation: CGSize, in size: CGSize) -> CGSize {
        let limit = limits(in: size)
        return CGSize(
            width: Self.resist(translation.width, from: offset.width,
                               limit: limit.width, dimension: size.width),
            height: Self.resist(translation.height, from: offset.height,
                                limit: limit.height, dimension: size.height)
        )
    }

    private static func resist(_ translation: CGFloat, from origin: CGFloat,
                               limit: CGFloat, dimension: CGFloat) -> CGFloat {
        let proposed = origin + translation
        let bounded = min(max(proposed, -limit), limit)
        let overshoot = proposed - bounded
        guard overshoot != 0 else { return translation }
        let damped = (overshoot * dimension * resistance)
            / (dimension + resistance * abs(overshoot))
        return bounded + damped - origin
    }

    private static func project(_ velocity: CGFloat) -> CGFloat {
        (velocity / 1000) * decelerationRate / (1 - decelerationRate)
    }

    private func reset() {
        zoom = 1
        pinch = 1
        offset = .zero
        dragged = .zero
        pinched = .zero
    }
}
