import XCTest
import Combine
import AudioToolbox
@testable import GeoCue

// MARK: - Mock Services

final class MockRingtonePersistenceService: RingtonePersistenceProtocol {
    var savedSettings: RingtoneSettings?
    var shouldThrowError = false
    var errorToThrow: RingtoneError = .persistenceError("Mock error")
    
    func saveRingtoneSettings(_ settings: RingtoneSettings) throws {
        if shouldThrowError {
            throw errorToThrow
        }
        savedSettings = settings
    }
    
    func loadRingtoneSettings() throws -> RingtoneSettings {
        if shouldThrowError {
            throw errorToThrow
        }
        return savedSettings ?? RingtoneSettings()
    }
    
    func clearRingtoneSettings() throws {
        if shouldThrowError {
            throw errorToThrow
        }
        savedSettings = nil
    }
}

final class MockRingtoneAudioService: RingtoneAudioProtocol {
    var shouldFailPlayback = false
    var playbackError: RingtoneError = .soundPlaybackFailed("Mock playback error")
    var lastPlayedSoundID: SystemSoundID?
    
    func playSystemSound(_ soundID: SystemSoundID, completion: @escaping RingtoneCompletion<Void>) {
        lastPlayedSoundID = soundID
        
        if shouldFailPlayback {
            completion(.failure(playbackError))
        } else {
            completion(.success(()))
        }
    }
    
    func stopAudioPlayback() {
        lastPlayedSoundID = nil
    }
    
    func configureAudioSession() throws {
        // Mock implementation
    }
}

final class MockLogger: LoggerProtocol {
    var logs: [(level: String, message: String, category: LogCategory)] = []
    
    func info(_ message: String, category: LogCategory) {
        logs.append((level: "INFO", message: message, category: category))
    }
    
    func warning(_ message: String, category: LogCategory) {
        logs.append((level: "WARNING", message: message, category: category))
    }
    
    func error(_ message: String, category: LogCategory) {
        logs.append((level: "ERROR", message: message, category: category))
    }
    
    func debug(_ message: String, category: LogCategory) {
        logs.append((level: "DEBUG", message: message, category: category))
    }
}

// MARK: - Test Observer

final class TestRingtoneServiceObserver: RingtoneServiceObserver {
    var ringtoneUpdates: [RingtoneType] = []
    var toggleUpdates: [Bool] = []
    var errors: [RingtoneError] = []
    
    func ringtoneService(_ service: RingtoneServiceProtocol, didUpdateRingtone ringtone: RingtoneType) {
        ringtoneUpdates.append(ringtone)
    }
    
    func ringtoneService(_ service: RingtoneServiceProtocol, didToggleEnabled isEnabled: Bool) {
        toggleUpdates.append(isEnabled)
    }
    
    func ringtoneService(_ service: RingtoneServiceProtocol, didEncounterError error: RingtoneError) {
        errors.append(error)
    }
}

// MARK: - RingtoneService Tests

final class RingtoneServiceTests: XCTestCase {
    
    private var ringtoneService: RingtoneService!
    private var mockPersistence: MockRingtonePersistenceService!
    private var mockAudio: MockRingtoneAudioService!
    private var mockLogger: MockLogger!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        mockPersistence = MockRingtonePersistenceService()
        mockAudio = MockRingtoneAudioService()
        mockLogger = MockLogger()
        cancellables = Set<AnyCancellable>()
        
