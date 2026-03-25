import Cocoa
import SwiftUI
import UniformTypeIdentifiers
#if ENABLE_SPARKLE
import Sparkle
#endif

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var menuBarManager: MenuBarManager?
    weak var appSettings: AppSettingsStore?
    weak var whisperState: WhisperState?
    private var isTerminationCleanupInProgress = false
    
    #if ENABLE_SPARKLE
    private let automaticUpdateCheckDefaultsKey = "sparkle.lastAutomaticScheduledUpdateCheck"
    private let automaticUpdateCheckDelay: TimeInterval = 3
    private var automaticUpdateCheckTimer: Timer?
    private var workspaceWakeObserver: NSObjectProtocol?

    private lazy var updaterControllerString: SPUStandardUpdaterController = {
        return SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }()
    
    private var updaterController: SPUStandardUpdaterController {
        return updaterControllerString
    }
    #endif
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activation policy is now handled by SettingsCoordinator
        #if ENABLE_SPARKLE
        configureAutomaticUpdateChecks()
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        #if ENABLE_SPARKLE
        automaticUpdateCheckTimer?.invalidate()
        automaticUpdateCheckTimer = nil

        if let workspaceWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceWakeObserver)
            self.workspaceWakeObserver = nil
        }
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let appSettings = appSettings, !appSettings.isMenuBarOnly {
            if WindowManager.shared.showMainWindow() != nil {
                return false
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminationCleanupInProgress, let whisperState else {
            return .terminateNow
        }

        isTerminationCleanupInProgress = true

        Task { @MainActor [weak self] in
            await whisperState.shutdownForTermination()
            self?.isTerminationCleanupInProgress = false
            sender.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }
    
    #if ENABLE_SPARKLE
    @objc func checkForUpdates(_ sender: Any?) {
        print("AppDelegate: checkForUpdates called")
        NSApp.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(sender)
    }
    
    private func configureAutomaticUpdateChecks() {
        let updater = updaterController.updater
        updater.automaticallyChecksForUpdates = false

        performMissedAutomaticUpdateCheckIfNeeded()
        scheduleNextAutomaticUpdateCheck()
        observeSystemWakeForAutomaticUpdateChecks()
    }

    private func performMissedAutomaticUpdateCheckIfNeeded(referenceDate: Date = Date()) {
        guard let scheduledDate = mostRecentScheduledUpdateCheckDate(onOrBefore: referenceDate),
              shouldRunAutomaticUpdateCheck(for: scheduledDate) else {
            return
        }

        recordAutomaticUpdateCheck(for: scheduledDate)
        DispatchQueue.main.asyncAfter(deadline: .now() + automaticUpdateCheckDelay) { [weak self] in
            self?.updaterController.updater.checkForUpdatesInBackground()
        }
    }

    private func scheduleNextAutomaticUpdateCheck(referenceDate: Date = Date()) {
        automaticUpdateCheckTimer?.invalidate()

        guard let nextScheduledDate = nextScheduledUpdateCheckDate(after: referenceDate) else {
            return
        }

        let interval = max(nextScheduledDate.timeIntervalSinceNow, 1)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.runAutomaticUpdateCheck(for: nextScheduledDate)
            self?.scheduleNextAutomaticUpdateCheck(referenceDate: Date())
        }
        timer.tolerance = min(300, interval * 0.05)
        automaticUpdateCheckTimer = timer
    }

    private func runAutomaticUpdateCheck(for scheduledDate: Date) {
        guard shouldRunAutomaticUpdateCheck(for: scheduledDate) else {
            return
        }

        recordAutomaticUpdateCheck(for: scheduledDate)
        updaterController.updater.checkForUpdatesInBackground()
    }

    private func shouldRunAutomaticUpdateCheck(for scheduledDate: Date) -> Bool {
        guard let lastCheckDate = UserDefaults.standard.object(forKey: automaticUpdateCheckDefaultsKey) as? Date else {
            return true
        }

        return lastCheckDate < scheduledDate
    }

    private func recordAutomaticUpdateCheck(for scheduledDate: Date) {
        UserDefaults.standard.set(scheduledDate, forKey: automaticUpdateCheckDefaultsKey)
    }

    private func observeSystemWakeForAutomaticUpdateChecks() {
        if let workspaceWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceWakeObserver)
        }

        workspaceWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.performMissedAutomaticUpdateCheckIfNeeded()
            self?.scheduleNextAutomaticUpdateCheck(referenceDate: Date())
        }
    }

    private func nextScheduledUpdateCheckDate(after date: Date) -> Date? {
        var components = DateComponents()
        components.weekday = 2
        components.hour = 12
        components.minute = 0
        components.second = 0

        return localCalendar.nextDate(
            after: date,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func mostRecentScheduledUpdateCheckDate(onOrBefore date: Date) -> Date? {
        guard let scheduledDateForCurrentWeek = scheduledUpdateCheckDate(forWeekContaining: date) else {
            return nil
        }

        if scheduledDateForCurrentWeek <= date {
            return scheduledDateForCurrentWeek
        }

        return localCalendar.date(byAdding: .day, value: -7, to: scheduledDateForCurrentWeek)
    }

    private func scheduledUpdateCheckDate(forWeekContaining date: Date) -> Date? {
        let weekComponents = localCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        var components = DateComponents()
        components.yearForWeekOfYear = weekComponents.yearForWeekOfYear
        components.weekOfYear = weekComponents.weekOfYear
        components.weekday = 2
        components.hour = 12
        components.minute = 0
        components.second = 0

        return localCalendar.date(from: components)
    }

    private var localCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        return calendar
    }
    #endif
    
    // MARK: - SPUUpdaterDelegate
    
    // Delegate methods removed to avoid duplicate alerts.
    // SPUStandardUpdaterController handles UI including "No Update Found" and errors automatically.
}

#if ENABLE_SPARKLE
extension AppDelegate: SPUUpdaterDelegate {}
#endif
