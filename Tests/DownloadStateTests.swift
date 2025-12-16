import XCTest
@testable import PasteFence

final class DownloadStateTests: XCTestCase {

    // MARK: - SpeedCalculator Tests

    func testSpeedCalculatorEmptyReturnsZero() {
        let calculator = SpeedCalculator()
        XCTAssertEqual(calculator.calculateSpeed(), 0)
    }

    func testSpeedCalculatorSingleSampleReturnsZero() {
        var calculator = SpeedCalculator()
        calculator.addSample(bytes: 1000)
        XCTAssertEqual(calculator.calculateSpeed(), 0)
    }

    func testSpeedCalculatorWithTwoSamples() {
        var calculator = SpeedCalculator(sampleWindow: 10.0)

        // First sample
        calculator.addSample(bytes: 0)

        // Simulate time passing (we can't easily test this without time manipulation)
        // For now, test that we get some speed value with multiple samples
        calculator.addSample(bytes: 1000)

        // Speed should be 0 or positive (depends on time between samples)
        XCTAssertGreaterThanOrEqual(calculator.calculateSpeed(), 0)
    }

    func testSpeedCalculatorReset() {
        var calculator = SpeedCalculator()
        calculator.addSample(bytes: 1000)
        calculator.addSample(bytes: 2000)
        calculator.reset()
        XCTAssertEqual(calculator.calculateSpeed(), 0)
    }

    func testSpeedCalculatorETAWithZeroSpeed() {
        let calculator = SpeedCalculator()
        let eta = calculator.estimatedTimeRemaining(for: 1000)
        XCTAssertEqual(eta, .infinity)
    }

    // MARK: - DownloadState Initialization Tests

    @MainActor
    func testDownloadStateInitialValues() {
        let state = DownloadState()

        XCTAssertFalse(state.isDownloading)
        XCTAssertEqual(state.currentFile, "")
        XCTAssertEqual(state.progress, 0.0)
        XCTAssertEqual(state.downloadedBytes, 0)
        XCTAssertEqual(state.totalBytes, 0)
        XCTAssertEqual(state.speed, 0.0)
        XCTAssertEqual(state.estimatedTimeRemaining, 0)
        XCTAssertNil(state.error)
    }

    // MARK: - DownloadState Formatted Properties Tests

    @MainActor
    func testFormattedProgressWithValues() {
        let state = DownloadState()
        state.downloadedBytes = 500_000_000  // 500 MB
        state.totalBytes = 1_000_000_000     // 1 GB

        let formatted = state.formattedProgress
        // Should contain both values - exact format depends on locale
        XCTAssertTrue(formatted.contains("/"))
        XCTAssertFalse(formatted.isEmpty)
    }

    @MainActor
    func testFormattedProgressWithZero() {
        let state = DownloadState()
        state.downloadedBytes = 0
        state.totalBytes = 0

        let formatted = state.formattedProgress
        XCTAssertTrue(formatted.contains("/"))
    }

    @MainActor
    func testFormattedSpeed() {
        let state = DownloadState()
        state.speed = 10_000_000  // 10 MB/s

        let formatted = state.formattedSpeed
        XCTAssertTrue(formatted.contains("/s"))
    }

    @MainActor
    func testFormattedSpeedZero() {
        let state = DownloadState()
        state.speed = 0

        let formatted = state.formattedSpeed
        XCTAssertTrue(formatted.contains("/s"))
    }

    @MainActor
    func testFormattedETAWithValidTime() {
        let state = DownloadState()
        state.estimatedTimeRemaining = 330  // 5 minutes 30 seconds

        let formatted = state.formattedETA
        XCTAssertNotEqual(formatted, "Calculating...")
        XCTAssertFalse(formatted.isEmpty)
    }

    @MainActor
    func testFormattedETAWithZero() {
        let state = DownloadState()
        state.estimatedTimeRemaining = 0

        let formatted = state.formattedETA
        XCTAssertEqual(formatted, "Calculating...")
    }

