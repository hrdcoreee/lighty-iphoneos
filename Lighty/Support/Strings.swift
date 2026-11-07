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

    var powerLabel: String
    var brightnessLabel: String
    var quickColors: String
    var customColor: String

    var diagnosticsTitle: String
    var diagnosticsEmpty: String
    var copyDiagnostics: String
    var clearLog: String
    var showAllDevices: String
    var showAllDevicesDesc: String

    var settingsTitle: String
    var done: String
    var deviceSection: String
    var unbind: String
    var unbindDesc: String
    var noStripBound: String
    var aboutSection: String
    var versionLabel: String
    var aboutDescription: String

    var languageSection: String
    var languageAuto: String
    var languageRussian: String
    var languageEnglish: String

    static let english = Strings(
        scanTitle: "Lighty",
        scanSubtitle: "Find your light strip",
        scan: "Scan",
        stopScan: "Stop",
        searching: "Searching for devices...",
        readyToScan: "Ready to scan",
        unknownDevice: "Unknown device",
        devicesFound: { "\($0) device(s) found" },
        bluetoothOffTitle: "Bluetooth is off",
        bluetoothOffBody: "Turn on Bluetooth in Settings to find your LED strip.",
        controlTitle: "Control",
        connected: "Connected",
        connecting: "Connecting...",
        offline: "Offline",
        powerLabel: "Power",
        brightnessLabel: "Brightness",
        quickColors: "Quick colors",
        customColor: "Custom color",
        diagnosticsTitle: "Diagnostics",
        diagnosticsEmpty: "No log entries yet.",
        copyDiagnostics: "Copy log",
        clearLog: "Clear",
        showAllDevices: "Show all Bluetooth devices",
        showAllDevicesDesc: "Scan for any BLE device, not only strip controllers",
        settingsTitle: "Settings",
        done: "Done",
        deviceSection: "Strip",
        unbind: "Unbind",
        unbindDesc: "Unbind and choose another strip",
        noStripBound: "No strip paired yet",
        aboutSection: "About",
        versionLabel: "Version",
        aboutDescription: "Bluetooth LED strip control",
        languageSection: "Language",
        languageAuto: "System (Auto)",
        languageRussian: "Русский",
        languageEnglish: "English"
    )

    static let russian = Strings(
        scanTitle: "Lighty",
        scanSubtitle: "Найдите вашу подсветку",
        scan: "Поиск",
        stopScan: "Остановить",
        searching: "Идёт поиск устройств...",
        readyToScan: "Готово к поиску",
        unknownDevice: "Неизвестное устройство",
        devicesFound: { "Найдено устройств: \($0)" },
        bluetoothOffTitle: "Bluetooth выключен",
        bluetoothOffBody: "Включите Bluetooth в настройках, чтобы найти ленту.",
        controlTitle: "Управление",
        connected: "Подключено",
        connecting: "Подключение...",
        offline: "Не в сети",
        powerLabel: "Питание",
        brightnessLabel: "Яркость",
        quickColors: "Быстрые цвета",
        customColor: "Свой цвет",
        diagnosticsTitle: "Диагностика",
        diagnosticsEmpty: "Записей пока нет.",
        copyDiagnostics: "Копировать лог",
        clearLog: "Очистить",
        showAllDevices: "Показывать все Bluetooth-устройства",
        showAllDevicesDesc: "Искать любые BLE-устройства, а не только контроллеры ленты",
        settingsTitle: "Настройки",
        done: "Готово",
        deviceSection: "Лента",
        unbind: "Отвязать",
        unbindDesc: "Отвязать и выбрать другую ленту",
        noStripBound: "Лента ещё не сопряжена",
        aboutSection: "О приложении",
        versionLabel: "Версия",
        aboutDescription: "Управление LED-лентой по Bluetooth",
        languageSection: "Язык",
        languageAuto: "Системный (авто)",
        languageRussian: "Русский",
        languageEnglish: "English"
    )

    static func current(for code: String) -> Strings {
        switch code {
        case "ru":
            return .russian
        case "en":
            return .english
        default:
            return Locale.isRussian ? .russian : .english
        }
    }
}

extension Locale {
    /// Checks whether Russian is the preferred language on the device.
    static var isRussian: Bool {
        for lang in Locale.preferredLanguages {
            let lower = lang.lowercased()
            if lower.hasPrefix("ru") {
                return true
            }
            if lower.hasPrefix("en") {
                return false
            }
        }
        if let code = Locale.current.language.languageCode?.identifier?.lowercased(), code == "ru" {
            return true
        }
        if Locale.current.identifier.lowercased().hasPrefix("ru") {
            return true
        }
        return false
    }

    /// Picks Russian for Russian system locales, otherwise English.
    static var lightyStrings: Strings {
        isRussian ? .russian : .english
    }
}
