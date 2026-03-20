import Foundation
import Combine

@MainActor
class GameImageUploadViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var error: Error?
    @Published var uploadedImageUrl: String?

    private let r2Service = R2StorageService.shared
    private let supabaseService = SupabaseService.shared

    func uploadGameImage(_ imageData: Data, gameId: UUID) async {
        isUploading = true
        error = nil

        do {
            // Upload to R2
            let publicUrl = try await r2Service.uploadGameImage(data: imageData, gameId: gameId)

            // Update database
            try await supabaseService.updateGameImageUrl(gameId: gameId, imageUrl: publicUrl)

            uploadedImageUrl = publicUrl
        } catch {
            self.error = error
        }

        isUploading = false
    }
}

@MainActor
class EventCoverUploadViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var error: Error?
    @Published var uploadedImageUrl: String?

    private let r2Service = R2StorageService.shared
    private let supabaseService = SupabaseService.shared

    func uploadEventCover(_ imageData: Data, eventId: UUID) async {
        isUploading = true
        error = nil

        do {
            // Upload to R2
            let publicUrl = try await r2Service.uploadEventCover(data: imageData, eventId: eventId)

            // Update database
            try await supabaseService.updateEventCoverImageUrl(eventId: eventId, coverImageUrl: publicUrl)

            uploadedImageUrl = publicUrl
        } catch {
            self.error = error
        }

        isUploading = false
    }
}
