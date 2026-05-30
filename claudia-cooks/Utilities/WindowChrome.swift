//
//  WindowChrome.swift
//  claudia-cooks
//

import AppKit
import SwiftUI

extension View {
    func windowChrome(mode: AppWindowMode) -> some View {
        background(WindowChromeConfigurator(mode: mode))
    }
}

private final class WindowSizeDelegate: NSObject, NSWindowDelegate {
    var mode: AppWindowMode = .frameworkPicker

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        switch mode {
        case .frameworkPicker:
            contentFrameSize(for: AppWindowMetrics.pickerSize, in: sender)
        case .builder:
            let minimumFrame = contentFrameSize(
                for: AppWindowMetrics.builderMinimumSize,
                in: sender
            )
            return NSSize(
                width: max(frameSize.width, minimumFrame.width),
                height: max(frameSize.height, minimumFrame.height)
            )
        }
        return frameSize
    }

    private func contentFrameSize(for contentSize: CGSize, in window: NSWindow) -> NSSize {
        let content = NSSize(width: contentSize.width, height: contentSize.height)
        return window.frameRect(forContentRect: NSRect(origin: .zero, size: content)).size
    }
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    let mode: AppWindowMode

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else {
                return
            }

            let coordinator = context.coordinator
            let modeChanged = coordinator.lastMode != mode
            coordinator.resizeDelegate.mode = mode

            if window.delegate !== coordinator.resizeDelegate {
                window.delegate = coordinator.resizeDelegate
            }

            apply(mode: mode, to: window, animateTransition: modeChanged)
            coordinator.lastMode = mode
        }
    }

    private func apply(mode: AppWindowMode, to window: NSWindow, animateTransition: Bool) {
        switch mode {
        case .frameworkPicker:
            var styleMask = window.styleMask
            styleMask.remove(.resizable)
            window.styleMask = styleMask

            let size = AppWindowMetrics.pickerSize
            let fixedSize = NSSize(width: size.width, height: size.height)
            window.minSize = fixedSize
            window.maxSize = fixedSize
            window.contentMinSize = fixedSize

            if animateTransition {
                animateWindow(window, toContentSize: fixedSize)
            }

        case .builder:
            var styleMask = window.styleMask
            styleMask.insert(.resizable)
            window.styleMask = styleMask

            let minSize = AppWindowMetrics.builderMinimumSize
            let minimum = NSSize(width: minSize.width, height: minSize.height)
            window.minSize = minimum
            window.contentMinSize = minimum
            window.maxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )

            let contentSize = window.contentLayoutRect.size
            if contentSize.width < minimum.width || contentSize.height < minimum.height {
                animateWindow(window, toContentSize: minimum)
            }
        }
    }

    private func animateWindow(_ window: NSWindow, toContentSize size: NSSize) {
        var frame = window.frame
        let newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin.y += frame.size.height - newFrame.size.height
        frame.size = newFrame.size
        window.setFrame(frame, display: true, animate: true)
    }

    final class Coordinator {
        var lastMode: AppWindowMode?
        let resizeDelegate = WindowSizeDelegate()
    }
}