        ringtoneService = RingtoneService(
            persistenceService: mockPersistence,
            audioService: mockAudio,
            logger: mockLogger
        )
    }
    
    override func tearDown() {
        cancellables = nil
        ringtoneService = nil
        mockLogger = nil
        mockAudio = nil
        mockPersistence = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(ringtoneService.selectedRingtone, .defaultSound)
        XCTAssertTrue(ringtoneService.isRingtoneEnabled)
    }
    
    func testInitializationWithExistingSettings() {
        // Given
        let existingSettings = RingtoneSettings(selectedRingtone: .bell, isEnabled: false)
        mockPersistence.savedSettings = existingSettings
        
        // When
        let service = RingtoneService(
            persistenceService: mockPersistence,
            audioService: mockAudio,
            logger: mockLogger
        )
        
        // Then
        // Need to wait for async initialization
        let expectation = XCTestExpectation(description: "Service initialized")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(service.selectedRingtone, .bell)
            XCTAssertFalse(service.isRingtoneEnabled)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Ringtone Update Tests
    
    func testUpdateRingtoneSuccess() {
        // Given
        let expectation = XCTestExpectation(description: "Ringtone updated")
        var result: RingtoneResult<Void>?
        
        // When
        ringtoneService.updateRingtone(.bell) { updateResult in
            result = updateResult
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(result?.isSuccess == true)
        XCTAssertEqual(ringtoneService.selectedRingtone, .bell)
        XCTAssertEqual(mockPersistence.savedSettings?.selectedRingtone, .bell)
    }
    
    func testUpdateRingtoneFailure() {
        // Given
        mockPersistence.shouldThrowError = true
        let expectation = XCTestExpectation(description: "Ringtone update failed")
        var result: RingtoneResult<Void>?
        
        // When
        ringtoneService.updateRingtone(.bell) { updateResult in
            result = updateResult
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(result?.isFailure == true)
        XCTAssertEqual(ringtoneService.selectedRingtone, .defaultSound) // Should remain unchanged
    }
    
    func testUpdateRingtoneWithSameRingtone() {
        // Given
        let expectation = XCTestExpectation(description: "Same ringtone update")
        var result: RingtoneResult<Void>?
        
        // When
        ringtoneService.updateRingtone(.defaultSound) { updateResult in
            result = updateResult
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(result?.isSuccess == true)
        XCTAssertNil(mockPersistence.savedSettings) // Should not save if same
    }
    
    // MARK: - Toggle Tests
    
    func testToggleRingtoneEnabled() {
        // Given
        let expectation = XCTestExpectation(description: "Ringtone toggled")
        var result: RingtoneResult<Bool>?
        
        // When
        ringtoneService.toggleRingtoneEnabled { toggleResult in
            result = toggleResult
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        if case .success(let isEnabled) = result {
            XCTAssertFalse(isEnabled)
            XCTAssertFalse(ringtoneService.isRingtoneEnabled)
            XCTAssertEqual(mockPersistence.savedSettings?.isEnabled, false)
        } else {
            XCTFail("Expected success result")
        }
    }
    
    // MARK: - Preview Tests
    
    func testPreviewRingtoneSuccess() {
        // Given
        let expectation = XCTestExpectation(description: "Ringtone previewed")
        var result: RingtoneResult<Void>?
        
        // When
        ringtoneService.previewRingtone(.bell) { previewResult in
            result = previewResult
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(result?.isSuccess == true)
        XCTAssertEqual(mockAudio.lastPlayedSoundID, RingtoneType.bell.systemSoundID)
    }
    
    func testPreviewDefaultRingtone() {
        // Given
        let expectation = XCTestExpectation(description: "Default ringtone previewed")
        var result: RingtoneResult<Void>?
        
        // When
        ringtoneService.previewRingtone(.defaultSound) { previewResult in
            result = previewResult
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(result?.isSuccess == true)
        XCTAssertEqual(mockAudio.lastPlayedSoundID, 1007) // Default sound ID
    }
    
    func testPreviewRingtoneFailure() {
        // Given
        mockAudio.shouldFailPlayback = true
        let expectation = XCTestExpectation(description: "Ringtone preview failed")
        var result: RingtoneResult<Void>?
        
        // When
        ringtoneService.previewRingtone(.bell) { previewResult in
            result = previewResult
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(result?.isFailure == true)
    }
    
    // MARK: - Notification Sound Tests
    
    func testGetNotificationSoundWhenEnabled() {
        // Given
        // Service starts enabled by default
        
        // When
        let sound = ringtoneService.getNotificationSound()
        
        // Then
        XCTAssertNotNil(sound)
    }
    
    func testGetNotificationSoundWhenDisabled() {
        // Given
        let expectation = XCTestExpectation(description: "Ringtone disabled")
        
        ringtoneService.toggleRingtoneEnabled { _ in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // When
        let sound = ringtoneService.getNotificationSound()
        
        // Then
        XCTAssertNil(sound)
    }
    
    // MARK: - Observer Tests
    
    func testObserverNotifications() {
        // Given
        let observer = TestRingtoneServiceObserver()
        ringtoneService.addObserver(observer)
        let expectation = XCTestExpectation(description: "Observer notified")
        
        // When
        ringtoneService.updateRingtone(.bell) { _ in
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(observer.ringtoneUpdates.count, 1)
        XCTAssertEqual(observer.ringtoneUpdates.first, .bell)
    }
    
    // MARK: - Validation Tests
    
    func testConfigurationValidation() {
        // When
        let result = ringtoneService.validateConfiguration()
        
        // Then
        XCTAssertTrue(result.isSuccess)
    }
    
    // MARK: - Convenience Tests
    
    func testAvailableRingtones() {
        // When
        let ringtones = ringtoneService.availableRingtones
        
        // Then
        XCTAssertTrue(ringtones.contains(.defaultSound))
        XCTAssertTrue(ringtones.contains(.bell))
        XCTAssertFalse(ringtones.isEmpty)
    }
    
    func testRingtonesByCategory() {
        // When
        let categorizedRingtones = ringtoneService.ringtonesByCategory
        
        // Then
        XCTAssertFalse(categorizedRingtones.isEmpty)
        XCTAssertTrue(categorizedRingtones.keys.contains(.system))
    }
}

// MARK: - Result Extensions for Testing

private extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    var isFailure: Bool {
        return !isSuccess
    }
}