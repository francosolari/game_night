import Foundation

struct EventLocationPresentation {
    let title: String
    let subtitle: String?
    let fullAddress: String?

    init(locationName: String?, locationAddress: String?, canViewFullAddress: Bool) {
        let trimmedName = locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parsedAddress = ParsedEventAddress(address: locationAddress)

        if canViewFullAddress {
            fullAddress = parsedAddress.fullAddress
            if !trimmedName.isEmpty {
                title = trimmedName
                subtitle = parsedAddress.fullAddress
            } else if let streetLine = parsedAddress.streetLine, let cityState = parsedAddress.cityState {
                title = streetLine
                subtitle = cityState
            } else {
                title = parsedAddress.cityState ?? parsedAddress.fullAddress ?? "Location"
                subtitle = nil
            }
            return
        }

        fullAddress = nil
        if !trimmedName.isEmpty {
            title = trimmedName
            subtitle = parsedAddress.cityState
        } else {
            title = parsedAddress.cityState ?? "Approximate location"
            subtitle = nil
        }
    }

    var mapsURL: URL? {
        guard let fullAddress,
              let encodedAddress = fullAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return nil
        }

        return URL(string: "http://maps.apple.com/?q=\(encodedAddress)")
    }
}

private struct ParsedEventAddress {
    let fullAddress: String?
    let streetLine: String?
    let cityState: String?

    init(address: String?) {
        let trimmed = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            fullAddress = nil
            streetLine = nil
            cityState = nil
            return
        }

        fullAddress = trimmed

        let parts = trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count >= 3 {
            streetLine = parts.dropLast(2).joined(separator: ", ")
            cityState = parts.suffix(2).joined(separator: ", ")
        } else if parts.count == 2 {
            streetLine = parts[0]
            cityState = parts[1]
        } else {
            streetLine = parts.first
            cityState = nil
        }
    }
}
