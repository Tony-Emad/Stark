import AppKit
@preconcurrency import AVFoundation
import LocalAuthentication
import ServiceManagement
import SwiftUI
import Vision

private let starkFaceRecognitionService = FaceRecognitionService()
private let starkSetupDismissedKey = "stark.setup-dismissed"

extension Notification.Name {
    static let starkPanelShowRequested = Notification.Name("stark.panel-show-requested")
}

@main
struct StarkApp: App {
    @NSApplicationDelegateAdaptor(StarkAppDelegate.self) private var appDelegate
    @StateObject private var model = StarkModel()

    var body: some Scene {
        WindowGroup("Stark") {
            StarkNotchView(model: model)
                .frame(width: 360, height: 330)
                .background(NotchWindowConfigurator())
                .onAppear {
                    if model.shouldShowPanel {
                        model.panelVisible = true
                        model.startCamera()
                    } else {
                        model.panelVisible = false
                        DispatchQueue.main.async {
                            StarkWindowController.hidePanel()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .starkPanelShowRequested)) { _ in
                    model.panelVisible = true
                    model.startCamera()
                }
                .onDisappear { model.stopCamera() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            StarkSettingsView(model: model)
        }

        MenuBarExtra("Stark", systemImage: "faceid") {
            Button(model.isLocked ? "Stark is locked" : "Lock Stark now") {
                model.lockNow()
                StarkWindowController.showPanel()
            }
            .disabled(model.identityStore.sampleCount == 0)

            Button("Open Stark setup") {
                model.openSetup()
                StarkWindowController.showPanel()
            }

            Divider()
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.setLaunchAtLogin($0) }
            ))
            SettingsLink { Text("Stark settings…") }
            Divider()
            Button("Quit Stark") { NSApp.terminate(nil) }
        }
    }
}

final class StarkAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            StarkWindowController.configureExistingWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DispatchQueue.main.async {
            StarkWindowController.reopenFromDock()
        }
        return true
    }
}

enum StarkPhase: Equatable {
    case idle
    case requestingCamera
    case looking
    case faceFound
    case authorized
    case unavailable(String)
}

enum StarkSetupStep: Int, CaseIterable {
    case welcome
    case faceScan
    case secure
    case ready
}

struct CameraChoice: Identifiable, Hashable {
    let id: String
    let name: String
}

enum StarkSessionPolicy {
    static let minimumAutoLockMinutes = 1
    static let maximumAutoLockMinutes = 60

    static func clampAutoLockMinutes(_ minutes: Int) -> Int {
        min(max(minutes, minimumAutoLockMinutes), maximumAutoLockMinutes)
    }
}

@MainActor
final class StarkModel: NSObject, ObservableObject {
    @Published var phase: StarkPhase = .idle
    @Published var detail = "Stark keeps the scan local to this Mac."
    @Published var faceConfidence: Float = 0
    @Published var isRunning = false
    @Published var setupStep: StarkSetupStep = .faceScan
    @Published var poseIndex = 0
    @Published var livenessScore: Double = 0
    @Published var isLive = false
    @Published var isAutoCapturing = false
    @Published var panelVisible = true
    @Published var matchState: FaceMatchState = .notEnrolled
    @Published var enrollmentSamples = 0
    @Published var isLocked = false
    @Published var launchAtLoginEnabled = false
    @Published var selectedCameraID: String?
    @Published private(set) var cameras: [CameraChoice] = []
    @Published var autoLockMinutes: Int

    let session = AVCaptureSession()
    let identityStore: IdentityStore
    private let cameraQueue = DispatchQueue(label: "com.stark.camera")
    private var isConfigured = false
    private var latestFeaturePrintData: Data?
    private var currentInput: AVCaptureDeviceInput?
    private var currentOutput: AVCaptureVideoDataOutput?
    private var autoLockTask: Task<Void, Never>?
    private var autoCaptureTask: Task<Void, Never>?
    private var lockCompanionMonitor: LockCompanionMonitor?

    let poses = ["center", "top right", "right", "bottom right", "bottom", "bottom left", "left", "top left", "top"]

