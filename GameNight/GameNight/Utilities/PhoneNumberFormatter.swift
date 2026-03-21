import Foundation

/// Centralized phone number formatting and normalization.
/// Goal: prevent duplicates and provide consistent display format.
enum PhoneNumberFormatter {
    /// Normalizes phone to digits-only for comparison (e.g., "19543482945").
    /// This is the canonical format for checking uniqueness.
    static func normalizedForComparison(_ phoneNumber: String) -> String {
        phoneNumber.filter(\.isNumber)
    }

    /// Formats phone for display, hiding country code for local numbers.
    /// For US: "+19543482945" → "954-348-2945" (hides +1, shows area-exchange-number)
    /// For other regions: Falls back to digits-only for now.
    static func formatForDisplay(_ phoneNumber: String, countryCode: String = "+1") -> String {
        let digits = normalizedForComparison(phoneNumber)

        // US number with country code prefix
        if countryCode == "+1" && digits.count == 11 && digits.hasPrefix("1") {
            let areaCode = String(digits.dropFirst().prefix(3))
            let exchange = String(digits.dropFirst(4).prefix(3))
            let subscriber = String(digits.dropFirst(7))
            return "(\(areaCode)) \(exchange)-\(subscriber)"
        }

        // 10-digit US number (already local format)
        if countryCode == "+1" && digits.count == 10 {
            let areaCode = String(digits.prefix(3))
            let exchange = String(digits.dropFirst(3).prefix(3))
            let subscriber = String(digits.dropFirst(6))
            return "(\(areaCode)) \(exchange)-\(subscriber)"
        }

        // For other formats/regions, show digits only
        return digits
    }

    /// Normalizes raw input to E.164 format (with +).
    /// Used when storing/syncing to backend.
    static func normalizeToE164(_ phoneNumber: String) -> String {
        let digits = phoneNumber.filter(\.isNumber)

        if digits.isEmpty {
            return ""
        }

        // 10-digit US (add +1)
        if digits.count == 10 {
            return "+1\(digits)"
        }

        // 11-digit starting with 1 (US with leading 1)
        if digits.count == 11 && digits.hasPrefix("1") {
            return "+\(digits)"
        }

        // Already has content, assume international
        return "+\(digits)"
    }
}
