import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from install_tasks import patch_swift_delegate


class SwiftDelegateTests(unittest.TestCase):
    def test_launch_override_with_both_registrars(self):
        for registrar in ['self', 'engineBridge.pluginRegistry']:
            with self.subTest(registrar=registrar):
                text = '''import Flutter
import UIKit
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
 override func application(
 _ application: UIApplication,
 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
 ) -> Bool {
 GeneratedPluginRegistrant.register(with: REGISTRAR)
 return super.application(application, didFinishLaunchingWithOptions: launchOptions)
 }
}'''.replace('REGISTRAR', registrar)
                patched = patch_swift_delegate(text)
                self.assertEqual(patched, patch_swift_delegate(patched))
                self.assertEqual(patched.count('UNUserNotificationCenter.current().delegate'), 1)
                self.assertIn('register(with: ' + registrar + ')', patched)

    def test_implicit_engine_without_application_override(self):
        text = '''import Flutter
import UIKit
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
 func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
 GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
 }
}'''
        patched = patch_swift_delegate(text)
        self.assertIn('override func application(', patched)
        self.assertEqual(patched, patch_swift_delegate(patched))

    def test_unknown_custom_delegate_fails_before_write(self):
        with self.assertRaises(ValueError):
            patch_swift_delegate('custom implementation')