    override init() {
        identityStore = IdentityStore()
        let storedAutoLockMinutes = UserDefaults.standard.integer(forKey: "stark.auto-lock-minutes")
        autoLockMinutes = max(1, storedAutoLockMinutes == 0 ? 5 : storedAutoLockMinutes)
        super.init()
        enrollmentSamples = identityStore.sampleCount
        panelVisible = shouldShowPanel
        selectedCameraID = UserDefaults.standard.string(forKey: "stark.camera.id")
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        refreshCameras()
        lockCompanionMonitor = LockCompanionMonitor { [weak self] in
            self?.lockNow()
        }
        if enrollmentSamples >= poses.count {
            setupStep = .ready
            detail = "Stark is secured on this Mac."
        }
    }

    var currentInstruction: String {
        "Tilt your head to the \(poses[min(poseIndex, poses.count - 1)])"
    }

    var setupProgress: Double {
        guard setupStep == .faceScan else { return setupStep == .ready ? 1 : 0.1 }
        return Double(poseIndex + 1) / Double(poses.count)
    }

    var hasCompleteFaceSetup: Bool {
        identityStore.sampleCount >= poses.count
    }

    var hasDismissedSetup: Bool {
        UserDefaults.standard.bool(forKey: starkSetupDismissedKey)
    }

    var shouldShowPanel: Bool {
        !hasCompleteFaceSetup || !hasDismissedSetup
    }

    var faceStatusText: String {
        if phase == .faceFound && isLive && isAutoCapturing { return "Capturing automatically…" }
        if phase == .faceFound && isLive { return "Live face found — preparing capture" }
        if phase == .faceFound { return "Move slightly to confirm liveness" }
        if case .unavailable(let message) = phase { return message }
        return "Keep your face inside the circle"
    }

    func startSetup() {
        panelVisible = true
        setupStep = .faceScan
        poseIndex = min(identityStore.sampleCount, poses.count - 1)
        enrollmentSamples = identityStore.sampleCount
        latestFeaturePrintData = nil
        cancelAutoCapture()
        startCamera()
    }

    func openSetup() {
        UserDefaults.standard.set(false, forKey: starkSetupDismissedKey)
        panelVisible = true
        if hasCompleteFaceSetup {
            setupStep = .ready
            stopCamera()
        } else {
            setupStep = .faceScan
            poseIndex = min(identityStore.sampleCount, poses.count - 1)
            startCamera()
        }
    }

    func closePanel(permanently: Bool = false) {
        if permanently && hasCompleteFaceSetup {
            UserDefaults.standard.set(true, forKey: starkSetupDismissedKey)
        }
        panelVisible = false
        stopCamera()
        StarkWindowController.hidePanel()
    }

    func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    var cameraPermissionNeedsRecovery: Bool {
        if case .unavailable(let message) = phase {
            return message.localizedCaseInsensitiveContains("camera access")
        }
        return false
    }

    func resetEnrollment() {
        do {
            try identityStore.clear()
            UserDefaults.standard.set(false, forKey: starkSetupDismissedKey)
            enrollmentSamples = 0
            poseIndex = 0
            panelVisible = true
            setupStep = .faceScan
            isLocked = false
            latestFeaturePrintData = nil
            cancelAutoCapture()
            matchState = .notEnrolled
            detail = "Face setup deleted from this Mac."
            startCamera()
        } catch {
            detail = "Could not delete the saved face setup: \(error.localizedDescription)"
        }
    }

    func lockNow() {
        panelVisible = true
        guard identityStore.sampleCount > 0 else {
            detail = "Complete face setup before locking Stark."
            return
        }
        isLocked = true
        detail = "Look at the camera to verify your identity."
        startCamera()
    }

