import Foundation

/// User-facing strings. Kept in code rather than a string catalogue so the
/// initial POC has a single source of truth mirroring the Android `Strings`.
struct Strings {
    var scanTitle: String
    var scanSubtitle: String
    var scan: String
    var stopScan: String
    var searching: String
    var readyToScan: String
    var unknownDevice: String
    var devicesFound: (Int) -> String
    var bluetoothOffTitle: String
    var bluetoothOffBody: String

    var controlTitle: String
    var connected: String
    var connecting: String
    var offline: String
    var disconnect: String

    var powerLabel: String
    var brightnessLabel: String
    var quickColors: String
    var customColor: String

    var diagnosticsTitle: String
    var diagnosticsEmpty: String
    var copyDiagnostics: String
    var clearLog: String
    var showAllDevices: String

    static let english = Strings(
        scanTitle: "Lighty",
        scanSubtitle: "Connect your ELK-BLEDOM LED strip",
        scan: "Scan",
        stopScan: "Stop",
        searching: "Searching for controllers...",
        readyToScan: "Tap Scan to look for nearby controllers",
        unknownDevice: "Unknown device",
        devicesFound: { "\($0) device(s) found" },
        bluetoothOffTitle: "Bluetooth is off",
        bluetoothOffBody: "Turn on Bluetooth in Settings to find your LED strip.",
        controlTitle: "Control",
        connected: "Connected",
        connecting: "Connecting...",
        offline: "Offline",
        disconnect: "Disconnect",
        powerLabel: "Power",
        brightnessLabel: "Brightness",
        quickColors: "Quick colors",
        customColor: "Custom color",
        diagnosticsTitle: "Diagnostics",
        diagnosticsEmpty: "No log entries yet.",
        copyDiagnostics: "Copy log",
        clearLog: "Clear",
        showAllDevices: "Show all Bluetooth devices"
    )

    static let russian = Strings(
        scanTitle: "Lighty",
        scanSubtitle: "Подключите LED-ленту ELK-BLEDOM",
        scan: "Поиск",
        stopScan: "Стоп",
        searching: "Поиск контроллеров...",
        readyToScan: "Нажмите «Поиск», чтобы найти контроллеры рядом",
        unknownDevice: "Неизвестное устройство",
        devicesFound: { "Найдено устройств: \($0)" },
        bluetoothOffTitle: "Bluetooth выключен",
        bluetoothOffBody: "Включите Bluetooth в настройках, чтобы найти ленту.",
        controlTitle: "Управление",
        connected: "Подключено",
        connecting: "Подключение...",
        offline: "Не в сети",
        disconnect: "Отключить",
        powerLabel: "Питание",
        brightnessLabel: "Яркость",
        quickColors: "Быстрые цвета",
        customColor: "Свой цвет",
        diagnosticsTitle: "Диагностика",
        diagnosticsEmpty: "Записей пока нет.",
        copyDiagnostics: "Копировать лог",
        clearLog: "Очистить",
        showAllDevices: "Показывать все Bluetooth-устройства"
    )
}

extension Locale {
    /// Picks Russian for Russian system locales, otherwise English.
    static var lightyStrings: Strings {
        Locale.current.language.languageCode?.identifier == "ru" ? .russian : .english
    }
}
