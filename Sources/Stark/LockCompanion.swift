@preconcurrency import AppKit

@MainActor
final class LockCompanionMonitor: NSObject {
    private var observers: [NSObjectProtocol] = []
    var onSystemSleepOrWake: (() -> Void)?

    init(onSystemSleepOrWake: (() -> Void)? = nil) {
        self.onSystemSleepOrWake = onSystemSleepOrWake
        super.init()

        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.onSystemSleepOrWake?() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.onSystemSleepOrWake?() }
        })
    }

}
