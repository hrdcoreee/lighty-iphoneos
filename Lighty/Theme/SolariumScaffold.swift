import SwiftUI

/// Screen container for the solarium look: scrolling glass cards.
///
/// The ambient background is owned by `RootView` (and by the settings sheet),
/// not by each screen, so the wash does not restart when the flow crossfades
/// from pairing to control.
///
/// A `List` is deliberately not used: its row backgrounds, separators and
/// insets fight the material, and it installs hit testing that made a bottom
/// shield necessary.
struct SolariumScaffold<Content: View>: View {

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SolariumTheme.cardSpacing) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            // Leave room for the home indicator so the last card can be
            // scrolled fully clear of it.
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(.clear)
        // The navigation bar sits over the wash; an opaque bar would cut a
        // hard rectangle through it.
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

/// A titled group of content, drawn as one glass card.
struct SolariumCard<Content: View>: View {

    let title: String?
    let tint: Color?
    private let content: Content

    init(_ title: String? = nil, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            content
        }
        .padding(SolariumTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(tint: tint)
    }
}
