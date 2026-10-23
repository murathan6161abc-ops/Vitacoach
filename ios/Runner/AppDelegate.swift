import CoreMotion
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let stepHistory = StepHistoryChannel()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VitaStepHistory") {
      stepHistory.register(with: registrar.messenger())
    }
  }
}

/// Gün gün adım toplamlarını CoreMotion'dan okur. CMPedometer son 7 günü
/// cihazda saklar; uygulama kapalıyken atılan adımlar da gelir.
final class StepHistoryChannel {
  private let pedometer = CMPedometer()

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "vitacoach/step_history", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "dailyTotals" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self, CMPedometer.isStepCountingAvailable() else {
        result(nil)
        return
      }
      let days = (call.arguments as? [String: Any])?["days"] as? Int ?? 7
      self.dailyTotals(days: min(max(days, 1), 7), result: result)
    }
  }

  private func dailyTotals(days: Int, result: @escaping FlutterResult) {
    let calendar = Calendar.current
    let now = Date()
    let today = calendar.startOfDay(for: now)
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"

    let group = DispatchGroup()
    let lock = NSLock()
    var totals = [String: Int]()
    for offset in 0..<days {
      guard let start = calendar.date(byAdding: .day, value: -offset, to: today),
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start)
      else { continue }
      let end = offset == 0 ? now : nextDay
      let key = formatter.string(from: start)
      group.enter()
      pedometer.queryPedometerData(from: start, to: end) { data, _ in
        // İzin yoksa veya veri yoksa gün atlanır; Dart tarafı eksik günleri
        // sensör sayımıyla korur.
        if let steps = data?.numberOfSteps.intValue {
          lock.lock()
          totals[key] = steps
          lock.unlock()
        }
        group.leave()
      }
    }
    group.notify(queue: .main) {
      result(totals.isEmpty ? nil : totals)
    }
  }
}
