import AppKit
import QuartzCore

@MainActor
final class OverlayManager {
    private var windows: [NSWindow] = []
    private var autoStopTimer: Timer?
    private var active = false
    var onAutoStop: (() -> Void)?

    var isActive: Bool {
        active
    }

    func start(intensity: Double, maxDuration: TimeInterval, respectReduceMotion: Bool) {
        stop()

        let reduceMotion = respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let clampedIntensity = max(0.1, min(1, reduceMotion ? min(intensity, 0.25) : intensity))

        syncWindows(intensity: clampedIntensity, reduceMotion: reduceMotion)
        for (window, screen) in zip(windows, NSScreen.screens) {
            window.setFrame(screen.frame, display: true)
            guard let view = window.contentView as? ShakeOverlayView else { continue }
            view.configure(intensity: clampedIntensity, reduceMotion: reduceMotion)
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
            if let view = window.contentView as? ShakeOverlayView {
                view.stopAnimation()
            }
            window.orderOut(nil)
        }
    }

    func refreshIfActive(intensity: Double, maxDuration: TimeInterval, respectReduceMotion: Bool) {
        guard isActive else { return }
        start(intensity: intensity, maxDuration: maxDuration, respectReduceMotion: respectReduceMotion)
    }

    private func syncWindows(intensity: Double, reduceMotion: Bool) {
        let screens = NSScreen.screens
        if windows.count > screens.count {
            for window in windows.dropFirst(screens.count) {
                if let view = window.contentView as? ShakeOverlayView {
                    view.stopAnimation()
                }
                window.orderOut(nil)
            }
            windows = Array(windows.prefix(screens.count))
        }

        while windows.count < screens.count {
            let screen = screens[windows.count]
            let view = ShakeOverlayView(intensity: intensity, reduceMotion: reduceMotion)
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

private final class ShakeOverlayView: NSView {
    private var intensity: Double
    private var reduceMotion: Bool

    init(intensity: Double, reduceMotion: Bool) {
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

    func configure(intensity: Double, reduceMotion: Bool) {
        stopAnimation()
        self.intensity = intensity
        self.reduceMotion = reduceMotion
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let alpha = 0.10 + 0.10 * intensity
        NSColor.systemRed.withAlphaComponent(alpha).setFill()
        bounds.fill(using: .sourceOver)

        drawEdgeBands()
        drawScanLines()
    }

    func startAnimation() {
        guard let layer else { return }
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

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.45, 0.9, 0.55, 0.85, 0.45]
        opacity.duration = reduceMotion ? 1.0 : 0.35
        opacity.repeatCount = .infinity

        layer.add(x, forKey: "shake-x")
        layer.add(y, forKey: "shake-y")
        layer.add(opacity, forKey: "shake-opacity")
    }

    func stopAnimation() {
        guard let layer else { return }
        layer.removeAllAnimations()
        layer.transform = CATransform3DIdentity
        layer.opacity = 1
    }

    private func drawEdgeBands() {
        let width = max(14, bounds.width * 0.018)
        let alpha = 0.25 + 0.35 * intensity
        NSColor.systemRed.withAlphaComponent(alpha).setFill()

        NSRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height).fill()
        NSRect(x: bounds.maxX - width, y: bounds.minY, width: width, height: bounds.height).fill()
        NSRect(x: bounds.minX, y: bounds.maxY - width, width: bounds.width, height: width).fill()
        NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: width).fill()
    }

    private func drawScanLines() {
        NSColor.white.withAlphaComponent(0.07 + 0.08 * intensity).setStroke()
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
