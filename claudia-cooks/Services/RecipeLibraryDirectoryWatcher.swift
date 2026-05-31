//
//  RecipeLibraryDirectoryWatcher.swift
//  claudia-cooks
//

import CoreServices
import Foundation

/// Watches a recipe library folder for creates, deletes, and modifications.
final class RecipeLibraryDirectoryWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    init(libraryURL: URL, onChange: @escaping () -> Void) {
        self.onChange = onChange
        startWatching(path: libraryURL.path)
    }

    deinit {
        stopWatching()
    }

    private func startWatching(path: String) {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: { info in
                Unmanaged<RecipeLibraryDirectoryWatcher>.fromOpaque(info!).retain()
                return info
            },
            release: { info in
                Unmanaged<RecipeLibraryDirectoryWatcher>.fromOpaque(info!).release()
            },
            copyDescription: nil
        )

        let pathsToWatch = [path] as CFArray
        let flags = FSEventStreamCreateFlags(
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )

        guard let stream = FSEventStreamCreate(
            nil,
            { _, clientInfo, _, _, _, _ in
                guard let clientInfo else {
                    return
                }

                let watcher = Unmanaged<RecipeLibraryDirectoryWatcher>
                    .fromOpaque(clientInfo)
                    .takeUnretainedValue()
                watcher.onChange()
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.25,
            flags
        ) else {
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    private func stopWatching() {
        guard let stream else {
            return
        }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
