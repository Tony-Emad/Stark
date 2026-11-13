import AppKit
@preconcurrency import AVFoundation
import LocalAuthentication
import SwiftUI
import Vision

@main
struct StarkApp: App {
    @NSApplicationDelegateAdaptor(StarkAppDelegate.self) private var appDelegate
    @StateObject private var model = StarkModel()

    var body: some Scene {
        WindowGroup("Stark") {
            StarkNotchView(model: model)
                .frame(width: 380, height: 430)
                .background(NotchWindowConfigurator())
                .onAppear { model.startCamera() }
                .onDisappear { model.stopCamera() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            StarkSettingsView()
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

@MainActor
final class StarkModel: NSObject, ObservableObject {
    @Published var phase: StarkPhase = .idle
    @Published var detail = "Stark keeps the scan local to this Mac."
    @Published var faceConfidence: Float = 0
    @Published var isRunning = false
    @Published var setupStep: StarkSetupStep = .faceScan
    @Published var poseIndex = 0

    let session = AVCaptureSession()
    private let cameraQueue = DispatchQueue(label: "com.stark.camera")
    private var isConfigured = false

    let poses = ["center", "top right", "right", "bottom right", "bottom", "bottom left", "left", "top left", "top"]

    var currentInstruction: String {
        "Tilt your head to the \(poses[min(poseIndex, poses.count - 1)])"
    }

    var setupProgress: Double {
        guard setupStep == .faceScan else { return setupStep == .ready ? 1 : 0.1 }
        return Double(poseIndex + 1) / Double(poses.count)
    }

    func startSetup() {
        setupStep = .faceScan
        poseIndex = 0
        startCamera()
    }

    func advanceSetup() {
        switch setupStep {
        case .welcome:
            startSetup()
        case .faceScan:
            if poseIndex + 1 < poses.count {
                poseIndex += 1
            } else {
                setupStep = .secure
                detail = "Secure Stark with Touch ID or your Mac password."
            }
        case .secure:
            authorizeWithTouchIDOrPassword()
        case .ready:
            NSApp.hide(nil)
        }
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
        cameraQueue.async { [weak self] in
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
                    self.setupStep = .ready
                    self.detail = "Stark is secured on this Mac."
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

            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                phase = .unavailable("No camera found")
                detail = "Connect a camera and try again."
                return
            }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: cameraQueue)
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                phase = .unavailable("Camera output unavailable")
                return
            }
            session.addOutput(output)
            session.commitConfiguration()
            isConfigured = true
        }

        phase = .looking
        detail = "Face presence is detected on-device."
        isRunning = true
        let captureSession = session
        cameraQueue.async { [weak self] in
            captureSession.startRunning()
            _ = self
        }
    }
}

extension StarkModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            let face = (request.results as? [VNFaceObservation])?.first
            let confidence = face?.confidence ?? 0
            let hasFace = face != nil && confidence >= 0.5
            Task { @MainActor in
                guard let self else { return }
                if hasFace {
                    self.faceConfidence = confidence
                    if self.phase != .authorized { self.phase = .faceFound }
                } else if self.phase != .authorized {
                    self.phase = .looking
                    self.faceConfidence = 0
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }
}

struct StarkNotchView: View {
    @ObservedObject var model: StarkModel

    var body: some View {
        ZStack {
            NotchPanelShape()
                .fill(Color.black)
                .shadow(color: .black.opacity(0.4), radius: 24, y: 12)

            VStack(spacing: 0) {
                HStack {
                    Text("STARK SETUP")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2.4)
                        .foregroundStyle(.white.opacity(0.74))
                    Spacer()
                    Button {
                        model.stopCamera()
                        NSApp.hide(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 17)

                Spacer(minLength: 8)
                content
                Spacer(minLength: 12)
                progressDots.padding(.bottom, 22)
            }
            .padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
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
                Text(model.phase == .faceFound ? "Face found — capture this position" : "Keep your face inside the circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.52))
                primaryButton("Capture position", action: model.advanceSetup)
                    .opacity(model.phase == .faceFound ? 1 : 0.55)
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

    private var logo: some View {
        Image("StarkLogo", bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: 90, height: 90)
            .clipShape(Circle())
    }

    private var faceScanner: some View {
        ZStack {
            TickRing(progress: model.setupProgress).frame(width: 220, height: 220)
            CameraPreview(session: model.session)
                .frame(width: 154, height: 154)
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

    var body: some View {
        ZStack {
            ForEach(0..<48, id: \.self) { index in
                Capsule()
                    .fill(index < Int(progress * 48) ? Color.blue : Color.white.opacity(0.78))
                    .frame(width: 2.4, height: index % 4 == 0 ? 12 : 8)
                    .offset(y: -96)
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
            if let window = view.window { StarkWindowController.configure(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window { StarkWindowController.configure(window) }
    }
}

@MainActor
enum StarkWindowController {
    static let panelSize = NSSize(width: 380, height: 430)

    static func configureExistingWindow() {
        if let window = NSApp.windows.first(where: { $0.contentView != nil }) { configure(window) }
    }

    static func configure(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = false
        window.setContentSize(panelSize)
        position(window)
        window.orderFrontRegardless()
    }

    private static func position(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let origin = CGPoint(x: screen.frame.midX - panelSize.width / 2, y: screen.frame.maxY - panelSize.height)
        window.setFrame(NSRect(origin: origin, size: panelSize), display: true, animate: false)
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.previewLayer.session = session
    }
}

final class PreviewView: NSView {
    override func makeBackingLayer() -> CALayer { AVCaptureVideoPreviewLayer() }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct StarkSettingsView: View {
    var body: some View {
        Form {
            Section("Security") {
                Text("Stark uses Apple's public LocalAuthentication prompt for Touch ID or Mac password authorization. Face matching and system-login integration are separate future phases.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("Permissions") {
                Text("Camera access is required for local face detection. Accessibility permission will only be needed for an explicitly opted-in password-entry bridge in a later phase.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(width: 480, height: 280)
    }
}
