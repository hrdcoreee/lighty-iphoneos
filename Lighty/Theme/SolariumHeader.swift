import SwiftUI

/// Large title area of a screen, matching the Android `scanSubtitle` block but
/// rendered as the top card of the glass stack.
///
/// The accessory is a generic view rather than `AnyView`, so it keeps its own
/// type and animation identity (for example the scan spinner does not get
/// re-created on every body evaluation).
struct SolariumHeader<Accessory: View>: View {

    let title: String
    let subtitle: String?
    private let accessory: Accessory

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            accessory
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

extension SolariumHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}