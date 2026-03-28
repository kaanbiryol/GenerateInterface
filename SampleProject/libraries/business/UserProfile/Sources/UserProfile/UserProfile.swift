import Foundation

/// A repository for managing user profiles.
public protocol UserProfileRepository {
    func fetchProfile(id: String) async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws
}

/// A user profile.
public struct UserProfile: Sendable {
    public let id: String
    public let name: String
    public let email: String
    public let createdAt: Date

    public init(id: String, name: String, email: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
    }
}

/// Account status for a user profile.
public enum AccountStatus: String, CaseIterable, Sendable {
    case active
    case inactive
    case suspended
}

extension UserProfile {
    /// The user's display name, falling back to email.
    public var displayName: String {
        name.isEmpty ? email : name
    }
}

/// Creates a placeholder profile for previews.
public func makePreviewUserProfile() -> UserProfile {
    UserProfile(
        id: "preview",
        name: "Jane Doe",
        email: "jane@example.com",
        createdAt: Date()
    )
}
