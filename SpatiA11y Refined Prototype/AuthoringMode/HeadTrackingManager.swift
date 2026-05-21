import Foundation
import CoreMotion

final class HeadTrackingManager {
    private let motionManager = CMHeadphoneMotionManager()
    private var isRunning = false
    private var loggedFirstMotionUpdate = false

    func start(onUpdate: @escaping (_ yaw: Float, _ pitch: Float, _ roll: Float) -> Void) {
        guard !isRunning else { return }

        guard CMHeadphoneMotionManager.authorizationStatus() != .denied else {
            print("Head tracking denied.")
            return
        }

        guard motionManager.isDeviceMotionAvailable else {
            print("Headphone motion not available. Use AirPods Pro, AirPods Max, or AirPods (3rd gen) connected and worn.")
            return
        }

        isRunning = true
        loggedFirstMotionUpdate = false
        print("Head tracking started (headphone motion).")

        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            if let error {
                print("Headphone motion error:", error)
                return
            }

            guard let motion else { return }

            if !self.loggedFirstMotionUpdate {
                self.loggedFirstMotionUpdate = true
                print("Head tracking receiving motion updates.")
            }

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
        loggedFirstMotionUpdate = false
        motionManager.stopDeviceMotionUpdates()
        print("Head tracking stopped.")
    }
}
