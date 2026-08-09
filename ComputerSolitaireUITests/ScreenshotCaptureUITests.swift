import XCTest
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Captures one App Store screenshot per test so Fastlane can select exactly
/// the requested games with XCTest's `only-testing` support.
final class ScreenshotCaptureUITests: XCTestCase {
    // Keep these method names aligned with GAME_TESTS in fastlane/Fastfile.
    @MainActor func testScreenshot01KlondikeDraw3() throws { try capture("klondike-draw3") }
    @MainActor func testScreenshot02Spider() throws { try capture("spider") }
    @MainActor func testScreenshot03FreeCell() throws { try capture("freecell") }
    @MainActor func testScreenshot04Yukon() throws { try capture("yukon") }
    @MainActor func testScreenshot05Pyramid() throws { try capture("pyramid") }
    @MainActor func testScreenshot06TriPeaks() throws { try capture("tripeaks") }
    @MainActor func testScreenshot07Golf() throws { try capture("golf") }
    @MainActor func testScreenshot08FortyThieves() throws { try capture("fortythieves") }
    @MainActor func testScreenshot09Scorpion() throws { try capture("scorpion") }
    @MainActor func testScreenshot10Canfield() throws { try capture("canfield") }

#if os(macOS)
    /// Full window size in points — title bar and toolbar included, since
    /// the toolbar holds the app's controls and belongs in the screenshot.
    /// On a 2x display the capture comes out at 2880x1800 pixels — an exact
    /// Mac App Store screenshot size.
    private static let windowSize = CGSize(width: 1440, height: 900)

    /// XCTest creates a fresh test-case instance per method, so cache the
    /// one window-frame probe across the selected macOS screenshots.
    @MainActor private static var cachedMacContentSize: CGSize?
#endif

    @MainActor
    private func capture(_ fixtureName: String) throws {
        let fixture = try XCTUnwrap(
            ScreenshotFixtureCatalog.fixture(named: fixtureName),
            "unknown screenshot fixture: \(fixtureName)"
        )
        let app = XCUIApplication()
#if os(macOS)
        let contentSize = try macContentSize()
        // Ignore persisted window state so the app-side pin always wins.
        app.launchArguments += [
            "-screenshotWindowSize",
            "\(Int(contentSize.width))x\(Int(contentSize.height))",
            "-ApplePersistenceIgnoreState", "YES"
        ]
#else
        // The explicit settle below is the only animation wait. Disabling the
        // helper's extra delay and idle polling saves a second per screenshot.
        setupSnapshot(app, waitForAnimations: false)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
#endif
        let requestedCardStyle = Self.requestedCardStyle(in: app.launchArguments)
        app.launchArguments += Self.appearance(cardStyle: requestedCardStyle)
        app.launchArguments += Self.interfaceStyleArguments
        app.launchArguments += ["-screenshotFixture", fixture.name]
        app.launch()
        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 10),
            "\(fixture.name): app window never appeared"
        )
        Thread.sleep(forTimeInterval: 2)

#if os(macOS)
        try captureMacWindow(of: app, named: fixture.name)
#else
        snapshot(fixture.name, timeWaitingForIdle: 0)
#endif
    }

    /// Pin every visible preference, while keeping the product's real platform
    /// defaults: Simple cards on iOS/iPadOS and Classic cards on macOS.
    private static func appearance(cardStyle requestedCardStyle: String?) -> [String] {
        let defaultCardStyle: String
#if os(macOS)
        defaultCardStyle = "classic"
#else
        defaultCardStyle = "simple"
#endif

        return [
            "-settings.tableBackgroundColor", "#5B9A9A",
            "-settings.cardStyle", requestedCardStyle ?? defaultCardStyle,
            "-settings.cardBackColor", "navy",
            "-settings.cardTiltEnabled", "YES",
            "-settings.feltEffectEnabled", "YES"
        ]
    }

    /// iOS receives the option through Snapshot's app launch arguments;
    /// macOS receives it through the xcodebuild test-runner environment.
    private static func requestedCardStyle(in launchArguments: [String]) -> String? {
#if os(macOS)
        if let environmentValue = ProcessInfo.processInfo.environment["SCREENSHOT_CARD_STYLE"],
           !environmentValue.isEmpty {
            return environmentValue
        }
#endif
        guard let flagIndex = launchArguments.lastIndex(of: "-screenshotCardStyle") else {
            return nil
        }
        let valueIndex = launchArguments.index(after: flagIndex)
        guard launchArguments.indices.contains(valueIndex) else { return nil }
        return launchArguments[valueIndex]
    }

    private static var interfaceStyleArguments: [String] {
#if os(macOS)
        let isDarkMode = ProcessInfo.processInfo.environment["SCREENSHOT_DARK_MODE"] != "false"
        return ["-AppleInterfaceStyle", isDarkMode ? "Dark" : "Light"]
#else
        return []
#endif
    }

