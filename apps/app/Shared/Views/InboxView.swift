import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum Grain {
    static let cgImage: CGImage? = {
        let filter = CIFilter.randomGenerator()
        guard let noise = filter.outputImage else { return nil }
        let mono = noise.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.4,
        ])
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
        let context = CIContext(options: nil)
        return context.createCGImage(mono, from: rect)
    }()

    @ViewBuilder
    static var view: some View {
        if let cgImage {
            Image(decorative: cgImage, scale: 3)
                .resizable(resizingMode: .tile)
        } else {
            Color.clear
        }
    }
}

private struct HashGradientBackground: View {
    let seed: String

    private func v(_ salt: Int) -> Double {
        var hash: UInt64 = 5381
        for byte in "\(salt).\(seed)".utf8 { hash = (hash &* 33) ^ UInt64(byte) }
        return Double(hash % 1000) / 1000.0
    }

    private var greys: [Color] {
        [Color.primary.opacity(0.16), Color.primary.opacity(0.0)]
    }

    @ViewBuilder
    var body: some View {
        if v(0) < 0.4 {
            RadialGradient(
                gradient: Gradient(colors: greys),
                center: UnitPoint(x: 0.2 + v(1) * 0.6, y: 0.2 + v(2) * 0.6),
                startRadius: 0,
                endRadius: 120 + v(3) * 180
            )
        } else {
            LinearGradient(
                colors: greys,
                startPoint: UnitPoint(x: v(1), y: v(2)),
                endPoint: UnitPoint(x: v(3), y: v(4))
            )
        }
    }
}

func brandHue(for text: String, salt: Int) -> Double {
    var hash: UInt64 = 5381
    for byte in "\(salt)-\(text)".utf8 { hash = (hash &* 33) ^ UInt64(byte) }
    return Double(hash % 1000) / 1000.0
}

private struct SourceAvatar: View {
    let name: String
    let unread: Bool