    func unlockFromFace() {
        guard isLocked else { return }
        guard case .matched(let distance) = matchState,
              StarkMatchPolicy.accepts(distance: distance, livenessScore: livenessScore, confidence: faceConfidence) else {
            detail = "Face match and liveness must both pass before authorization."
            return
        }
        authorizeWithTouchIDOrPassword()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            detail = "Could not change launch-at-login: \(error.localizedDescription)"
        }
    }

    func setAutoLockMinutes(_ minutes: Int) {
        autoLockMinutes = StarkSessionPolicy.clampAutoLockMinutes(minutes)
        UserDefaults.standard.set(autoLockMinutes, forKey: "stark.auto-lock-minutes")
        if !isLocked { armAutoLock() }
    }

    func refreshCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        cameras = discovery.devices.map { CameraChoice(id: $0.uniqueID, name: $0.localizedName) }
        if selectedCameraID == nil || !cameras.contains(where: { $0.id == selectedCameraID }) {
            selectedCameraID = cameras.first?.id
        }
    }

    func selectCamera(_ id: String) {
        guard selectedCameraID != id else { return }
        selectedCameraID = id
        UserDefaults.standard.set(id, forKey: "stark.camera.id")
        guard isConfigured else { return }

        let captureSession = session
        cameraQueue.async { captureSession.stopRunning() }
        session.beginConfiguration()
        if let currentInput { session.removeInput(currentInput) }
        if let currentOutput { session.removeOutput(currentOutput) }
        session.commitConfiguration()
        currentInput = nil
        currentOutput = nil
        isConfigured = false
        isRunning = false
        startCamera()
    }

    func advanceSetup() {
        switch setupStep {
        case .welcome:
            startSetup()
        case .faceScan:
            captureEnrollmentSample()
        case .secure:
            authorizeWithTouchIDOrPassword()
        case .ready:
            if hasCompleteFaceSetup {
                closePanel(permanently: true)
            } else {
                setupStep = .faceScan
                poseIndex = min(identityStore.sampleCount, poses.count - 1)
                startCamera()
            }
        }
    }

    func captureEnrollmentSample() {
        guard phase == .faceFound, isLive, let featurePrintData = latestFeaturePrintData else {
            detail = "Look at the camera and move slightly so Stark can verify a live face."
            return
        }

        do {
            try identityStore.add(featurePrint: featurePrintData)
            enrollmentSamples = identityStore.sampleCount
            latestFeaturePrintData = nil
            isLive = false
            livenessScore = 0
            if poseIndex + 1 < poses.count {
                poseIndex += 1
                detail = "Position captured. Continue with the next pose."
            } else {
                setupStep = .secure
                stopCamera()
                detail = "Secure Stark with Touch ID or your Mac password."
            }
        } catch {
            detail = "Could not save this local face sample: \(error.localizedDescription)"
        }
    }

    private func scheduleAutoCaptureIfReady() {
        guard setupStep == .faceScan, phase == .faceFound, isLive, autoCaptureTask == nil else { return }
        let poseBeingCaptured = poseIndex
        isAutoCapturing = true
        autoCaptureTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled else { return }
            self?.completeAutoCapture(for: poseBeingCaptured)
        }
    }

    private func completeAutoCapture(for pose: Int) {
        autoCaptureTask = nil
        isAutoCapturing = false
        guard pose == poseIndex, setupStep == .faceScan, phase == .faceFound, isLive else { return }
        captureEnrollmentSample()
    }

    private func cancelAutoCapture() {
        autoCaptureTask?.cancel()
        autoCaptureTask = nil
        isAutoCapturing = false
    }

    func startCamera() {
        guard !isRunning else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRunCamera()
        case .notDetermined:
            phase = .requestingCamera
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.configureAndRunCamera()
                    } else {
                        self.phase = .unavailable("Camera access is required")
                        self.detail = "Allow Stark in System Settings → Privacy & Security → Camera."
                    }
                }
            }
        default:
            phase = .unavailable("Camera access is disabled")
            detail = "Allow Stark in System Settings → Privacy & Security → Camera."
        }
    }

    func stopCamera() {
        guard isRunning else { return }
        let captureSession = session
        cameraQueue.sync { [weak self] in
            captureSession.stopRunning()
            _ = self
        }
        isRunning = false
    }

    func authorizeWithTouchIDOrPassword() {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            phase = .unavailable("Biometric authentication unavailable")
            detail = error?.localizedDescription ?? "Set up Touch ID or a Mac account password first."
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Secure Stark for this Mac") { [weak self] success, evaluationError in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.phase = .authorized
                    if self.isLocked {
                        self.isLocked = false
                        self.detail = "Stark unlocked with Touch ID or password."
                    } else {
                        self.setupStep = .ready
                        self.detail = "Stark is secured on this Mac."
                    }
                    self.armAutoLock()
                } else {
                    self.detail = evaluationError?.localizedDescription ?? "Authorization cancelled."
                }
            }
        }
    }

    private func configureAndRunCamera() {
        if !isConfigured {
            session.beginConfiguration()
            session.sessionPreset = .high

            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .external],
                mediaType: .video,
                position: .unspecified
            )
            let camera = discovery.devices.first(where: { $0.uniqueID == selectedCameraID }) ?? discovery.devices.first
            guard let camera,
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                phase = .unavailable("No camera found")
                detail = "Connect a camera and try again."
                return
            }
            session.addInput(input)
            currentInput = input

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: cameraQueue)
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                phase = .unavailable("Camera output unavailable")
                return
            }
            session.addOutput(output)
            if let connection = output.connection(with: .video) {
                configureNaturalCameraConnection(connection)
            }
            currentOutput = output
            session.commitConfiguration()
            isConfigured = true
        }

        phase = .looking
        detail = "Face presence is detected on-device."
        starkFaceRecognitionService.reset()
        isRunning = true
        let captureSession = session
        cameraQueue.async { [weak self] in
            captureSession.startRunning()
            Task { @MainActor in
                guard let self,
                      let connection = self.currentOutput?.connection(with: .video) else { return }
                configureNaturalCameraConnection(connection)
            }
        }
    }

    private func armAutoLock() {
        autoLockTask?.cancel()
        guard !isLocked, identityStore.sampleCount > 0 else { return }
        autoLockTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.autoLockMinutes ?? 5) * 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.lockNow()
        }
    }
}

