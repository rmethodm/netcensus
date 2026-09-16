import UserNotifications

enum ScanNotifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func postCompletion(hostCount: Int, newCount: Int, highCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(AppBrand.displayName) finished"
        var parts = ["\(hostCount) hosts"]
        if newCount > 0 { parts.append("\(newCount) new") }
        if highCount > 0 { parts.append("\(highCount) high-severity findings") }
        content.body = parts.joined(separator: " · ")
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
