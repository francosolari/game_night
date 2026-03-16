import Foundation

enum JSONTestHelpers {
    static func makeEventDecoder() -> JSONDecoder {
        let iso8601WithFractionalSeconds = ISO8601DateFormatter()
        iso8601WithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let iso8601WithoutFractionalSeconds = ISO8601DateFormatter()
        iso8601WithoutFractionalSeconds.formatOptions = [.withInternetDateTime]

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .iso8601)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = iso8601WithFractionalSeconds.date(from: value)
                ?? iso8601WithoutFractionalSeconds.date(from: value)
                ?? dayFormatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(value)"
            )
        }
        return decoder
    }

    static func makeJSONData(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }
}
