import XCTest
@testable import PasteFence

final class DownloadResumeTests: XCTestCase {

    // MARK: - Test Fixtures

    var tempDir: URL!
    var storage: DownloadResumeStorage!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadResumeTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = DownloadResumeStorage(storageURL: tempDir.appendingPathComponent("test_resume.json"))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - DownloadResumeInfo Tests

    func testDownloadResumeInfoCodable() throws {
        let original = DownloadResumeInfo(
            repoId: "test/model",
            filename: "model.safetensors",
            resumeData: Data([0x01, 0x02, 0x03]),
            downloadedBytes: 1024,
            totalBytes: 2048,
            timestamp: Date(),
            revision: "main"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DownloadResumeInfo.self, from: data)

        XCTAssertEqual(decoded.repoId, original.repoId)
        XCTAssertEqual(decoded.filename, original.filename)
        XCTAssertEqual(decoded.resumeData, original.resumeData)
        XCTAssertEqual(decoded.downloadedBytes, original.downloadedBytes)
        XCTAssertEqual(decoded.totalBytes, original.totalBytes)
        XCTAssertEqual(decoded.revision, original.revision)
    }

    func testDownloadResumeInfoNotStale() {
        let info = DownloadResumeInfo(
            repoId: "test/model",
            filename: "model.safetensors",
            resumeData: Data(),
            downloadedBytes: 0,
            totalBytes: 100,
            timestamp: Date(),
            revision: "main"
        )

        XCTAssertFalse(info.isStale)
    }

    func testDownloadResumeInfoIsStaleAfter24Hours() {
        let oldTimestamp = Date().addingTimeInterval(-25 * 60 * 60) // 25 hours ago
        let info = DownloadResumeInfo(
            repoId: "test/model",
            filename: "model.safetensors",
            resumeData: Data(),
            downloadedBytes: 0,
            totalBytes: 100,
            timestamp: oldTimestamp,
            revision: "main"
        )

        XCTAssertTrue(info.isStale)
    }

    // MARK: - DownloadResumeStorage Tests

