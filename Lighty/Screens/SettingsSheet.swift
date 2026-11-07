import SwiftUI

/// Settings form, presented inside its own `NavigationStack` from `RootView`.
struct SettingsSheet: View {
    @EnvironmentObject private var controller: LightyController
    @Environment(\.dismiss) private var dismiss

    let strings: Strings

    var body: some View {
        ZStack {
            SolariumBackground()

            ScrollView {
                VStack(spacing: SolariumTheme.cardSpacing) {
                    deviceCard
                    filterCard
                    diagnosticsCard
                    aboutCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(strings.settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(strings.done) { dismiss() }
            }
        }
    }

    private var deviceCard: some View {
        SolariumCard(strings.deviceSection) {
            if let bound = controller.boundDevice {
                VStack(alignment: .leading, spacing: 10) {
                    Text(bound.name ?? bound.id.uuidString)
                        .font(.body)
                    Text(strings.unbindDesc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        controller.unbind()
                        dismiss()
                    } label: {
                        Label(strings.unbind, systemImage: "xmark.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Text(strings.noStripBound)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filterCard: some View {
        SolariumCard {
            Toggle(isOn: Binding(
                get: { controller.showAllDevices },
                set: { controller.showAllDevices = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(strings.showAllDevices).font(.subheadline)
                    Text(strings.showAllDevicesDesc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var diagnosticsCard: some View {
        SolariumCard {
            VStack(spacing: 0) {
                NavigationLink {
                    DiagnosticsScreen(strings: strings)
                } label: {
                    settingsLinkRow(
                        title: strings.diagnosticsTitle,
                        systemImage: "waveform.path.ecg"
                    )
                }
                .buttonStyle(.plain)

                Divider().opacity(0.3)

                // Development surface: tunes the private-backdrop mesh on the
                // device, where the effect can actually be judged.
                NavigationLink {
                    SolariumLabScreen()
                } label: {
                    settingsLinkRow(title: "Solarium Lab", systemImage: "circle.hexagongrid")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func settingsLinkRow(title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var aboutCard: some View {
        SolariumCard(strings.aboutSection) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(strings.versionLabel)
                    Spacer()
                    Text(AppInfo.version).foregroundStyle(.secondary)
                }
                .font(.subheadline)
                Text(strings.aboutDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
