import AppKit
import QuartzCore
import ShakeTimerCore

@MainActor
final class OverlayManager {
    private var windows: [NSWindow] = []
    private var autoStopTimer: Timer?
    private var active = false
    var onAutoStop: (() -> Void)?

    var isActive: Bool {
        active
    }

    func start(kind: VisualCueKind, intensity: Double, maxDuration: TimeInterval, respectReduceMotion: Bool) {
        stop()

        let reduceMotion = respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let clampedIntensity = max(0.1, min(1, reduceMotion ? min(intensity, 0.25) : intensity))

        syncWindows(kind: kind, intensity: clampedIntensity, reduceMotion: reduceMotion)
        for (window, screen) in zip(windows, NSScreen.screens) {
            window.setFrame(screen.frame, display: true)
            guard let view = window.contentView as? VisualCueOverlayView else { continue }
            view.configure(kind: kind, intensity: clampedIntensity, reduceMotion: reduceMotion)
            view.startAnimation()
            window.orderFrontRegardless()
        }
        active = true

        if maxDuration > 0 {
            autoStopTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.stop()
                    self?.onAutoStop?()
                }
            }
        }
    }

    func stop() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        active = false
        for window in windows {
            if let view = window.contentView as? VisualCueOverlayView {
                view.stopAnimation()
            }
            window.orderOut(nil)
        }
    }

    func refreshIfActive(kind: VisualCueKind, intensity: Double, maxDuration: TimeInterval, respectReduceMotion: Bool) {
        guard isActive else { return }
        start(kind: kind, intensity: intensity, maxDuration: maxDuration, respectReduceMotion: respectReduceMotion)
    }

    private func syncWindows(kind: VisualCueKind, intensity: Double, reduceMotion: Bool) {
        let screens = NSScreen.screens
        if windows.count > screens.count {
            for window in windows.dropFirst(screens.count) {
                if let view = window.contentView as? VisualCueOverlayView {
                    view.stopAnimation()
                }
                window.orderOut(nil)
            }
            windows = Array(windows.prefix(screens.count))
        }

        while windows.count < screens.count {
            let screen = screens[windows.count]
            let view = VisualCueOverlayView(kind: kind, intensity: intensity, reduceMotion: reduceMotion)
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.contentView = view
            windows.append(window)
        }
    }
}

private final class VisualCueOverlayView: NSView {
    private var kind: VisualCueKind
    private var intensity: Double
    private var reduceMotion: Bool

    init(kind: VisualCueKind, intensity: Double, reduceMotion: Bool) {
        self.kind = kind
        self.intensity = intensity
        self.reduceMotion = reduceMotion
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(kind: VisualCueKind, intensity: Double, reduceMotion: Bool) {
        stopAnimation()
        self.kind = kind
        self.intensity = intensity
        self.reduceMotion = reduceMotion
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        effect.draw(in: bounds, intensity: intensity)
    }

    func startAnimation() {
        guard let layer else { return }
        effect.addAnimations(to: layer, intensity: intensity, reduceMotion: reduceMotion)
    }

    func stopAnimation() {
        guard let layer else { return }
        layer.removeAllAnimations()
        layer.transform = CATransform3DIdentity
        layer.opacity = 1
    }

    private var effect: VisualCueEffect {
        switch kind {
        case .desktopShake:
            DesktopShakeEffect()
        case .edgePulse:
            EdgePulseEffect()
        case .screenFlash:
            ScreenFlashEffect()
        case .scanSweep:
            ScanSweepEffect()
        }
    }
}

private protocol VisualCueEffect {
    func draw(in bounds: NSRect, intensity: Double)
    func addAnimations(to layer: CALayer, intensity: Double, reduceMotion: Bool)
}

private extension VisualCueEffect {
    func opacityAnimation(values: [Double], duration: CFTimeInterval) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = values
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }

    func drawScanLines(in bounds: NSRect, intensity: Double, color: NSColor = .white) {
        color.withAlphaComponent(0.07 + 0.08 * intensity).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 2
        let spacing = max(32, 80 - intensity * 40)
        var y = bounds.minY
        while y < bounds.maxY {
            path.move(to: NSPoint(x: bounds.minX, y: y))
            path.line(to: NSPoint(x: bounds.maxX, y: y + 12 * intensity))
            y += spacing
        }
        path.stroke()
    }
}

private struct DesktopShakeEffect: VisualCueEffect {
    func draw(in bounds: NSRect, intensity: Double) {
        let alpha = 0.10 + 0.10 * intensity
        NSColor.systemRed.withAlphaComponent(alpha).setFill()
        bounds.fill(using: .sourceOver)

        drawEdgeBands(in: bounds, intensity: intensity)
        drawScanLines(in: bounds, intensity: intensity)
    }

    func addAnimations(to layer: CALayer, intensity: Double, reduceMotion: Bool) {
        let amplitude = reduceMotion ? 4 * intensity : 18 * intensity
        let duration = reduceMotion ? 0.55 : 0.08

        let x = CAKeyframeAnimation(keyPath: "transform.translation.x")
        x.values = [0, -amplitude, amplitude, -amplitude * 0.6, amplitude * 0.8, 0]
        x.duration = duration
        x.repeatCount = .infinity
        x.timingFunction = CAMediaTimingFunction(name: .linear)

        let y = CAKeyframeAnimation(keyPath: "transform.translation.y")
        y.values = [0, amplitude * 0.35, -amplitude * 0.25, amplitude * 0.2, 0]
        y.duration = duration * 1.3
        y.repeatCount = .infinity
        y.timingFunction = CAMediaTimingFunction(name: .linear)

        layer.add(x, forKey: "cue-shake-x")
        layer.add(y, forKey: "cue-shake-y")
        layer.add(opacityAnimation(values: [0.45, 0.9, 0.55, 0.85, 0.45], duration: reduceMotion ? 1.0 : 0.35), forKey: "cue-opacity")
    }

