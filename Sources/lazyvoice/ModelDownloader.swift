import Foundation
import Combine

class ModelDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadText = ""
    @Published var downloadError: String?
    
    private let modelUrls = [
        "tiny": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin",
        "base": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
        "small": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"
    ]
    
    private let modelSizes = [
        "tiny": 39_000_000,  // ~39MB
        "base": 148_000_000, // ~148MB
        "small": 488_000_000 // ~488MB
    ]
    
    func getModelPath(for modelType: String) -> String? {
        let fileName = getModelFileName(for: modelType)
        
        // First try app bundle resources
        if let bundlePath = Bundle.main.path(forResource: fileName.replacingOccurrences(of: ".bin", with: ""), ofType: "bin") {
            return bundlePath
        }
        
        // Then try application support directory
        guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let lazyvoiceDir = appSupportDir.appendingPathComponent("lazyvoice")
        let modelPath = lazyvoiceDir.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: modelPath.path) {
            return modelPath.path
        }
        
        return nil
    }
    
    func downloadModelIfNeeded(modelType: String) async throws -> String {
        let fileName = getModelFileName(for: modelType)
        
        // Check if model already exists
        if let existingPath = getModelPath(for: modelType) {
            print("ModelDownloader: Model \(modelType) already exists at: \(existingPath)")
            return existingPath
        }
        
        // Create application support directory
        guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ModelDownloadError.cannotCreateDirectory
        }
        
        let lazyvoiceDir = appSupportDir.appendingPathComponent("lazyvoice")
        try FileManager.default.createDirectory(at: lazyvoiceDir, withIntermediateDirectories: true)
        
        let targetPath = lazyvoiceDir.appendingPathComponent(fileName)
        
        // Download the model
        try await downloadModel(modelType: modelType, to: targetPath)
        
        return targetPath.path
    }
    
    private func downloadModel(modelType: String, to targetPath: URL) async throws {
        guard let urlString = modelUrls[modelType],
              let url = URL(string: urlString) else {
            throw ModelDownloadError.invalidURL
        }
        
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
            downloadText = "Downloading \(modelType) model..."
            downloadError = nil
        }
        
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url, delegate: DownloadDelegate(downloader: self))
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ModelDownloadError.downloadFailed
            }
            
            // Move the downloaded file to the target location
            try FileManager.default.moveItem(at: tempURL, to: targetPath)
            
            await MainActor.run {
                isDownloading = false
                downloadProgress = 1.0
                downloadText = "Model \(modelType) downloaded successfully!"
            }
            
            print("ModelDownloader: Successfully downloaded \(modelType) model to: \(targetPath.path)")
            
        } catch {
            await MainActor.run {
                isDownloading = false
                downloadError = "Failed to download \(modelType) model: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    private func getModelFileName(for modelType: String) -> String {
        switch modelType {
        case "base":
            return "ggml-base.bin"
        case "small":
            return "ggml-small.bin"
        default:
            return "ggml-tiny.bin"
        }
    }
    
    func getModelSize(for modelType: String) -> String {
        guard let sizeInBytes = modelSizes[modelType] else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: Int64(sizeInBytes), countStyle: .file)
    }
}

// MARK: - Download Delegate for Progress Tracking

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    weak var downloader: ModelDownloader?
    
    init(downloader: ModelDownloader) {
        self.downloader = downloader
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard totalBytesExpectedToWrite > 0 else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let mbDownloaded = Double(totalBytesWritten) / 1_000_000
        let mbTotal = Double(totalBytesExpectedToWrite) / 1_000_000
        
        Task { @MainActor in
            downloader?.downloadProgress = progress
            downloader?.downloadText = String(format: "Downloading... %.1fMB / %.1fMB", mbDownloaded, mbTotal)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // This will be handled in the main download function
    }
}

// MARK: - Error Types

enum ModelDownloadError: LocalizedError {
    case invalidURL
    case cannotCreateDirectory
    case downloadFailed
    case modelNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid model download URL"
        case .cannotCreateDirectory:
            return "Cannot create model storage directory"
        case .downloadFailed:
            return "Model download failed"
        case .modelNotFound:
            return "Requested model type not found"
        }
    }
} 