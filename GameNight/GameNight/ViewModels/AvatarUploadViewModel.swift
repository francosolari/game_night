import Foundation
import Combine

@MainActor
class AvatarUploadViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var error: Error?
    @Published var uploadedImageUrl: String?

    private let r2Service = R2StorageService.shared
    private let supabaseService = SupabaseService.shared

    func uploadAvatar(_ imageData: Data, userId: UUID) async {
        isUploading = true
        error = nil

        do {
            // Upload to R2
            let publicUrl = try await r2Service.uploadAvatar(data: imageData, userId: userId)

            // Update database
            var user = try await supabaseService.fetchCurrentUser()
            user.avatarUrl = publicUrl
            try await supabaseService.updateUser(user)

            uploadedImageUrl = publicUrl
        } catch {
            self.error = error
        }

        isUploading = false
    }
}
