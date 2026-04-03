import UserNotifications

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private static let timeConfirmedPrefix = " is locked in for "

    // MARK: - UNNotificationServiceExtension

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler

        guard let mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        self.bestAttemptContent = mutableContent

        rewriteTimeConfirmedBodyIfNeeded(mutableContent, userInfo: request.content.userInfo)

        guard
            let imageURLString = request.content.userInfo["image_url"] as? String,
            let imageURL = URL(string: imageURLString)
        else {
            // No image URL in payload — deliver as-is (subtitle/body were set server-side)
            contentHandler(mutableContent)
            return
        }

        downloadImage(from: imageURL) { attachment in
            if let attachment {
                mutableContent.attachments = [attachment]
            }
            contentHandler(mutableContent)
        }
    }

    private func rewriteTimeConfirmedBodyIfNeeded(
        _ content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) {
        guard
            let notificationType = userInfo["notification_type"] as? String,
            notificationType == "time_confirmed",
            let startTimeUTC = userInfo["start_time_utc"] as? String,
            let localizedTime = Self.localizedTimeString(fromUTCISO8601: startTimeUTC)
        else {
            return
        }

        let existingBody = content.body

        if let range = existingBody.range(of: Self.timeConfirmedPrefix) {
            let prefix = existingBody[..<range.upperBound]
            let suffix = existingBody[range.upperBound...]
            if suffix.hasSuffix(".") {
                content.body = "\(prefix)\(localizedTime)."
            } else {
                content.body = "\(prefix)\(localizedTime)"
            }
            return
        }

        content.body = localizedTime
    }

    private static func localizedTimeString(fromUTCISO8601 isoString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: isoString) ?? ISO8601DateFormatter().date(from: isoString)
        guard let date else { return nil }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = .current
        displayFormatter.timeZone = .current
        displayFormatter.dateFormat = "EEE, MMM d at h:mm a"
        return displayFormatter.string(from: date)
    }

    override func serviceExtensionTimeWillExpire() {
        // iOS is reclaiming our ~30s time budget. Deliver best attempt without the image.
        if let handler = contentHandler, let content = bestAttemptContent {
            handler(content)
        }
    }

    // MARK: - Image Download

    private func downloadImage(
        from url: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            guard let tempURL, error == nil else {
                completion(nil)
                return
            }

            // UNNotificationAttachment requires a file extension the system recognizes.
            // Rename the temp file with the correct extension derived from MIME type.
            let ext = Self.fileExtension(for: response)
            let destURL = tempURL
                .deletingLastPathComponent()
                .appendingPathComponent(tempURL.lastPathComponent + ext)

            do {
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                let attachment = try UNNotificationAttachment(
                    identifier: "notification-image",
                    url: destURL,
                    options: nil
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }.resume()
    }

    private static func fileExtension(for response: URLResponse?) -> String {
        switch response?.mimeType {
        case "image/png":  return ".png"
        case "image/webp": return ".webp"
        case "image/gif":  return ".gif"
        default:           return ".jpg" // Safe fallback for BGG and Supabase Storage images
        }
    }
}
