import Foundation
import LocalAuthentication
import Speech

// Read-only snapshot of device-level capabilities that the keyboard and the
// container app both need to consult when deciding what UI to show.
//
// `hasSystemMicBar` proxies for "device has Face ID and therefore iOS shows
// its own globe/mic action bar above the keyboard". The candidate-bar mic
// (LimeIME's home-button-iPhone fallback) is hidden when this is true.
//
// `supportsOnDeviceSpeech` reflects whether `SFSpeechRecognizer`'s on-device
// model is available for the given locale on this device — gates the mic
// affordance entirely on devices that can't run the recognition pipeline
// (pre-A12 hardware or unsupported locale).
//
// See docs/IOS_VOICE_INPUT.md §4 for the design rationale and docs/IOS_KB_GAP.md
// §4.3 for the host-class plumbing.
struct DeviceCapabilities {
    let isOnPad: Bool
    let hasSystemMicBar: Bool
    let supportsOnDeviceSpeech: Bool

    static func capture(isOnPad: Bool, locale: Locale = Locale.current) -> DeviceCapabilities {
        let ctx = LAContext()
        var laError: NSError?
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &laError)
        var faceID = ctx.biometryType == .faceID

        #if targetEnvironment(simulator)
        // Tests / simulator override — useful when the simulator reports
        // .none biometry but we want to exercise the Face ID code path.
        if let override = ProcessInfo.processInfo.environment["LIME_FORCE_FACEID"] {
            faceID = override == "1"
        }
        #endif

        // iPad never shows the iPhone system mic bar — clear the flag there
        // even if biometry reports Face ID (some iPads have Face ID hardware).
        let hasSystemMicBar = !isOnPad && faceID

        let supports = SFSpeechRecognizer.supportsOnDeviceRecognition(for: locale)

        return DeviceCapabilities(
            isOnPad: isOnPad,
            hasSystemMicBar: hasSystemMicBar,
            supportsOnDeviceSpeech: supports
        )
    }
}

private extension SFSpeechRecognizer {
    // Convenience matching the spec's call site. `SFSpeechRecognizer` has an
    // instance property `supportsOnDeviceRecognition`; this helper instantiates
    // a recogniser for the requested locale and reads it, defaulting to false
    // when the locale is unsupported entirely.
    static func supportsOnDeviceRecognition(for locale: Locale) -> Bool {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else { return false }
        return recognizer.supportsOnDeviceRecognition
    }
}
