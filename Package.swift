// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "lazyvoice",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "lazyvoice",
            targets: ["lazyvoice"]
        )
    ],
    targets: [
        .target(
            name: "WhisperWrapper",
            path: "Sources/WhisperWrapper",
            sources: ["WhisperWrapper.c"],
            publicHeadersPath: "include",
            cSettings: [
                .define("GGML_USE_METAL")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L/Users/Alessandro/Documents/Startups/whisper.cpp/build/src",
                    "-L/Users/Alessandro/Documents/Startups/whisper.cpp/build/ggml/src",
                    "-L/Users/Alessandro/Documents/Startups/whisper.cpp/build/ggml/src/ggml-cpu", 
                    "-L/Users/Alessandro/Documents/Startups/whisper.cpp/build/ggml/src/ggml-metal",
                    "-lwhisper",
                    "-lggml",
                    "-lggml-base",
                    "-lggml-cpu",
                    "-lggml-metal",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/Alessandro/Documents/Startups/whisper.cpp/build/src",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/Alessandro/Documents/Startups/whisper.cpp/build/ggml/src",
                    "-Xlinker", "-rpath", "-Xlinker", "/Users/Alessandro/Documents/Startups/whisper.cpp/build/ggml/src/ggml-metal"
                ])
            ]
        ),
        .executableTarget(
            name: "lazyvoice",
            dependencies: ["WhisperWrapper"],
            path: "Sources/lazyvoice",
            sources: [
                "lazyvoiceApp.swift",
                "AppDelegate.swift",
                "MenuBarView.swift",
                "PreferencesView.swift",
                "AudioManager.swift",
                "WhisperManager.swift",
                "TranscriptionService.swift",
                "AudioResampler.swift",
                "HotkeyManager.swift",
                "RecordingOverlay.swift",
                "Transcription.swift",
                "HistoryManager.swift",
                "HistoryView.swift",
                "WaveformView.swift",
                "ErrorManager.swift",
                "PermissionManager.swift"
            ],
            resources: [
                .copy("ggml-tiny.bin")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Accelerate"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
) 