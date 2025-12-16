import XCTest
@testable import PasteFence

final class HuggingFaceClientTests: XCTestCase {

    // MARK: - HuggingFaceAPI Tests

    func testFilesURLConstruction() {
        let url = HuggingFaceAPI.filesURL(for: "Qwen/Qwen3-0.6B-MLX-8bit")
        XCTAssertEqual(
            url.absoluteString,
            "https://huggingface.co/api/models/Qwen/Qwen3-0.6B-MLX-8bit/tree/main"
        )
    }

    func testFilesURLWithCustomRevision() {
        let url = HuggingFaceAPI.filesURL(for: "Qwen/Qwen3-0.6B-MLX-8bit", revision: "v1.0")
        XCTAssertEqual(
            url.absoluteString,
            "https://huggingface.co/api/models/Qwen/Qwen3-0.6B-MLX-8bit/tree/v1.0"
        )
    }

    func testDownloadURLConstruction() {
        let url = HuggingFaceAPI.downloadURL(for: "Qwen/Qwen3-0.6B-MLX-8bit", path: "config.json")
        XCTAssertEqual(
            url.absoluteString,
            "https://huggingface.co/Qwen/Qwen3-0.6B-MLX-8bit/resolve/main/config.json"
        )
    }

    func testDownloadURLWithCustomRevision() {
        let url = HuggingFaceAPI.downloadURL(
            for: "Qwen/Qwen3-0.6B-MLX-8bit",
            path: "model.safetensors",
            revision: "v1.0"
        )
        XCTAssertEqual(
            url.absoluteString,
            "https://huggingface.co/Qwen/Qwen3-0.6B-MLX-8bit/resolve/v1.0/model.safetensors"
        )
    }

    // MARK: - HFFileInfo Tests

    func testFileInfoDecoding() throws {
        let json = """
        {
            "type": "file",
            "path": "config.json",
            "size": 1234,
            "oid": "abc123"
        }
        """

        let data = json.data(using: .utf8)!
        let fileInfo = try JSONDecoder().decode(HFFileInfo.self, from: data)

        XCTAssertEqual(fileInfo.type, "file")
        XCTAssertEqual(fileInfo.path, "config.json")
        XCTAssertEqual(fileInfo.size, 1234)
        XCTAssertEqual(fileInfo.oid, "abc123")
        XCTAssertTrue(fileInfo.isFile)
        XCTAssertFalse(fileInfo.isDirectory)
    }

    func testDirectoryInfoDecoding() throws {
        let json = """
        {
            "type": "directory",
            "path": "subdir",
            "size": null,
            "oid": null
        }
        """

        let data = json.data(using: .utf8)!
        let fileInfo = try JSONDecoder().decode(HFFileInfo.self, from: data)

        XCTAssertEqual(fileInfo.type, "directory")
        XCTAssertEqual(fileInfo.path, "subdir")
        XCTAssertNil(fileInfo.size)
        XCTAssertNil(fileInfo.oid)
        XCTAssertFalse(fileInfo.isFile)
        XCTAssertTrue(fileInfo.isDirectory)
    }

    func testFileInfoArrayDecoding() throws {
        let json = """
        [
            {"type": "file", "path": "config.json", "size": 100, "oid": "a"},
            {"type": "file", "path": "model.safetensors", "size": 500000000, "oid": "b"},
            {"type": "directory", "path": "subdir", "size": null, "oid": null}
        ]
        """

        let data = json.data(using: .utf8)!
        let files = try JSONDecoder().decode([HFFileInfo].self, from: data)

        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(files.filter { $0.isFile }.count, 2)
        XCTAssertEqual(files.filter { $0.isDirectory }.count, 1)
    }

    func testFileInfoEquality() {
        let file1 = HFFileInfo(type: "file", path: "config.json", size: 100, oid: "abc")
        let file2 = HFFileInfo(type: "file", path: "config.json", size: 100, oid: "abc")
        let file3 = HFFileInfo(type: "file", path: "other.json", size: 200, oid: "def")

        XCTAssertEqual(file1, file2)
        XCTAssertNotEqual(file1, file3)
    }

