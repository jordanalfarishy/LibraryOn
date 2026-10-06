import CoreServices
import Foundation

private final class FolderChangeCallback {
    let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }
}

private let folderChangeCallback: FSEventStreamCallback = { _, context, _, _, _, _ in
    guard let context else { return }
    Unmanaged<FolderChangeCallback>.fromOpaque(context).takeUnretainedValue().onChange()
}

@MainActor final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private var callbackContext: UnsafeMutableRawPointer?

    init?(url: URL, onChange: @escaping @MainActor () -> Void) {
        let callback = FolderChangeCallback {
            Task { @MainActor in onChange() }
        }
        let pointer = Unmanaged.passRetained(callback).toOpaque()
        var context = FSEventStreamContext(version: 0, info: pointer, retain: nil,
                                           release: nil, copyDescription: nil)
        guard let stream = FSEventStreamCreate(
            nil, folderChangeCallback, &context, [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        ) else {
            Unmanaged<FolderChangeCallback>.fromOpaque(pointer).release()
            return nil
        }
        FSEventStreamSetDispatchQueue(stream, .main)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            Unmanaged<FolderChangeCallback>.fromOpaque(pointer).release()
            return nil
        }
        self.stream = stream
        callbackContext = pointer
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        if let callbackContext {
            Unmanaged<FolderChangeCallback>.fromOpaque(callbackContext).release()
            self.callbackContext = nil
        }
    }
}
