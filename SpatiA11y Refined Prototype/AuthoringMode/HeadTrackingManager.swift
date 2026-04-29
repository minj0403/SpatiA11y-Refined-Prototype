import Foundation
import CoreMotion

final class HeadTrackingManager {
    private let motionManager = CMHeadphoneMotionManager()
    private var isRunning = false
    
    func start(onUpdate: @escaping (_ yaw: Float, _ pitch: Float, _ roll: Float) -> Void) {
        guard !isRunning else { return }

        guard CMHeadphoneMotionManager.authorizationStatus() != .denied else {
            print("Head tracking denied.")
            return
        }

        guard motionManager.isDeviceMotionAvailable else {
            print("Headphone motion not available.")
            return
        }

        isRunning = true

        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            if let error {
                print("Headphone motion error:", error)
                return
            }

            guard let motion else { return }

            let attitude = motion.attitude
            let yaw = Float(attitude.yaw)
            let pitch = Float(attitude.pitch)
            let roll = Float(attitude.roll)

            onUpdate(yaw, pitch, roll)
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        motionManager.stopDeviceMotionUpdates()
    }
}