extension StarkModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let result = starkFaceRecognitionService.process(pixelBuffer: pixelBuffer)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.faceConfidence = result.confidence
            self.livenessScore = result.livenessScore
            self.isLive = result.isLive
            if let featurePrintData = result.featurePrintData {
                self.latestFeaturePrintData = featurePrintData
                let distances = self.identityStore.featurePrints.compactMap {
                    FaceMatcher.distance(current: featurePrintData, enrolled: $0)
                }
                if let distance = distances.min() {
                    self.matchState = distance <= FaceMatcher.matchThreshold ? .matched(distance: distance) : .rejected(distance: distance)
                } else {
                    self.matchState = .notEnrolled
                }
            }

            if result.hasFace {
                if self.phase != .authorized { self.phase = .faceFound }
                if result.isLive && self.setupStep == .faceScan && !self.isLocked {
                    self.scheduleAutoCaptureIfReady()
                } else if !result.isLive {
                    self.cancelAutoCapture()
                }
            } else if self.phase != .authorized {
                self.cancelAutoCapture()
                self.phase = .looking
                self.faceConfidence = 0
                self.livenessScore = 0
                self.isLive = false
                self.matchState = self.identityStore.sampleCount == 0 ? .notEnrolled : .searching
            }
        }
    }

}

struct StarkNotchView: View {
    @ObservedObject var model: StarkModel

