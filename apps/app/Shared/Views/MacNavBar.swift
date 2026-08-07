#if os(macOS)
import SwiftUI

/// The popover has no window chrome, so `.toolbar` never renders inside it.
/// Pushed pages draw this bar instead.
struct MacNavBar<Trailing: View>: View {
    private let backTitle: String
    private let trailing: Trailing

    @Environment(\.dismiss) private var dismiss

    init(backTitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.backTitle = backTitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Label(backTitle, systemImage: "chevron.backward")
                    .font(.inco(.subheadline, weight: .medium))
            }
            .buttonStyle(.geist)
            .accessibilityLabel(Copy.Components.backTo(backTitle))

            Spacer(minLength: 0)

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

extension MacNavBar where Trailing == EmptyView {
    init(backTitle: String) {
        self.init(backTitle: backTitle) { EmptyView() }
    }
}
#endif
