import UIKit
import Flutter
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    private let channelName = "com.teacher.teacher_recorder/recording"
    private var replayKitHandler: ReplayKitHandler?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        replayKitHandler = ReplayKitHandler()

        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "startRecording":
                guard let args = call.arguments as? [String: Any],
                      let outputPath = args["outputPath"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "outputPath required", details: nil))
                    return
                }
                // Keep audio session active so iOS doesn't suspend the app.
                self.activateAudioSession()
                self.replayKitHandler?.startRecording(outputPath: outputPath, result: result)

            case "stopRecording":
                self.replayKitHandler?.stopRecording(result: result)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default,
                                                          options: [.mixWithOthers, .allowBluetooth])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