    var body: some View {
        Group {
            if model.panelVisible {
                ZStack {
                    NotchPanelShape()
                        .fill(Color.black)
                        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)

                    VStack(spacing: 0) {
                        HStack {
                            Text("STARK")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(2.4)
                                .foregroundStyle(.white.opacity(0.74))
                            Spacer()
                            Button {
                                model.closePanel()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 26, height: 26)
                            }
                            .buttonStyle(.plain)
                    }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                        Spacer(minLength: 6)
                        content
                        Spacer(minLength: 8)
                        progressDots.padding(.bottom, 16)
                    }
                    .padding(.horizontal, 18)
                }
            } else {
                Color.clear
            }
        }
        .frame(width: 360, height: 330)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLocked {
            lockContent
        } else {
            setupContent
        }
    }

    @ViewBuilder
    private var setupContent: some View {
        switch model.setupStep {
        case .welcome:
            VStack(spacing: 16) {
                logo
                Text("Set up Stark").font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("A private face-scan companion for your Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                primaryButton("Start setup", action: model.advanceSetup)
            }
        case .faceScan:
            VStack(spacing: 14) {
                faceScanner
                Text(model.currentInstruction)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                Text(model.faceStatusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.52))
                if model.cameraPermissionNeedsRecovery {
                    Button("Open Camera Settings") {
                        model.openCameraSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Text(model.isAutoCapturing ? "AUTO CAPTURE ARMED" : "AUTO CAPTURE WHEN LIVE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(model.isAutoCapturing ? .blue : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.08), in: Capsule())
                    .accessibilityLabel("Automatic capture is enabled")
            }
        case .secure:
            VStack(spacing: 16) {
                Image(systemName: "touchid")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(.blue, .white)
                Text("Secure your Stark setup")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                Text("Use Touch ID or your Mac password to protect this setup.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                primaryButton("Continue with Touch ID", action: model.advanceSetup)
            }
        case .ready:
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.green)
                Text("Stark is ready").font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("Your setup is protected on this Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.58))
                primaryButton("Done", action: model.advanceSetup)
            }
        }
    }

    private var lockContent: some View {
        VStack(spacing: 14) {
            ZStack {
                TickRing(progress: model.isLive ? 1 : model.livenessScore, diameter: 174)
                    .frame(width: 174, height: 174)
                CameraPreview(session: model.session)
                    .frame(width: 124, height: 124)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
            }
            Text("Stark is locked")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(model.faceStatusText)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.58))
            Button("Verify and unlock") {
                model.unlockFromFace()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.isLive)
            .accessibilityLabel("Verify your live face and unlock Stark")
            Button("Use Touch ID / password") {
                model.authorizeWithTouchIDOrPassword()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var logo: some View {
        Image("StarkLogo", bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: 90, height: 90)
            .clipShape(Circle())
    }

    private var faceScanner: some View {
        ZStack {
            TickRing(progress: model.setupProgress, diameter: 174)
                .frame(width: 174, height: 174)
            CameraPreview(session: model.session)
                .frame(width: 124, height: 124)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
        }
    }

    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(StarkSetupStep.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= model.setupStep.rawValue ? Color.blue : Color.white.opacity(0.22))
                    .frame(width: step == model.setupStep ? 22 : 7, height: 5)
                    .animation(.easeOut(duration: 0.2), value: model.setupStep)
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.9), in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
    }
}

struct TickRing: View {
    let progress: Double
    let diameter: CGFloat

    init(progress: Double, diameter: CGFloat = 220) {
        self.progress = progress
        self.diameter = diameter
    }

    var body: some View {
        ZStack {
            ForEach(0..<48, id: \.self) { index in
                Capsule()
                    .fill(index < Int(progress * 48) ? Color.blue : Color.white.opacity(0.78))
                    .frame(width: 2.4, height: index % 4 == 0 ? 12 : 8)
                    .offset(y: -(diameter / 2 - 7))
                    .rotationEffect(.degrees(Double(index) * 7.5))
            }
        }
        .animation(.easeOut(duration: 0.25), value: progress)
    }
}

struct NotchPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 32
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct NotchWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                StarkWindowController.configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window { StarkWindowController.configure(window) }
    }
}

@MainActor
enum StarkWindowController {
    private static let panelIdentifier = NSUserInterfaceItemIdentifier("com.stark.notch-panel")
    private static let panelSize = NSSize(width: 360, height: 330)
    private static var isPanelHidden = false

    static func configureExistingWindow() {
        guard let window = panelWindow() else { return }
        removeDuplicatePanels(keeping: window)
        configure(window)
    }

    static func showPanel() {
        isPanelHidden = false
        NotificationCenter.default.post(name: .starkPanelShowRequested, object: nil)
        configureExistingWindow()
        NSApp.activate(ignoringOtherApps: true)
        guard let window = panelWindow() else { return }
        removeDuplicatePanels(keeping: window)
        window.alphaValue = 1
        window.ignoresMouseEvents = false
        window.setContentSize(panelSize)
        position(window, size: panelSize)
        window.makeKeyAndOrderFront(nil)
    }

    static func reopenFromDock() {
        guard !settingsWindowIsVisible else { return }
        if UserDefaults.standard.bool(forKey: starkSetupDismissedKey) {
            hidePanel()
            showSettings()
            return
        }
        showPanel()
    }

