//
//  FPSCounter.swift
//  fps-counter
//
//  Created by Markus Gasser on 03.03.16.
//  Copyright © 2016 konoma GmbH. All rights reserved.
//

import UIKit
import QuartzCore


/// A class that tracks the current FPS of the running application.
///
/// `FPSCounter` uses `CADisplayLink` updates to count the frames per second drawn.
/// Set the delegate of this class to get notified in certain intervals of the
/// current FPS.
///
/// If you just want to see the FPS in the application you can use the
/// `FPSCounter.showInStatusBar(_:)` convenience method.
///
public class FPSCounter: NSObject {

    /// Helper class that relays display link updates to the FPSCounter
    ///
    /// This is necessary because CADisplayLink retains its target. Thus
    /// if the FPSCounter class would be the target of the display link
    /// it would create a retain cycle. The delegate has a weak reference
    /// to its parent FPSCounter, thus preventing this.
    ///
    internal class DisplayLinkDelegate: NSObject {

        /// A weak ref to the parent FPSCounter instance.
        weak var parentCounter: FPSCounter?

        /// Notify the parent FPSCounter of a CADisplayLink update.
        ///
        /// This method is automatically called by the CADisplayLink.
        ///
        /// - Parameters:
        ///   - displayLink: The display link that updated
        ///
        func updateFromDisplayLink(displayLink: CADisplayLink) {
            self.parentCounter?.updateFromDisplayLink(displayLink)
        }
    }


    // MARK: - Initialization

    private let displayLink: CADisplayLink
    private let displayLinkDelegate: DisplayLinkDelegate

    /// Create a new FPSCounter.
    ///
    /// To start receiving FPS updates you need to start tracking with the
    /// `startTracking(inRunLoop:mode:)` method.
    ///
    public override init() {
        self.displayLinkDelegate = DisplayLinkDelegate()
        self.displayLink = CADisplayLink(target: self.displayLinkDelegate, selector: "updateFromDisplayLink:")

        super.init()

        self.displayLinkDelegate.parentCounter = self
    }

    deinit {
        self.displayLink.invalidate()
    }


    // MARK: - Configuration

    /// The delegate that should receive FPS updates.
    public weak var delegate: FPSCounterDelegate?

    /// Delay between FPS updates. Longer delays mean more averaged FPS numbers.
    public var notificationDelay: NSTimeInterval = 1.0


    // MARK: - Tracking

    private var runloop: NSRunLoop?
    private var mode: String?

    /// Start tracking FPS updates.
    ///
    /// You can specify wich runloop to use for tracking, as well as the runloop modes.
    /// Usually you'll want the main runloop (default), and either the common run loop modes
    /// (default), or the tracking mode (`UITrackingRunLoopMode`).
    ///
    /// When the counter is already tracking, it's stopped first.
    ///
    /// - Parameters:
    ///   - runloop: The runloop to start tracking in
    ///   - mode:    The mode(s) to track in the runloop
    ///
    public func startTracking(inRunLoop runloop: NSRunLoop = NSRunLoop.mainRunLoop(), mode: String = NSRunLoopCommonModes) {
        self.stopTracking()

        self.runloop = runloop
        self.displayLink.addToRunLoop(runloop, forMode: mode)
    }

    /// Stop tracking FPS updates.
    ///
    /// This method does nothing if the counter is not currently tracking.
    ///
    public func stopTracking() {
        guard let runloop = self.runloop, mode = self.mode else { return }

        self.displayLink.removeFromRunLoop(runloop, forMode: mode)
        self.runloop = nil
        self.mode = nil
    }


    // MARK: - Handling Frame Updates

    private var lastNotificationTime: CFAbsoluteTime = 0.0
    private var numberOfFrames: Int = 0

    private func updateFromDisplayLink(displayLink: CADisplayLink) {
        if self.lastNotificationTime == 0.0 {
            self.lastNotificationTime = CFAbsoluteTimeGetCurrent()
            return
        }

        self.numberOfFrames += 1

        let currentTime = CFAbsoluteTimeGetCurrent()
        let elapsedTime = currentTime - self.lastNotificationTime

        if elapsedTime >= self.notificationDelay {
            self.notifyUpdateForElapsedTime(elapsedTime)
            self.lastNotificationTime = 0.0
            self.numberOfFrames = 0
        }
    }

    private func notifyUpdateForElapsedTime(elapsedTime: CFAbsoluteTime) {
        let fps = Int(round(Double(self.numberOfFrames) / elapsedTime))
        self.delegate?.fpsCounter(self, didUpdateFramesPerSecond: fps)
    }
}


/// The delegate protocol for the FPSCounter class.
///
/// Implement this protocol if you want to receive updates from a `FPSCounter`.
///
public protocol FPSCounterDelegate: NSObjectProtocol {

    /// Called in regular intervals while the counter is tracking FPS.
    ///
    /// - Parameters:
    ///   - counter: The FPSCounter that sent the update
    ///   - fps:     The current FPS of the application
    ///
    func fpsCounter(counter: FPSCounter, didUpdateFramesPerSecond fps: Int)
}
