/**
 * Location presentation logic ported from iOS EventLocationPresentation.swift
 * Handles address parsing, visibility, and map link generation.
 */

interface ParsedAddress {
  fullAddress: string | null;
  streetLine: string | null;
  cityState: string | null;
}

function parseAddress(address: string | null | undefined): ParsedAddress {
  const trimmed = (address ?? "").trim();
  if (!trimmed) return { fullAddress: null, streetLine: null, cityState: null };

  const parts = trimmed
    .split(",")
    .map(p => p.trim())
    .filter(p => p.length > 0);

  if (parts.length >= 3) {
    return {
      fullAddress: trimmed,
      streetLine: parts.slice(0, -2).join(", "),
      cityState: parts.slice(-2).join(", "),
    };
  }
  if (parts.length === 2) {
    return { fullAddress: trimmed, streetLine: parts[0], cityState: parts[1] };
  }
  return { fullAddress: trimmed, streetLine: parts[0] ?? null, cityState: null };
}

export interface LocationPresentation {
  title: string;
  subtitle: string | null;
  fullAddress: string | null;
  googleMapsURL: string | null;
  appleMapsURL: string | null;
  wazeURL: string | null;
}

export function buildLocationPresentation(
  locationName: string | null | undefined,
  locationAddress: string | null | undefined,
  canViewFullAddress: boolean
): LocationPresentation | null {
  const trimmedName = (locationName ?? "").trim();
  const parsed = parseAddress(locationAddress);

  if (!trimmedName && !parsed.fullAddress) return null;

  const encode = (addr: string) => encodeURIComponent(addr);

  if (canViewFullAddress) {
    const title = trimmedName || parsed.streetLine || parsed.cityState || "Location";
    const subtitle = trimmedName
      ? (parsed.fullAddress ?? null)
      : parsed.cityState && parsed.streetLine
        ? parsed.cityState
        : null;

    const mapAddr = parsed.fullAddress;
    return {
      title,
      subtitle,
      fullAddress: parsed.fullAddress,
      googleMapsURL: mapAddr ? `https://www.google.com/maps/search/?api=1&query=${encode(mapAddr)}` : null,
      appleMapsURL: mapAddr ? `https://maps.apple.com/?q=${encode(mapAddr)}` : null,
      wazeURL: mapAddr ? `https://waze.com/ul?q=${encode(mapAddr)}` : null,
    };
  }

  // Not authorized to see full address
  return {
    title: trimmedName || parsed.cityState || "Approximate location",
    subtitle: trimmedName ? (parsed.cityState ?? null) : null,
    fullAddress: null,
    googleMapsURL: null,
    appleMapsURL: null,
    wazeURL: null,
  };
}
