import Foundation
import AVFoundation
import AudioToolbox

final class RingtoneAudioService: NSObject, RingtoneAudioProtocol, AVAudioPlayerDelegate {
    
    // MARK: - Properties
    
    private let logger: LoggerProtocol
    private var audioSession: AVAudioSession?
    private var audioPlayer: AVAudioPlayer?
    private let queue = DispatchQueue(label: "com.pixelsbysaurav.geocue.audio", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    func playSystemSound(_ soundID: SystemSoundID, completion: @escaping RingtoneCompletion<Void>) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.audioSessionUnavailable))
                }
                return
            }
            
            self.logger.debug("Playing system sound: \(soundID)", category: .audio)
            
            // Validate sound ID
            guard self.isValidSystemSoundID(soundID) else {
                self.logger.error("Invalid system sound ID: \(soundID)", category: .audio)
                DispatchQueue.main.async {
                    completion(.failure(.systemSoundNotAvailable(soundID)))
                }
                return
            }
            
            do {
                try self.configureAudioSession()
                
                // Play the system sound
                AudioServicesPlaySystemSound(soundID)
                
                self.logger.debug("Successfully played system sound: \(soundID)", category: .audio)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                
            } catch {
                self.logger.error("Failed to play system sound \(soundID): \(error.localizedDescription)", category: .audio)
                DispatchQueue.main.async {
                    completion(.failure(.soundPlaybackFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    func stopAudioPlayback() {
        queue.async { [weak self] in
            self?.audioPlayer?.stop()
            self?.audioPlayer = nil
            self?.logger.debug("Audio playback stopped", category: .audio)
        }
    }
    
    func playCustomAudio(_ fileName: String, completion: @escaping RingtoneCompletion<Void>) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.audioSessionUnavailable))
                }
                return
            }
            
            self.logger.debug("Playing custom audio: \(fileName)", category: .audio)
            
            // Check if the audio file exists in the bundle
            let resourceName = String(fileName.dropLast(4)) // Remove file extension
            let fileExtension = String(fileName.dropFirst(resourceName.count + 1)) // Get extension
            
            guard let path = Bundle.main.path(forResource: resourceName, ofType: fileExtension) else {
                self.logger.error("Custom audio file not found: \(fileName)", category: .audio)
                DispatchQueue.main.async {
                    completion(.failure(.soundPlaybackFailed("Audio file not found: \(fileName)")))
                }
                return
            }
            
            do {
                try self.configureAudioSession()
                
                // Create audio player for custom files
                let url = URL(fileURLWithPath: path)
                let audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer = audioPlayer
                audioPlayer.delegate = self
                
                // Configure audio player
                audioPlayer.prepareToPlay()
                audioPlayer.play()
                
                self.logger.debug("Successfully started playing custom audio: \(fileName)", category: .audio)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                
            } catch {
                self.logger.error("Failed to play custom audio \(fileName): \(error.localizedDescription)", category: .audio)
                DispatchQueue.main.async {
                    completion(.failure(.soundPlaybackFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure audio session for notification sounds and previews
            // Use playback category for better notification sound support
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true, options: [])
            
            self.audioSession = audioSession
            logger.debug("Audio session configured for notifications and playback", category: .audio)
            
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)", category: .audio)
            throw RingtoneError.audioSessionUnavailable
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try configureAudioSession()
        } catch {
            logger.error("Initial audio session setup failed: \(error.localizedDescription)", category: .audio)
        }
    }
    
    private func isValidSystemSoundID(_ soundID: SystemSoundID) -> Bool {
        // System sound IDs typically range from 1000 to 1200
        // This is a basic validation - in production you might want to maintain
        // a more comprehensive list of valid sound IDs
        return soundID >= 1000 && soundID <= 1200
    }
    
    deinit {
        stopObservingAudioSession()
    }
}

// MARK: - Thread Safety Extensions

extension RingtoneAudioService {
    
    private func executeOnMainQueue<T>(_ operation: @escaping () -> T, completion: @escaping (T) -> Void) {
        queue.async {
            let result = operation()
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}

// MARK: - Audio Session Observer

extension RingtoneAudioService {
    
    func startObservingAudioSession() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        logger.debug("Started observing audio session notifications", category: .audio)
    }
    
    func stopObservingAudioSession() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        
        logger.debug("Stopped observing audio session notifications", category: .audio)
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            logger.info("Audio session interruption began", category: .audio)
            stopAudioPlayback()
            
        case .ended:
            logger.info("Audio session interruption ended", category: .audio)
            // Reactivate audio session if needed
            do {
                try configureAudioSession()
            } catch {
                logger.error("Failed to reactivate audio session after interruption: \(error.localizedDescription)", category: .audio)
            }
            
        @unknown default:
            logger.warning("Unknown audio session interruption type: \(typeValue)", category: .audio)
        }
    }
    
    @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        logger.debug("Audio session route changed: \(reason.rawValue)", category: .audio)
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            // Handle route changes (e.g., headphones connected/disconnected)
            logger.info("Audio route changed due to device change", category: .audio)
            
        default:
            break
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayer = nil
        logger.debug("Audio playback finished", category: .audio)
    }
}