    private func drawEdgeBands(in bounds: NSRect, intensity: Double) {
        let width = max(14, bounds.width * 0.018)
        let alpha = 0.25 + 0.35 * intensity
        NSColor.systemRed.withAlphaComponent(alpha).setFill()

        NSRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height).fill()
        NSRect(x: bounds.maxX - width, y: bounds.minY, width: width, height: bounds.height).fill()
        NSRect(x: bounds.minX, y: bounds.maxY - width, width: bounds.width, height: width).fill()
        NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: width).fill()
    }
}

private struct EdgePulseEffect: VisualCueEffect {
    func draw(in bounds: NSRect, intensity: Double) {
        NSColor.black.withAlphaComponent(0.04 + 0.06 * intensity).setFill()
        bounds.fill(using: .sourceOver)

        let railWidth = max(18, bounds.width * (0.012 + 0.012 * intensity))
        NSColor.systemOrange.withAlphaComponent(0.5 + 0.35 * intensity).setFill()
        NSRect(x: bounds.minX, y: bounds.minY, width: railWidth, height: bounds.height).fill()
        NSRect(x: bounds.maxX - railWidth, y: bounds.minY, width: railWidth, height: bounds.height).fill()
        NSColor.systemYellow.withAlphaComponent(0.35 + 0.35 * intensity).setFill()
        NSRect(x: bounds.minX, y: bounds.maxY - railWidth, width: bounds.width, height: railWidth).fill()
        NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: railWidth).fill()

        drawCornerBrackets(in: bounds, railWidth: railWidth)
    }

    func addAnimations(to layer: CALayer, intensity: Double, reduceMotion: Bool) {
        layer.add(opacityAnimation(values: [0.30, 1.0, 0.48, 0.95, 0.30], duration: reduceMotion ? 1.2 : 0.42), forKey: "cue-edge-opacity")
    }

    private func drawCornerBrackets(in bounds: NSRect, railWidth: CGFloat) {
        NSColor.white.withAlphaComponent(0.55).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 3
        let length = railWidth * 4
        let corners = [
            (NSPoint(x: bounds.minX + railWidth, y: bounds.minY + railWidth), 1.0, 1.0),
            (NSPoint(x: bounds.maxX - railWidth, y: bounds.minY + railWidth), -1.0, 1.0),
            (NSPoint(x: bounds.minX + railWidth, y: bounds.maxY - railWidth), 1.0, -1.0),
            (NSPoint(x: bounds.maxX - railWidth, y: bounds.maxY - railWidth), -1.0, -1.0)
        ]
        for (origin, xDirection, yDirection) in corners {
            path.move(to: origin)
            path.line(to: NSPoint(x: origin.x + length * xDirection, y: origin.y))
            path.move(to: origin)
            path.line(to: NSPoint(x: origin.x, y: origin.y + length * yDirection))
        }
        path.stroke()
    }
}

private struct ScreenFlashEffect: VisualCueEffect {
    func draw(in bounds: NSRect, intensity: Double) {
        NSColor.systemYellow.withAlphaComponent(0.16 + 0.28 * intensity).setFill()
        bounds.fill(using: .sourceOver)
        NSColor.white.withAlphaComponent(0.10 + 0.18 * intensity).setFill()
        bounds.insetBy(dx: bounds.width * 0.08, dy: bounds.height * 0.08).fill(using: .sourceOver)
    }

    func addAnimations(to layer: CALayer, intensity: Double, reduceMotion: Bool) {
        layer.add(opacityAnimation(values: [0.12, 0.95, 0.28, 0.85, 0.12], duration: reduceMotion ? 1.2 : 0.6), forKey: "cue-flash-opacity")
    }
}

private struct ScanSweepEffect: VisualCueEffect {
    func draw(in bounds: NSRect, intensity: Double) {
        NSColor.systemBlue.withAlphaComponent(0.06 + 0.10 * intensity).setFill()
        bounds.fill(using: .sourceOver)

        NSColor.systemCyan.withAlphaComponent(0.18 + 0.28 * intensity).setStroke()
        let path = NSBezierPath()
        path.lineWidth = max(4, 8 * intensity)
        let spacing = max(44, 110 - intensity * 50)
        var x = bounds.minX - bounds.height
        while x < bounds.maxX {
            path.move(to: NSPoint(x: x, y: bounds.minY))
            path.line(to: NSPoint(x: x + bounds.height, y: bounds.maxY))
            x += spacing
        }
        path.stroke()
    }

    func addAnimations(to layer: CALayer, intensity: Double, reduceMotion: Bool) {
        let amplitude = reduceMotion ? 24 * intensity : 90 * intensity
        let sweep = CAKeyframeAnimation(keyPath: "transform.translation.x")
        sweep.values = [-amplitude, amplitude, -amplitude]
        sweep.duration = reduceMotion ? 1.4 : 0.55
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .linear)
        layer.add(sweep, forKey: "cue-scan-sweep")
        layer.add(opacityAnimation(values: [0.25, 0.8, 0.45, 0.9, 0.25], duration: reduceMotion ? 1.2 : 0.5), forKey: "cue-scan-opacity")
    }
}
