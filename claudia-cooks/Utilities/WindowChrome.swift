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

            guard context.coordinator.lastMode != mode else {
                return
            }

            context.coordinator.lastMode = mode
            apply(mode: mode, to: window)
        }
    }

    private func apply(mode: AppWindowMode, to window: NSWindow) {
        switch mode {
        case .frameworkPicker:
            var styleMask = window.styleMask
            styleMask.remove(.resizable)
            window.styleMask = styleMask

            let size = AppWindowMetrics.pickerSize
            let fixedSize = NSSize(width: size.width, height: size.height)
            window.minSize = fixedSize
            window.maxSize = fixedSize
            animateWindow(window, toContentSize: fixedSize)

        case .builder:
            var styleMask = window.styleMask
            styleMask.insert(.resizable)
            window.styleMask = styleMask

            let minSize = AppWindowMetrics.builderMinimumSize
            let minimum = NSSize(width: minSize.width, height: minSize.height)
            window.minSize = minimum
            window.maxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )

            if window.frame.size.width < minimum.width || window.frame.size.height < minimum.height {
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
    }
}
