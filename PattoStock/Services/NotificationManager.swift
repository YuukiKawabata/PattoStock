import Foundation
import UserNotifications

@Observable
final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()

    var isAuthorized = false
    var weeklyReminderDay: Int = 1 // 1=Sunday, 2=Monday, ...
    var weeklyReminderEnabled = false {
        didSet {
            if weeklyReminderEnabled {
                scheduleWeeklyReminder()
            } else {
                cancelWeeklyReminder()
            }
        }
    }

    private let center = UNUserNotificationCenter.current()
    private let weeklyReminderIdentifier = "weekly-shopping-reminder"

    private init() {
        Task { await checkAuthorizationStatus() }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run { self.isAuthorized = granted }
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
        await MainActor.run { self.isAuthorized = authorized }
    }

    func sendLowStockNotification(for item: InventoryItem) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = item.status == .outOfStock ? "在庫切れ" : "残りわずか"
        content.body = "\(item.name)の在庫が\(item.currentCount)個になりました"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "low-stock-\(item.id ?? UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func scheduleWeeklyReminder() {
        cancelWeeklyReminder()
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "買い物リマインダー"
        content.body = "在庫を確認して買い物リストをチェックしましょう"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = weeklyReminderDay
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: weeklyReminderIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelWeeklyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [weeklyReminderIdentifier])
    }

    func updateReminderDay(_ day: Int) {
        weeklyReminderDay = day
        if weeklyReminderEnabled {
            scheduleWeeklyReminder()
        }
    }
}
