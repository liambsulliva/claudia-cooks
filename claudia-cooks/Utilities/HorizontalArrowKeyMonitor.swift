//
//  HorizontalArrowKeyMonitor.swift
//  claudia-cooks
//

import AppKit
import SwiftUI

/// Handles unmodified left/right arrow keys for the key window, unless a text field is focused.
struct HorizontalArrowKeyMonitor: NSViewRepresentable {
    var isEnabled: Bool
    let onLeftArrow: () -> Void
    let onRightArrow: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLeftArrow: onLeftArrow, onRightArrow: onRightArrow)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onLeftArrow = onLeftArrow
        context.coordinator.onRightArrow = onRightArrow
        context.coordinator.setMonitoring(enabled: isEnabled, for: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    final class Coordinator {
        var onLeftArrow: () -> Void
        var onRightArrow: () -> Void
        private var monitor: Any?

        init(onLeftArrow: @escaping () -> Void, onRightArrow: @escaping () -> Void) {
            self.onLeftArrow = onLeftArrow
            self.onRightArrow = onRightArrow
        }

        func setMonitoring(enabled: Bool, for view: NSView) {
            guard enabled else {
                stopMonitoring()
                return
            }

            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }

                guard Self.shouldHandle(event, for: view) else {
                    return event
                }

                switch event.keyCode {
                case Self.leftArrowKeyCode:
                    onLeftArrow()
                    return nil
                case Self.rightArrowKeyCode:
                    onRightArrow()
                    return nil
                default:
                    return event
                }
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private static let leftArrowKeyCode: UInt16 = 123
        private static let rightArrowKeyCode: UInt16 = 124

        private static func shouldHandle(_ event: NSEvent, for view: NSView) -> Bool {
            guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
                return false
            }

            guard view.window === NSApp.keyWindow else {
                return false
            }

            guard !isTextInputFocused() else {
                return false
            }

            return event.keyCode == leftArrowKeyCode || event.keyCode == rightArrowKeyCode
        }

        private static func isTextInputFocused() -> Bool {
            guard let responder = NSApp.keyWindow?.firstResponder else {
                return false
            }

            return responder is NSTextView || responder is NSTextField
        }
    }
}
