build:
	swift build --configuration release --arch arm64 && mv .build/arm64-apple-macosx/release/generateInterface .
