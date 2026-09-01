import AppKit

@MainActor private var focusFollowsMouseMonitor: Any? = nil
@MainActor private var focusFollowsTask: Task<(), any Error>? = nil

@MainActor func syncFocusFollowsMouse(_ config: Config) {
    if config.focusFollowsMouse.enabled == (focusFollowsMouseMonitor != nil) {
        return
    }

    if !config.focusFollowsMouse.enabled {
        NSEvent.removeMonitor(focusFollowsMouseMonitor.orDie())
        focusFollowsMouseMonitor = nil
        focusFollowsTask?.cancel()
        focusFollowsTask = nil
        return
    }

    // Interestingly, this callback seems to not fire when the mouse is down which is good,
    // because this is how I want it to work for windows/tabs/files dragging
    focusFollowsMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { @MainActor event in
        let location = event.locationInWindow.withYAxisFlipped
        focusFollowsTask?.cancel()
        focusFollowsTask = Task.startUnstructured { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try checkCancellation()
            // Ignores macOS menubar dropdown, but, unfortunately, it doesn't ignore non-native menu-like fake windows.
            // todo: It would be cool to somehow reuse isWindowHeuristic logic here
            if await isAxWindowUnderMouse(location) == false { return }
            try checkCancellation()
            let workspace = location.monitorApproximation.activeWorkspace
            var window: Window? = nil
            for child in workspace.floatingWindowsContainer.mruChildren {
                try checkCancellation()
                guard let child = child as? Window else { continue }
                guard let rect = try await child.getAxRect(.cancellable) else { continue }
                if rect.contains(location) {
                    window = child
                    break
                }
            }
            // Fork addition: if the pointer is still inside the window that
            // already has focus, leave focus alone.
            //
            // With `accordion-padding = 0` every window in a stack shares one
            // rect, so a point matches all of them and findWindowRecursively
            // below returns whichever comes first in tree order — not the one
            // actually visible. Moving the mouse *within* the visible window
            // then yanked focus to a hidden sibling, which raised and buried
            // the window under the cursor.
            //
            // Deliberately placed after the floating lookup, so a floating
            // window over the focused one still wins the pointer.
            if window == nil, let focused = focus.windowOrNil {
                try checkCancellation()
                if let rect = try await focused.getAxRect(.cancellable), rect.contains(location) {
                    return
                }
            }
            if window == nil {
                window = location.findWindowRecursively(in: workspace.rootTilingContainer, virtual: false, fullscreenCoversAll: true)
            }
            if let window {
                try await runLightSession(.focusFollowsMouse, token) {
                    _ = window.focusWindow()
                    window.nativeFocus()
                }
            }
        }
    }
}

@concurrent
private nonisolated func isAxWindowUnderMouse(_ location: CGPoint) async -> Bool? {
    let systemwide = AXUIElementCreateSystemWide()
    var element: AXUIElement?
    if unsafe AXUIElementCopyElementAtPosition(systemwide, Float(location.x), Float(location.y), &element) != .success {
        return nil
    }
    guard let element else { return nil }
    return element.get(Ax.parentWindowRecursive) != nil || element.get(Ax.roleAttr) == kAXWindowRole
}