    // MARK: - File Filtering Tests

    func testFilterRequiredFilesIncludesJsonFiles() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "file", path: "config.json", size: 100, oid: "a"),
            HFFileInfo(type: "file", path: "tokenizer.json", size: 200, oid: "b"),
            HFFileInfo(type: "file", path: "tokenizer_config.json", size: 50, oid: "c")
        ]

        let filtered = await client.filterRequiredFiles(files)

        XCTAssertEqual(filtered.count, 3)
    }

    func testFilterRequiredFilesIncludesSafetensors() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "file", path: "model.safetensors", size: 500_000_000, oid: "a"),
            HFFileInfo(type: "file", path: "model-00001-of-00002.safetensors", size: 250_000_000, oid: "b")
        ]

        let filtered = await client.filterRequiredFiles(files)

        XCTAssertEqual(filtered.count, 2)
    }

    func testFilterRequiredFilesIncludesBinFiles() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "file", path: "pytorch_model.bin", size: 500_000_000, oid: "a")
        ]

        let filtered = await client.filterRequiredFiles(files)

        XCTAssertEqual(filtered.count, 1)
    }

    func testFilterRequiredFilesIncludesVocabFiles() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "file", path: "vocab.txt", size: 1000, oid: "a"),
            HFFileInfo(type: "file", path: "merges.txt", size: 2000, oid: "b"),
            HFFileInfo(type: "file", path: "sentencepiece.model", size: 3000, oid: "c")
        ]

        let filtered = await client.filterRequiredFiles(files)

        XCTAssertEqual(filtered.count, 3)
    }

    func testFilterRequiredFilesExcludesDirectories() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "directory", path: "subdir", size: nil, oid: nil),
            HFFileInfo(type: "file", path: "config.json", size: 100, oid: "a")
        ]

        let filtered = await client.filterRequiredFiles(files)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.path, "config.json")
    }

    func testFilterRequiredFilesExcludesReadme() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "file", path: "README.md", size: 500, oid: "a"),
            HFFileInfo(type: "file", path: "config.json", size: 100, oid: "b")
        ]

        let filtered = await client.filterRequiredFiles(files)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.path, "config.json")
    }

    func testFilterRequiredFilesExcludesLicense() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "file", path: "LICENSE", size: 1000, oid: "a"),
            HFFileInfo(type: "file", path: "LICENSE.md", size: 1000, oid: "b"),
            HFFileInfo(type: "file", path: "config.json", size: 100, oid: "c")
        ]

        let filtered = await client.filterRequiredFiles(files)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.path, "config.json")
    }

    func testFilterRequiredFilesExcludesGitFiles() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "file", path: ".gitattributes", size: 100, oid: "a"),
            HFFileInfo(type: "file", path: ".gitignore", size: 50, oid: "b"),
            HFFileInfo(type: "file", path: "config.json", size: 100, oid: "c")
        ]

        let filtered = await client.filterRequiredFiles(files)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.path, "config.json")
    }

    func testFilterRequiredFilesExcludesUnknownExtensions() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "file", path: "image.png", size: 100000, oid: "a"),
            HFFileInfo(type: "file", path: "document.pdf", size: 200000, oid: "b"),
            HFFileInfo(type: "file", path: "config.json", size: 100, oid: "c")
        ]

        let filtered = await client.filterRequiredFiles(files)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.path, "config.json")
    }

    // MARK: - Total Size Calculation Tests

    func testTotalDownloadSizeCalculation() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "file", path: "config.json", size: 100, oid: "a"),
            HFFileInfo(type: "file", path: "model.safetensors", size: 500_000_000, oid: "b"),
            HFFileInfo(type: "file", path: "tokenizer.json", size: 200, oid: "c")
        ]

        let totalSize = await client.totalDownloadSize(files)

        XCTAssertEqual(totalSize, 500_000_300)
    }

    func testTotalDownloadSizeWithNilSizes() async {
        let client = HuggingFaceClient()
        let files = [
            HFFileInfo(type: "file", path: "config.json", size: 100, oid: "a"),
            HFFileInfo(type: "directory", path: "subdir", size: nil, oid: nil),
            HFFileInfo(type: "file", path: "model.safetensors", size: 500_000_000, oid: "b")
        ]

        let totalSize = await client.totalDownloadSize(files)

        XCTAssertEqual(totalSize, 500_000_100)
    }

    func testTotalDownloadSizeEmptyArray() async {
        let client = HuggingFaceClient()
        let files: [HFFileInfo] = []

        let totalSize = await client.totalDownloadSize(files)

        XCTAssertEqual(totalSize, 0)
    }

    // MARK: - Byte Formatting Tests

    func testFormatBytesKilobytes() {
        let formatted = HuggingFaceClient.formatBytes(1024)
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("kB"))
    }

    func testFormatBytesMegabytes() {
        let formatted = HuggingFaceClient.formatBytes(1_048_576)
        XCTAssertTrue(formatted.contains("MB"))
    }

    func testFormatBytesGigabytes() {
        let formatted = HuggingFaceClient.formatBytes(1_073_741_824)
        XCTAssertTrue(formatted.contains("GB"))
    }

    // MARK: - Error Tests

    func testHFErrorDescriptions() {
        let networkError = HFError.networkError(URLError(.notConnectedToInternet))
        XCTAssertTrue(networkError.errorDescription?.contains("Network error") ?? false)

        let httpError = HFError.httpError(statusCode: 500)
        XCTAssertEqual(httpError.errorDescription, "HTTP error: 500")

        let notFound = HFError.notFound(repoId: "test/repo")
        XCTAssertEqual(notFound.errorDescription, "Repository not found: test/repo")

        let rateLimitedWithRetry = HFError.rateLimited(retryAfter: 60)
        XCTAssertEqual(rateLimitedWithRetry.errorDescription, "Rate limited. Retry after 60 seconds")

        let rateLimitedNoRetry = HFError.rateLimited(retryAfter: nil)
        XCTAssertEqual(rateLimitedNoRetry.errorDescription, "Rate limited. Please try again later")

        let invalidResponse = HFError.invalidResponse
        XCTAssertEqual(invalidResponse.errorDescription, "Invalid response from HuggingFace API")

        let decodingError = HFError.decodingError(DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "test")
        ))
        XCTAssertTrue(decodingError.errorDescription?.contains("Failed to decode") ?? false)
    }

    // MARK: - Comprehensive Filtering Test

    func testFilterRealWorldModelFiles() async {
        let client = HuggingFaceClient()

        // Simulate typical HuggingFace model repository contents
        let files = [
            // Should be included
            HFFileInfo(type: "file", path: "config.json", size: 725, oid: "a"),
            HFFileInfo(type: "file", path: "tokenizer.json", size: 2_500_000, oid: "b"),
            HFFileInfo(type: "file", path: "tokenizer_config.json", size: 345, oid: "c"),
            HFFileInfo(type: "file", path: "special_tokens_map.json", size: 150, oid: "d"),
            HFFileInfo(type: "file", path: "model.safetensors", size: 400_000_000, oid: "e"),
            HFFileInfo(type: "file", path: "vocab.txt", size: 500_000, oid: "f"),
            HFFileInfo(type: "file", path: "merges.txt", size: 400_000, oid: "g"),

            // Should be excluded
            HFFileInfo(type: "file", path: "README.md", size: 5000, oid: "h"),
            HFFileInfo(type: "file", path: "LICENSE", size: 1000, oid: "i"),
            HFFileInfo(type: "file", path: ".gitattributes", size: 100, oid: "j"),
            HFFileInfo(type: "directory", path: ".git", size: nil, oid: nil)
        ]

        let filtered = await client.filterRequiredFiles(files)

        XCTAssertEqual(filtered.count, 7)

        let filteredPaths = Set(filtered.map { $0.path })
        XCTAssertTrue(filteredPaths.contains("config.json"))
        XCTAssertTrue(filteredPaths.contains("tokenizer.json"))
        XCTAssertTrue(filteredPaths.contains("model.safetensors"))
        XCTAssertFalse(filteredPaths.contains("README.md"))
        XCTAssertFalse(filteredPaths.contains("LICENSE"))
        XCTAssertFalse(filteredPaths.contains(".gitattributes"))
    }

    // MARK: - DownloadProgress Tests

    func testDownloadProgressPercentageCalculation() {
        let progress = DownloadProgress(
            currentFile: "model.safetensors",
            fileIndex: 1,
            totalFiles: 3,
            bytesDownloaded: 250_000_000,
            totalBytes: 500_000_000
        )

        XCTAssertEqual(progress.percentComplete, 0.5, accuracy: 0.001)
    }

    func testDownloadProgressPercentageZeroTotal() {
        let progress = DownloadProgress(
            currentFile: "",
            fileIndex: 0,
            totalFiles: 0,
            bytesDownloaded: 0,
            totalBytes: 0
        )

        XCTAssertEqual(progress.percentComplete, 0.0)
    }

    func testDownloadProgressPercentageFull() {
        let progress = DownloadProgress(
            currentFile: "",
            fileIndex: 3,
            totalFiles: 3,
            bytesDownloaded: 500_000_000,
            totalBytes: 500_000_000
        )

        XCTAssertEqual(progress.percentComplete, 1.0, accuracy: 0.001)
    }

    func testDownloadProgressIsCompleteTrue() {
        let progress = DownloadProgress(
            currentFile: "",
            fileIndex: 5,
            totalFiles: 5,
            bytesDownloaded: 100,
            totalBytes: 100
        )

        XCTAssertTrue(progress.isComplete)
    }

    func testDownloadProgressIsCompleteFalse() {
        let progress = DownloadProgress(
            currentFile: "config.json",
            fileIndex: 2,
            totalFiles: 5,
            bytesDownloaded: 50,
            totalBytes: 100
        )

        XCTAssertFalse(progress.isComplete)
    }

    func testDownloadProgressEquality() {
        let progress1 = DownloadProgress(
            currentFile: "test.json",
            fileIndex: 1,
            totalFiles: 3,
            bytesDownloaded: 100,
            totalBytes: 300
        )

        let progress2 = DownloadProgress(
            currentFile: "test.json",
            fileIndex: 1,
            totalFiles: 3,
            bytesDownloaded: 100,
            totalBytes: 300
        )

        let progress3 = DownloadProgress(
            currentFile: "other.json",
            fileIndex: 2,
            totalFiles: 3,
            bytesDownloaded: 200,
            totalBytes: 300
        )

        XCTAssertEqual(progress1, progress2)
        XCTAssertNotEqual(progress1, progress3)
    }

    // MARK: - Download Error Tests

    func testDownloadFailedErrorWithReason() {
        let error = HFError.downloadFailed(filename: "model.safetensors", reason: "Connection timeout")
        XCTAssertEqual(
            error.errorDescription,
            "Download failed for model.safetensors: Connection timeout"
        )
    }

    func testDownloadFailedErrorWithoutReason() {
        let error = HFError.downloadFailed(filename: "config.json", reason: nil)
        XCTAssertEqual(
            error.errorDescription,
            "Download failed for config.json"
        )
    }

    func testDownloadFailedErrorNotFound() {
        let error = HFError.downloadFailed(filename: "missing.bin", reason: "File not found")
        XCTAssertTrue(error.errorDescription?.contains("File not found") ?? false)
    }

    func testDownloadFailedErrorHTTPStatus() {
        let error = HFError.downloadFailed(filename: "weights.safetensors", reason: "HTTP 500")
        XCTAssertTrue(error.errorDescription?.contains("HTTP 500") ?? false)
    }
}
