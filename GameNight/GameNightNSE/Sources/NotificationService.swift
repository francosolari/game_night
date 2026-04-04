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
            let localizedTime = Self.localizedTimeString(
                fromUTCISO8601: userInfo["start_time_utc"] as? String,
                orParsedBody: content.body
            )
        else {
            return
        }

        content.body = Self.replacingTimeConfirmedBody(content.body, with: localizedTime)
    }

    private static func localizedTimeString(
        fromUTCISO8601 isoString: String?,
        orParsedBody body: String
    ) -> String? {
        if let isoString {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = formatter.date(from: isoString) ?? ISO8601DateFormatter().date(from: isoString)
            if let date {
                return localizedTimeString(from: date)
            }
        }

        return localizedTimeString(fromParsedBody: body)
    }

    private static func localizedTimeString(from date: Date) -> String? {
        let displayFormatter = DateFormatter()
        displayFormatter.locale = .current
        displayFormatter.timeZone = .current
        displayFormatter.dateFormat = "EEE, MMM d at h:mm a"
        return displayFormatter.string(from: date)
    }

    private static func localizedTimeString(fromParsedBody body: String) -> String? {
        let marker = " is locked in for "
        guard
            let range = body.range(of: marker),
            let endOfTime = body.lastIndex(of: ".")
        else {
            return nil
        }

        let timeString = String(body[range.upperBound..<endOfTime]).trimmingCharacters(in: .whitespacesAndNewlines)
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "EEE, MMM d at h:mm a zzz"
        guard let date = parser.date(from: timeString) else {
            return nil
        }

        return localizedTimeString(from: date)
    }

    private static func replacingTimeConfirmedBody(_ body: String, with localizedTime: String) -> String {
        let marker = " is locked in for "
        guard let range = body.range(of: marker) else {
            return body
        }

        let prefix = body[..<range.upperBound]
        let suffix = body[range.upperBound...]
        if suffix.hasSuffix(".") {
            return "\(prefix)\(localizedTime)."
        }
        return "\(prefix)\(localizedTime)"
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
