import Foundation

public enum VisualCueKind: String, CaseIterable, Codable, Equatable, Sendable {
    case desktopShake
    case edgePulse
    case screenFlash
    case scanSweep

    public var title: String {
        switch self {
        case .desktopShake:
            "Desktop Shake"
        case .edgePulse:
            "Edge Pulse"
        case .screenFlash:
            "Screen Flash"
        case .scanSweep:
            "Scan Sweep"
        }
    }

    public var shortLabel: String {
        switch self {
        case .desktopShake:
            "SHAKE"
        case .edgePulse:
            "EDGE"
        case .screenFlash:
            "FLASH"
        case .scanSweep:
            "SCAN"
        }
    }

    public var detail: String {
        switch self {
        case .desktopShake:
            "Jitters translucent overlays to make the desktop feel like it is shaking."
        case .edgePulse:
            "Pulses bright border rails around every display without moving the image."
        case .screenFlash:
            "Uses a high-visibility full-screen flash for maximum urgency."
        case .scanSweep:
            "Sweeps diagonal scan bands across the displays like a hardware warning pass."
        }
    }
}
