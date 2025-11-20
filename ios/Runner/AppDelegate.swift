import UIKit
import Flutter
import BackgroundTasks
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let locationManager = CLLocationManager()
  private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
  private var locationTimer: Timer?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Method channel setup
    setupMethodChannel()
    
    // Location manager setup
    setupLocationManager()
    
    // Background task'ları planla
    scheduleBackgroundTasks()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupMethodChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    let channel = FlutterMethodChannel(
      name: "com.quickcity.mobile/background",
      binaryMessenger: controller.binaryMessenger
    )
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "startBackgroundLocationTracking":
        self?.startBackgroundLocationTracking()
        result(nil)
      case "stopBackgroundLocationTracking":
        self?.stopBackgroundLocationTracking()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func scheduleBackgroundTasks() {
    // Background task'ları geçici olarak devre dışı bırak
    print("🍎 iOS: Background task'lar geçici olarak devre dışı")
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    print("🍎 iOS: Uygulama arka plana alındı")
  }
  
  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    print("🍎 iOS: Uygulama ön plana alındı")
  }
  
  private func setupLocationManager() {
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
  }
  
  private func startBackgroundLocationTracking() {
    print("🍎 iOS Native: Background location tracking başlatılıyor...")
    
    // Background task başlat (düzgün şekilde)
    backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "LocationTracking") {
      print("🍎 iOS Native: Background task süresi doldu")
      self.endBackgroundTask()
    }
    
    // Location tracking başlat
    locationManager.startUpdatingLocation()
    
    // Timer başlat (her 30 saniyede konum gönder)
    locationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
      self.sendLocationToAPI()
    }
    
    print("🍎 iOS Native: Background location tracking aktif")
  }
  
  private func stopBackgroundLocationTracking() {
    print("🍎 iOS Native: Background location tracking durduruluyor...")
    
    locationManager.stopUpdatingLocation()
    locationTimer?.invalidate()
    locationTimer = nil
    endBackgroundTask()
    
    print("🍎 iOS Native: Background location tracking durduruldu")
  }
  
  private func endBackgroundTask() {
    if backgroundTaskID != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTaskID)
      backgroundTaskID = .invalid
    }
  }
  
  private func sendLocationToAPI() {
    guard let location = locationManager.location else {
      print("🍎 iOS Native: Konum bilgisi yok")
      return
    }
    
    print("🍎 iOS Native: Konum gönderiliyor - \(location.coordinate.latitude), \(location.coordinate.longitude)")
    
    // UserDefaults'tan session bilgilerini al
    guard let sessionData = UserDefaults.standard.string(forKey: "active_work_session"),
          let data = sessionData.data(using: .utf8),
          let session = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let sessionInfo = session["session"] as? [String: Any],
          let sessionId = sessionInfo["id"] as? String,
          let token = session["token"] as? String else {
      print("🍎 iOS Native: Session bilgisi bulunamadı - Debug için konum kaydediliyor")
      
      // Debug için konumu dosyaya kaydet
      let debugLocation = "\(Date()): \(location.coordinate.latitude), \(location.coordinate.longitude)\n"
      if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let debugFile = documentsPath.appendingPathComponent("gps_debug.log")
        if let data = debugLocation.data(using: .utf8) {
          if FileManager.default.fileExists(atPath: debugFile.path) {
            var existingData = try? Data(contentsOf: debugFile)
            existingData?.append(data)
            try? existingData?.write(to: debugFile)
          } else {
            try? data.write(to: debugFile)
          }
        }
      }
      return
    }
    
    // Konum verisi hazırla
    let locationData: [String: Any] = [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracy": location.horizontalAccuracy,
      "timestamp": ISO8601DateFormatter().string(from: location.timestamp),
      "altitude": location.altitude,
      "speed": location.speed,
      "heading": location.course
    ]
    
    // API'ye gönder
    guard let url = URL(string: "http://212.91.237.42/api/work-sessions/\(sessionId)/location-update") else {
      print("🍎 iOS Native: Geçersiz URL")
      return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: locationData)
    } catch {
      print("🍎 iOS Native: JSON serialization hatası: \(error)")
      return
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        print("🍎 iOS Native: API hatası: \(error)")
      } else if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode == 200 {
          print("🍎 iOS Native: Konum başarıyla gönderildi")
        } else {
          print("🍎 iOS Native: API hatası - Status: \(httpResponse.statusCode)")
        }
      }
    }.resume()
  }
}

extension AppDelegate: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    print("🍎 iOS Native: Konum güncellendi - \(location.coordinate.latitude), \(location.coordinate.longitude)")
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("🍎 iOS Native: Konum hatası: \(error)")
  }
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .authorizedAlways:
      print("🍎 iOS Native: Konum izni verildi (Always)")
    case .authorizedWhenInUse:
      print("🍎 iOS Native: Konum izni verildi (WhenInUse)")
    case .denied, .restricted:
      print("🍎 iOS Native: Konum izni reddedildi")
    case .notDetermined:
      print("🍎 iOS Native: Konum izni belirlenmedi")
    @unknown default:
      print("🍎 iOS Native: Bilinmeyen konum izni durumu")
    }
  }
}