    func testStorageSaveAndLoad() throws {
        let info = DownloadResumeInfo(
            repoId: "Qwen/Qwen3-0.6B",
            filename: "model.safetensors",
            resumeData: Data([0xDE, 0xAD, 0xBE, 0xEF]),
            downloadedBytes: 500_000,
            totalBytes: 1_000_000,
            timestamp: Date(),
            revision: "main"
        )

        try storage.save(info)

        let loaded = storage.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.repoId, info.repoId)
        XCTAssertEqual(loaded?.filename, info.filename)
        XCTAssertEqual(loaded?.resumeData, info.resumeData)
        XCTAssertEqual(loaded?.downloadedBytes, info.downloadedBytes)
        XCTAssertEqual(loaded?.totalBytes, info.totalBytes)
    }

    func testStorageLoadReturnsNilWhenEmpty() {
        let loaded = storage.load()
        XCTAssertNil(loaded)
    }

    func testStorageClear() throws {
        let info = DownloadResumeInfo(
            repoId: "test/model",
            filename: "test.bin",
            resumeData: Data(),
            downloadedBytes: 0,
            totalBytes: 100,
            timestamp: Date(),
            revision: "main"
        )

        try storage.save(info)
        XCTAssertNotNil(storage.load())

        storage.clear()
        XCTAssertNil(storage.load())
    }

    func testStorageLoadReturnsNilForStaleData() throws {
        let oldTimestamp = Date().addingTimeInterval(-25 * 60 * 60) // 25 hours ago
        let info = DownloadResumeInfo(
            repoId: "test/model",
            filename: "test.bin",
            resumeData: Data(),
            downloadedBytes: 0,
            totalBytes: 100,
            timestamp: oldTimestamp,
            revision: "main"
        )

        try storage.save(info)

        // Load should return nil for stale data
        let loaded = storage.load()
        XCTAssertNil(loaded)
    }

    func testStorageHasResumeData() throws {
        XCTAssertFalse(storage.hasResumeData)

        let info = DownloadResumeInfo(
            repoId: "test/model",
            filename: "test.bin",
            resumeData: Data(),
            downloadedBytes: 0,
            totalBytes: 100,
            timestamp: Date(),
            revision: "main"
        )

        try storage.save(info)
        XCTAssertTrue(storage.hasResumeData)
    }

    // MARK: - Multiple Resume Info Tests

    func testStorageSaveAndLoadMultiple() throws {
        let infos = [
            DownloadResumeInfo(
                repoId: "test/model",
                filename: "file1.bin",
                resumeData: Data([0x01]),
                downloadedBytes: 100,
                totalBytes: 200,
                timestamp: Date(),
                revision: "main"
            ),
            DownloadResumeInfo(
                repoId: "test/model",
                filename: "file2.bin",
                resumeData: Data([0x02]),
                downloadedBytes: 50,
                totalBytes: 300,
                timestamp: Date(),
                revision: "main"
            )
        ]

        try storage.saveMultiple(infos)

        let loaded = storage.loadMultiple()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].filename, "file1.bin")
        XCTAssertEqual(loaded[1].filename, "file2.bin")
    }

    func testStorageResumeInfoForFile() throws {
        let info = DownloadResumeInfo(
            repoId: "test/model",
            filename: "target.bin",
            resumeData: Data([0xFF]),
            downloadedBytes: 100,
            totalBytes: 200,
            timestamp: Date(),
            revision: "main"
        )

        try storage.save(info)

        let found = storage.resumeInfo(for: "test/model", filename: "target.bin")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.resumeData, Data([0xFF]))

        let notFound = storage.resumeInfo(for: "test/model", filename: "other.bin")
        XCTAssertNil(notFound)
    }

    func testStorageClearMultiple() throws {
        let infos = [
            DownloadResumeInfo(
                repoId: "test/model",
                filename: "file1.bin",
                resumeData: Data(),
                downloadedBytes: 0,
                totalBytes: 100,
                timestamp: Date(),
                revision: "main"
            )
        ]

        try storage.saveMultiple(infos)
        XCTAssertFalse(storage.loadMultiple().isEmpty)

        storage.clearMultiple()
        XCTAssertTrue(storage.loadMultiple().isEmpty)
    }

    func testStorageClearAll() throws {
        let singleInfo = DownloadResumeInfo(
            repoId: "test/model",
            filename: "single.bin",
            resumeData: Data(),
            downloadedBytes: 0,
            totalBytes: 100,
            timestamp: Date(),
            revision: "main"
        )
        try storage.save(singleInfo)

        let multiInfos = [
            DownloadResumeInfo(
                repoId: "test/model",
                filename: "multi.bin",
                resumeData: Data(),
                downloadedBytes: 0,
                totalBytes: 100,
                timestamp: Date(),
                revision: "main"
            )
        ]
        try storage.saveMultiple(multiInfos)

        XCTAssertTrue(storage.hasResumeData)

        storage.clearAll()

        XCTAssertNil(storage.load())
        XCTAssertTrue(storage.loadMultiple().isEmpty)
        XCTAssertFalse(storage.hasResumeData)
    }

    // MARK: - HFError Tests

    func testHFErrorCancelledDescription() {
        let error = HFError.cancelled(resumeData: Data([0x01, 0x02]))
        XCTAssertEqual(error.errorDescription, "Download was cancelled")
    }

    func testHFErrorNoResumeDataDescription() {
        let error = HFError.noResumeData
        XCTAssertEqual(error.errorDescription, "No resume data available to continue download")
    }

    // MARK: - Exponential Backoff Tests

    func testExponentialBackoffCalculation() {
        let baseDelay: TimeInterval = 2.0

        // attempt 0: 2^0 * 2 = 2
        let delay0 = baseDelay * pow(2.0, Double(0))
        XCTAssertEqual(delay0, 2.0, accuracy: 0.001)

        // attempt 1: 2^1 * 2 = 4
        let delay1 = baseDelay * pow(2.0, Double(1))
        XCTAssertEqual(delay1, 4.0, accuracy: 0.001)

        // attempt 2: 2^2 * 2 = 8
        let delay2 = baseDelay * pow(2.0, Double(2))
        XCTAssertEqual(delay2, 8.0, accuracy: 0.001)
    }

    func testExponentialBackoffCap() {
        let baseDelay: TimeInterval = 2.0
        let maxDelay: TimeInterval = 60.0

        // attempt 5: 2^5 * 2 = 64, capped at 60
        let delay = min(baseDelay * pow(2.0, Double(5)), maxDelay)
        XCTAssertEqual(delay, 60.0, accuracy: 0.001)
    }

    // MARK: - ResumableDownloadDelegate Tests

    func testResumableDownloadDelegateInit() {
        var progressCalled = false
        var completionCalled = false

        let delegate = ResumableDownloadDelegate(
            progressHandler: { _, _ in progressCalled = true },
            completionHandler: { _, _, _ in completionCalled = true }
        )

        XCTAssertNotNil(delegate)
        XCTAssertFalse(progressCalled)
        XCTAssertFalse(completionCalled)
        XCTAssertNil(delegate.downloadTask)
    }
}