    private var letter: String {
        String(name.trimmingCharacters(in: .whitespaces).first ?? "•").uppercased()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: brandHue(for: name, salt: 1), saturation: 0.7, brightness: 0.85),
                        Color(hue: brandHue(for: name, salt: 2), saturation: 0.75, brightness: 0.6),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 38, height: 38)
            .overlay {
                Text(letter)
                    .font(.inco(.headline, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(alignment: .topTrailing) {
                if unread {
                    Circle()
                        .fill(Color(red: 0.737, green: 0.129, blue: 0.133))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                        .offset(x: 3, y: -3)
                }
            }
    }
}

struct InboxView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]

    @State private var searchText = ""
    @State private var filterKeyID: Int?
    #if os(iOS)
    @State private var showingCreate = false
    @State private var showingSettings = false
    #endif

    private var filtered: [Message] {
        messages.filter { message in
            let matchesKey = filterKeyID.map { message.keyID == $0 } ?? true
            let matchesSearch: Bool = {
                guard !searchText.isEmpty else { return true }
                let needle = searchText.lowercased()
                if message.title.lowercased().contains(needle) { return true }
                if let body = message.body?.lowercased(), body.contains(needle) { return true }
                return false
            }()
            return matchesKey && matchesSearch
        }
    }

    var body: some View {
        Group {
            if messages.isEmpty {
                EmptyStateView()
            } else {
                list
            }
        }
        .refreshable { await model.refresh() }
        .searchable(text: $searchText, prompt: "Search")
        #if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { menuButton }
            ToolbarItem(placement: .principal) { bellTitle }
        }
        .sheet(isPresented: $showingCreate) {
            NavigationStack { CreateKeyView() }.environment(model)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }.environment(model)
        }
        #else
        .safeAreaInset(edge: .top) { header }
        #endif
    }

    private var bellTitle: some View {
        Image("BellLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 52)
            .overlay {
                if unreadCount > 0 {
                    GeometryReader { geo in
                        Text(unreadBadgeText)
                            .font(.custom("Inconsolata", fixedSize: geo.size.height * 0.17).weight(.bold))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .frame(width: geo.size.width * 0.30)
                            .position(x: geo.size.width * 0.705, y: geo.size.height * 0.18)
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private var menuButton: some View {
        Menu {
            Button("Mark All as Read") { markAllRead() }
            if keys.count > 1 {
                Divider()
                Button {
                    filterKeyID = nil
                } label: {
                    if filterKeyID == nil {
                        Label("All keys", systemImage: "checkmark")
                    } else {
                        Text("All keys")
                    }
                }
                Divider()
                ForEach(keys) { key in
                    Button {
                        filterKeyID = key.id
                    } label: {
                        if filterKeyID == key.id {
                            Label(key.name, systemImage: "checkmark")
                        } else {
                            Text(key.name)
                        }
                    }
                }
            }
        } label: {
            Image("akar-more-horizontal")
                .foregroundStyle(filterKeyID == nil
                    ? Color.primary.opacity(0.6)
                    : Color(red: 0.737, green: 0.129, blue: 0.133))
        }
    }

    private var list: some View {
        List {
            ForEach(filtered, id: \.serverID) { message in
                Button {
                    model.path.append(message.serverID)
                } label: {
                    MessageRow(message: message, keyName: keyName(for: message))
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .swipeActions(edge: .leading) {
                    Button {
                        message.isRead.toggle()
                        try? context.save()
                        model.sync?.updateBadge()
                    } label: {
                        Label(
                            message.isRead ? "Unread" : "Read",
                            systemImage: message.isRead ? "envelope.badge.fill" : "envelope.open.fill"
                        )
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(message)
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
                .contextMenu {
                    Button(message.isRead ? "Mark as Unread" : "Mark as Read") {
                        message.isRead.toggle()
                        try? context.save()
                        model.sync?.updateBadge()
                    }
                    Divider()
                    Button("Copy Title") { Clipboard.copy(message.title) }
                    if let body = message.body {
                        Button("Copy Message") { Clipboard.copy(body) }
                    }
                    if let link = message.link {
                        Button("Open Link") {
                            #if os(iOS)
                            UIApplication.shared.open(link)
                            #else
                            NSWorkspace.shared.open(link)
                            #endif
                        }
                    }
                    Button("Delete", role: .destructive) { delete(message) }
                }
            }
        }
        .listStyle(.plain)
        #if os(macOS)
        .scrollContentBackground(.hidden)
        #endif
    }

    private var keys: [CachedKey] { model.sync?.keys ?? [] }

    private func keyName(for message: Message) -> String {
        guard let id = message.keyID, let name = keys.first(where: { $0.id == id })?.name else {
            return "default"
        }
        return name
    }

    private var unreadCount: Int {
        messages.reduce(0) { $0 + ($1.isRead ? 0 : 1) }
    }

    private var unreadBadgeText: String {
        unreadCount > 99 ? "99+" : "\(unreadCount)"
    }

    @ViewBuilder
    private func glassIcon(_ systemName: String) -> some View {
        let img = Image(systemName: systemName)
            .font(.body)
            .foregroundStyle(.primary)
            .frame(width: 32, height: 32)
        if #available(iOS 26.0, macOS 26.0, *) {
            img.glassEffect(in: Circle())
        } else {
            img.background(.regularMaterial, in: Circle())
        }
    }

    private var bellLogo: some View {
        Image("BellLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 44)
            .overlay {
                if unreadCount > 0 {
                    GeometryReader { geo in
                        Text(unreadBadgeText)
                            .font(.custom("Inconsolata", fixedSize: geo.size.height * 0.19).weight(.heavy))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .frame(width: geo.size.width * 0.30)
                            .position(x: geo.size.width * 0.705, y: geo.size.height * 0.18)
                    }
                    .allowsHitTesting(false)
                    .animation(.snappy, value: unreadCount)
                }
            }
    }

    private var header: some View {
        ZStack {
            bellLogo
            HStack(spacing: 0) {
                Menu {
                    Button("Mark All as Read") { markAllRead() }
                    if keys.count > 1 {
                        Picker("Filter by key", selection: $filterKeyID) {
                            Text("All keys").tag(Int?.none)
                            ForEach(keys) { key in
                                Text(key.name).tag(Int?.some(key.id))
                            }
                        }
                    }
                    #if os(macOS)
                    Divider()
                    Button("Create Key…") { model.presentingCreateKey = true }
                    #endif
                } label: {
                    glassIcon("ellipsis")
                }
                .menuIndicator(.hidden)
                #if os(macOS)
                .menuStyle(.borderlessButton)
                #endif
                .fixedSize()

                Spacer(minLength: 0)

                Button { openSettingsAction() } label: {
                    glassIcon("gearshape")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func openSettingsAction() {
        #if os(iOS)
        showingSettings = true
        #else
        model.path.append(AppRoute.settings)
        #endif
    }

    private func delete(_ message: Message) {
        context.delete(message)
        try? context.save()
        model.sync?.updateBadge()
    }

    private func markAllRead() {
        for message in messages where !message.isRead {
            message.isRead = true
        }
        try? context.save()
        model.sync?.updateBadge()
    }
}

private struct MeshBlurBackground: View {
    let seed: String

    private func value(_ salt: Int) -> Double {
        var hash: UInt64 = 5381
        for byte in "\(salt)-\(seed)".utf8 { hash = (hash &* 33) ^ UInt64(byte) }
        return Double(hash % 1000) / 1000.0
    }

    private func color(_ salt: Int) -> Color {
        Color(hue: value(salt), saturation: 0.7, brightness: 0.85)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let d = max(w, h) * 0.85
            ZStack {
                Circle().fill(color(1)).frame(width: d, height: d)
                    .position(x: w * 0.12, y: h * 0.15)
                Circle().fill(color(2)).frame(width: d, height: d)
                    .position(x: w * 0.9, y: h * 0.0)
                Circle().fill(color(3)).frame(width: d, height: d)
                    .position(x: w * 0.25, y: h * 1.0)
                Circle().fill(color(4)).frame(width: d, height: d)
                    .position(x: w * 0.95, y: h * 0.95)
            }
            .blur(radius: 45)
        }
    }
}

private struct CornerBrackets: Shape {
    var length: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l = length
        // top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // top-right
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // bottom-left
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

private struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let line = Path(CGRect(x: 0, y: y, width: size.width, height: 1))
                context.fill(line, with: .color(.primary.opacity(0.05)))
                y += 3
            }
        }
    }
}

private struct MessageRow: View {
    let message: Message
    let keyName: String
    @State private var hovering = false

    private var accent: Color { Color(red: 0.737, green: 0.129, blue: 0.133) }

    private var fillGradient: LinearGradient {
        if message.isRead {
            let top = hovering ? 0.12 : 0.07
            let bottom = hovering ? 0.04 : 0.015
            return LinearGradient(
                colors: [Color.primary.opacity(top), Color.primary.opacity(bottom)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            let flat = accent.opacity(hovering ? 0.18 : 0.12)
            return LinearGradient(colors: [flat, flat], startPoint: .top, endPoint: .bottom)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(message.title)
                            .font(.inco(.headline, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(message.createdAt, format: .relative(presentation: .numeric, unitsStyle: .wide))
                            .font(.inco(.caption))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    if let body = message.body {
                        Text(body)
                            .font(.karla(.subheadline))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        Text(keyName)
                            .font(.inco(.caption2))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                            .layoutPriority(1)
                        Text(message.createdAt, format: .verbatim(
                            "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)  \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
                            timeZone: .current,
                            calendar: .current
                        ))
                        .font(.inco(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                if let imageURL = message.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if case let .success(image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Rectangle().fill(.quaternary)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fillGradient)
                Grain.view
                    .blendMode(.overlay)
                    .opacity(0.28)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if !message.isRead { parts.append("Unread") }
        parts.append(message.title)
        if let body = message.body { parts.append(body) }
        return parts.joined(separator: ", ")
    }
}
