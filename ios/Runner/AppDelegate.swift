import Flutter
import UIKit
import os.log

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register VPN plugin for MethodChannel bridge
        if #available(iOS 14.0, *) {
            let registrar = self.registrar(forPlugin: "VpnPlugin")!
            VpnPlugin.register(with: registrar)
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