    static func showSettings() {
        hidePanel()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    static func hidePanel() {
        isPanelHidden = true
        guard let window = panelWindow() else { return }
        window.ignoresMouseEvents = true
        window.alphaValue = 0
        window.orderOut(nil)
    }

    private static var settingsWindowIsVisible: Bool {
        NSApp.windows.contains {
            ($0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" || $0.title == "Stark Settings") && $0.isVisible
        }
    }

    private static func panelWindow() -> NSWindow? {
        panelWindows().first
    }

    private static func panelWindows() -> [NSWindow] {
        NSApp.windows.filter { window in
            window.identifier == panelIdentifier || window.title == "Stark"
        }
    }

    private static func removeDuplicatePanels(keeping window: NSWindow) {
        for duplicate in panelWindows() where duplicate !== window {
            duplicate.orderOut(nil)
            duplicate.close()
        }
    }

    static func configure(_ window: NSWindow) {
        window.identifier = panelIdentifier
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = false
        if window.frame.size != panelSize {
            DispatchQueue.main.async {
                guard !isPanelHidden else { return }
                window.setContentSize(panelSize)
                position(window, size: panelSize)
            }
        }
        if !isPanelHidden { window.orderFrontRegardless() }
    }

    private static func position(_ window: NSWindow, size: NSSize) {
        guard let screen = NSScreen.main else { return }
        let origin = CGPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height)
        window.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
    }
}

private func configureNaturalCameraConnection(_ connection: AVCaptureConnection) {
    if connection.isVideoMirroringSupported {
        // Do not allow AVFoundation to restore the front-camera selfie mirror.
        // The scan preview and the frame used by Vision must show the same
        // natural left/right orientation.
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = false
    }
    if #available(macOS 14.0, *), connection.isVideoRotationAngleSupported(0) {
        // Mac cameras use their native landscape sensor orientation. Keeping
        // the capture pipeline at zero degrees prevents rotated face geometry
        // from reaching Vision and keeps the preview aligned with the scan UI.
        connection.videoRotationAngle = 0
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.updateMirroring()
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.previewLayer.session = session
        nsView.updateMirroring()
    }
}

final class PreviewView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = AVCaptureVideoPreviewLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer = AVCaptureVideoPreviewLayer()
    }

    override func makeBackingLayer() -> CALayer { AVCaptureVideoPreviewLayer() }

    var previewLayer: AVCaptureVideoPreviewLayer {
        if let previewLayer = layer as? AVCaptureVideoPreviewLayer { return previewLayer }
        let previewLayer = AVCaptureVideoPreviewLayer()
        layer = previewLayer
        return previewLayer
    }

    func updateMirroring() {
        guard let connection = previewLayer.connection else { return }
        configureNaturalCameraConnection(connection)
    }

    override func layout() {
        super.layout()
        // The preview-layer connection can be created after SwiftUI first
        // assigns the session, so reapply the natural orientation during the
        // first layout pass and whenever the camera session changes size.
        updateMirroring()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateMirroring()
    }
}

struct StarkSettingsView: View {
    @ObservedObject var model: StarkModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "faceid")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Stark Settings")
                            .font(.title2.weight(.semibold))
                        Text("Camera, security, and session controls")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                settingsCard(title: "Security", systemImage: "lock.shield") {
                    Text("Stark uses Touch ID or your Mac password through Apple's LocalAuthentication prompt. Face matching stays local to this Mac.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                settingsCard(title: "Camera", systemImage: "camera") {
                    if model.cameras.isEmpty {
                        Text("No camera detected")
                            .foregroundStyle(.secondary)
                        Button("Open Camera Settings") { model.openCameraSettings() }
                            .buttonStyle(.bordered)
                    } else {
                        Picker("Camera", selection: Binding(
                            get: { model.selectedCameraID ?? model.cameras[0].id },
                            set: { model.selectCamera($0) }
                        )) {
                            ForEach(model.cameras) { camera in
                                Text(camera.name).tag(camera.id)
                            }
                        }
                    }
                    Button("Refresh cameras") { model.refreshCameras() }
                        .buttonStyle(.bordered)
                    if model.cameraPermissionNeedsRecovery {
                        Button("Open Camera Settings") { model.openCameraSettings() }
                            .buttonStyle(.bordered)
                    }
                }

                settingsCard(title: "Session", systemImage: "timer") {
                    HStack {
                        Text("Auto-lock after")
                        Spacer()
                        Stepper(
                            "\(model.autoLockMinutes) min",
                            value: Binding(
                                get: { model.autoLockMinutes },
                                set: { model.setAutoLockMinutes($0) }
                            ),
                            in: 1...60
                        )
                        .labelsHidden()
                        Text("\(model.autoLockMinutes) min")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 48, alignment: .trailing)
                    }
                }

                settingsCard(title: "Local face setup", systemImage: "person.crop.circle") {
                    HStack {
                        Text("Saved samples")
                        Spacer()
                        Text("\(model.enrollmentSamples)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Button(role: .destructive) {
                        model.resetEnrollment()
                    } label: {
                        Label("Delete face setup", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(width: 560, height: 500)
        .controlSize(.large)
    }

    private func settingsCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
