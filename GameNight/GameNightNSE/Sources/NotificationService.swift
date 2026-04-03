import UserNotifications

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

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
