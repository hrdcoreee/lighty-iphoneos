import SwiftUI

/// Settings overlay, mirroring the Android `SettingsScreen`: the bound strip
/// can be unbound here, the scan filter toggled, and the diagnostics log
/// reached. Presented as a sheet from either root screen.
struct SettingsSheet: View {
    @EnvironmentObject private var controller: LightyController
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_language") private var appLanguage: String = "auto"

    let strings: Strings

    var body: some View {
        NavigationStack {
            List {
                Section(strings.deviceSection) {
                    if let bound = controller.boundDevice {
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
                        }
                    } else {
                        Text(strings.noStripBound)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(strings.languageSection) {
                    Picker(strings.languageSection, selection: $appLanguage) {
                        Text(strings.languageAuto).tag("auto")
                        Text(strings.languageRussian).tag("ru")
                        Text(strings.languageEnglish).tag("en")
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Toggle(strings.showAllDevices, isOn: Binding(
                        get: { controller.showAllDevices },
                        set: { controller.showAllDevices = $0 }
                    ))
                } footer: {
                    Text(strings.showAllDevicesDesc)
                }

                Section {
                    NavigationLink {
                        DiagnosticsScreen(strings: strings)
                    } label: {
                        Label(strings.diagnosticsTitle, systemImage: "waveform.path.ecg")
                    }
                }

                Section(strings.aboutSection) {
                    LabeledContent(strings.versionLabel, value: AppInfo.version)
                    Text(strings.aboutDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(strings.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(strings.done) { dismiss() }
                }
            }
        }
    }
}
