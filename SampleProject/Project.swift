import ProjectDescription

extension Module {
    static let userProfile = Module(
        name: "UserProfile",
        kind: .business,
        moduleDependencies: [
            .core.extensionKit,
            .core.oxide
        ],
        features: [
            .tests(
                moduleDependencies: [.core.typography]
            ),
            .snapshotTests(),
            .testSupport(targetDependencies: [
                .testSupportTarget(of: .core.ribs)
            ])
        ]
    )
}
