import LocalAuthentication

enum FaceIDLockManager {
    /// Flipping the Settings toggle on is the only trigger for this prompt —
    /// never at launch.
    static func canUseBiometricsOrPasscode() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    static func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}