#if os(macOS)
    @MainActor
    private func macContentSize() throws -> CGSize {
        if let cached = Self.cachedMacContentSize {
            return cached
        }
        let titleBarHeight = try measureTitleBarHeight()
        let size = CGSize(
            width: Self.windowSize.width,
            height: Self.windowSize.height - titleBarHeight
        )
        Self.cachedMacContentSize = size
        return size
    }

    /// Measures the window title-bar height: launches the app with its
    /// content pinned to the reference size and returns how much taller the
    /// window frame is. The probe instance is replaced by the next launch.
    @MainActor
    private func measureTitleBarHeight() throws -> CGFloat {
        let probe = XCUIApplication()
        probe.launchArguments += [
            "-screenshotWindowSize",
            "\(Int(Self.windowSize.width))x\(Int(Self.windowSize.height))",
            "-ApplePersistenceIgnoreState", "YES",
            "-screenshotFixture", ScreenshotFixtureCatalog.top3[0].name
        ]
        probe.launchArguments += Self.appearance(
            cardStyle: Self.requestedCardStyle(in: probe.launchArguments)
        )
        probe.launchArguments += Self.interfaceStyleArguments
        probe.launch()
        let window = probe.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "probe window never appeared")

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline, window.frame.height < Self.windowSize.height {
            Thread.sleep(forTimeInterval: 0.2)
        }
        let titleBarHeight = window.frame.height - Self.windowSize.height
        XCTAssertGreaterThan(titleBarHeight, 0, "probe: no title bar measured")
        XCTAssertLessThan(titleBarHeight, 100, "probe: implausible title-bar height")
        return titleBarHeight
    }

    /// Captures the full app window (title bar and toolbar included) as an
    /// exact-size PNG attachment.
    ///
    /// `XCUIElement.screenshot()` is unreliable for macOS windows (it can
    /// return the entire desktop), so this takes a full-screen capture and
    /// crops it to the window's frame. The window must be frontmost —
    /// anything overlapping it would end up in the crop.
    @MainActor
    private func captureMacWindow(of app: XCUIApplication, named name: String) throws {
        app.activate()
        let window = app.windows.firstMatch

        // Wait for the pinned content size plus measured title bar to land.
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline,
              abs(window.frame.width - Self.windowSize.width) > 1
                || abs(window.frame.height - Self.windowSize.height) > 1 {
            Thread.sleep(forTimeInterval: 0.2)
        }
        let frame = window.frame
        XCTAssertEqual(frame.width, Self.windowSize.width, accuracy: 1, "\(name): window never took the pinned size")
        XCTAssertEqual(frame.height, Self.windowSize.height, accuracy: 1, "\(name): window never took the pinned size")

        let screen = try XCTUnwrap(NSScreen.screens.first, "no screen")
        let fullImage = XCUIScreen.main.screenshot().image
        let fullCG = try XCTUnwrap(
            fullImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
            "\(name): screen capture failed"
        )

        // Window frame is in points with a top-left origin — the same
        // orientation as CGImage rows — so only the display scale applies.
        let scale = CGFloat(fullCG.width) / screen.frame.width
        let crop = CGRect(
            x: frame.minX * scale,
            y: frame.minY * scale,
            width: frame.width * scale,
            height: frame.height * scale
        ).integral
        let cropped = try XCTUnwrap(fullCG.cropping(to: crop), "\(name): crop failed")

        let expected = CGSize(
            width: Self.windowSize.width * screen.backingScaleFactor,
            height: Self.windowSize.height * screen.backingScaleFactor
        )
        XCTAssertEqual(CGFloat(cropped.width), expected.width, "\(name): capture is not an exact App Store size")
        XCTAssertEqual(CGFloat(cropped.height), expected.height, "\(name): capture is not an exact App Store size")

        let pngData = try XCTUnwrap(
            NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:]),
            "\(name): PNG encoding failed"
        )
        let attachment = XCTAttachment(data: pngData, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
#endif
}