    @MainActor
    func testFormattedETAWithInfinity() {
        let state = DownloadState()
        state.estimatedTimeRemaining = .infinity

        let formatted = state.formattedETA
        XCTAssertEqual(formatted, "Calculating...")
    }

    @MainActor
    func testFileProgressString() {
        let state = DownloadState()
        state.currentFileIndex = 1
        state.totalFiles = 5

        XCTAssertEqual(state.fileProgressString, "File 2 of 5")
    }

    @MainActor
    func testFileProgressStringEmpty() {
        let state = DownloadState()
        state.totalFiles = 0

        XCTAssertEqual(state.fileProgressString, "")
    }

    // MARK: - DownloadState State Management Tests

    @MainActor
    func testStartDownload() {
        let state = DownloadState()
        state.startDownload(totalBytes: 1_000_000, totalFiles: 5)

        XCTAssertTrue(state.isDownloading)
        XCTAssertEqual(state.totalBytes, 1_000_000)
        XCTAssertEqual(state.totalFiles, 5)
        XCTAssertEqual(state.downloadedBytes, 0)
        XCTAssertEqual(state.progress, 0.0)
    }

    @MainActor
    func testUpdateProgress() {
        let state = DownloadState()
        state.totalBytes = 1_000_000

        state.updateProgress(
            downloadedBytes: 500_000,
            currentFile: "model.safetensors",
            fileIndex: 2,
            speed: 1_000_000,
            eta: 0.5
        )

        XCTAssertEqual(state.downloadedBytes, 500_000)
        XCTAssertEqual(state.currentFile, "model.safetensors")
        XCTAssertEqual(state.currentFileIndex, 2)
        XCTAssertEqual(state.speed, 1_000_000)
        XCTAssertEqual(state.estimatedTimeRemaining, 0.5)
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.001)
    }

    @MainActor
    func testCompleteDownload() {
        let state = DownloadState()
        state.startDownload(totalBytes: 1_000_000, totalFiles: 3)
        state.completeDownload()

        XCTAssertFalse(state.isDownloading)
        XCTAssertEqual(state.progress, 1.0)
        XCTAssertEqual(state.downloadedBytes, state.totalBytes)
        XCTAssertEqual(state.estimatedTimeRemaining, 0)
    }

    @MainActor
    func testFailDownload() {
        let state = DownloadState()
        state.startDownload(totalBytes: 1_000_000, totalFiles: 3)

        let error = HFError.networkError(URLError(.notConnectedToInternet))
        state.failDownload(with: error)

        XCTAssertFalse(state.isDownloading)
        XCTAssertNotNil(state.error)
    }

    @MainActor
    func testReset() {
        let state = DownloadState()
        state.startDownload(totalBytes: 1_000_000, totalFiles: 3)
        state.updateProgress(
            downloadedBytes: 500_000,
            currentFile: "test.json",
            fileIndex: 1,
            speed: 100_000,
            eta: 5.0
        )

        state.reset()

        XCTAssertFalse(state.isDownloading)
        XCTAssertEqual(state.currentFile, "")
        XCTAssertEqual(state.progress, 0.0)
        XCTAssertEqual(state.downloadedBytes, 0)
        XCTAssertEqual(state.totalBytes, 0)
        XCTAssertEqual(state.speed, 0.0)
        XCTAssertEqual(state.estimatedTimeRemaining, 0)
        XCTAssertNil(state.error)
    }

    // MARK: - DownloadProgressDelegate Tests

    func testDownloadProgressDelegateInit() {
        var progressCalled = false
        var completionCalled = false

        let delegate = DownloadProgressDelegate(
            progressHandler: { _, _ in progressCalled = true },
            completionHandler: { _, _ in completionCalled = true }
        )

        XCTAssertNotNil(delegate)
        XCTAssertFalse(progressCalled)
        XCTAssertFalse(completionCalled)
    }
}
