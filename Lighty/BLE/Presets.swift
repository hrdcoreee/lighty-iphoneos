import Foundation

/// Preset swatches, matching the palette of the Android `ControlScreen`.
enum Presets {

    static let palette: [HSVColor] = [
        HSVColor(hue: 0, saturation: 1, brightness: 1),      // red
        HSVColor(hue: 30, saturation: 1, brightness: 1),     // orange
        HSVColor(hue: 52, saturation: 1, brightness: 1),     // yellow
        HSVColor(hue: 120, saturation: 1, brightness: 1),    // green
        HSVColor(hue: 184, saturation: 1, brightness: 1),    // cyan
        HSVColor(hue: 216, saturation: 1, brightness: 1),    // blue
        HSVColor(hue: 272, saturation: 1, brightness: 1),    // violet
        HSVColor(hue: 306, saturation: 1, brightness: 1),    // magenta
        HSVColor(hue: 332, saturation: 0.7, brightness: 1),  // pink
        HSVColor(hue: 0, saturation: 0, brightness: 1),      // white
        HSVColor(hue: 32, saturation: 0.37, brightness: 1),  // warm white
    ]
}
