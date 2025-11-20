import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Helper method to get text based on locale
  String _getText(Map<String, String> translations) {
    switch (locale.languageCode) {
      case 'tr':
        return translations['tr'] ?? translations['en'] ?? '';
      case 'de':
        return translations['de'] ?? translations['en'] ?? '';
      case 'en':
      default:
        return translations['en'] ?? '';
    }
  }

  // String getters - Auto-generated from ARB files
  String get accessDenied => _getText({
    'en': 'accessDenied',
    'tr': 'Erişim reddedildi',
    'de': 'Zugriff verweigert',
  });
  String get activeSessionWarning => _getText({
    'en': 'activeSessionWarning',
    'tr': 'Zaten aktif bir iş oturumunuz var.',
    'de': 'Sie haben bereits eine aktive Arbeitssitzung.',
  });
  String get activeWorkSessionFound => _getText({
    'en': 'Active work session found',
    'tr': 'Aktif İş Oturumu Var',
    'de': 'Aktive Arbeitssitzung Gefunden',
  });
  String get actualTime => _getText({
    'en': 'actualTime',
    'tr': 'Gerçek süre',
    'de': 'Tatsächliche Zeit',
  });
  String get add => _getText({'en': 'Add', 'tr': 'Add', 'de': 'Add'});
  String get addNote =>
      _getText({'en': 'addNote', 'tr': 'Not Ekle', 'de': 'Notiz hinzufügen'});
  String get address =>
      _getText({'en': 'address', 'tr': 'Adres', 'de': 'Adresse'});
  String get adminNotes => _getText({
    'en': 'Admin Notes',
    'tr': 'Admin Notları',
    'de': 'Admin-Notizen',
  });
  String get allClusters => _getText({
    'en': 'allClusters',
    'tr': 'Tüm Cluster\'lar',
    'de': 'Alle Cluster',
  });
  String get allLocationsCompleted => _getText({
    'en': 'allLocationsCompleted',
    'tr': 'Tüm lokasyonlar tamamlandı!',
    'de': 'Alle Standorte abgeschlossen!',
  });
  String get appSubtitle => _getText({
    'en': 'appSubtitle',
    'tr': 'Kış Hizmetleri Yönetim Sistemi',
    'de': 'Winterdienst-Managementsystem',
  });
  String get appTitle => _getText({
    'en': 'QuickCity Mobile',
    'tr': 'QuickCity Winterdienst',
    'de': 'QuickCity Winterdienst',
  });
  String get approved =>
      _getText({'en': 'Approved', 'tr': 'Approved', 'de': 'Approved'});
  String get arrivedAtLocation => _getText({
    'en': 'arrivedAtLocation',
    'tr': 'Lokasyona Ulaştınız!',
    'de': 'Sie sind am Standort angekommen!',
  });
  String get assignedAt => _getText({
    'en': 'assignedAt',
    'tr': 'Atanma Tarihi',
    'de': 'Zugewiesen am',
  });
  String get assignedLocationsCount => _getText({
    'en': 'assignedLocationsCount',
    'tr': 'Atanmış lokasyon sayısı: @count',
    'de': 'Zugewiesene Standorte: @count',
  });
  String get atLeastOneImageRequired => _getText({
    'en': 'atLeastOneImageRequired',
    'tr': 'En az 1 fotoğraf seçmelisiniz',
    'de': 'Sie müssen mindestens 1 Bild auswählen',
  });
  String get attachments =>
      _getText({'en': 'attachments', 'tr': 'Ekler', 'de': 'Anhänge'});
  String get attention =>
      _getText({'en': 'attention', 'tr': 'Dikkat', 'de': 'Achtung'});
  String get authenticationError => _getText({
    'en': 'authenticationError',
    'tr': 'Kimlik doğrulama hatası',
    'de': 'Authentifizierungsfehler',
  });
  String get autoCheckIn => _getText({
    'en': 'autoCheckIn',
    'tr': 'Otomatik Check-In',
    'de': 'Auto Check-In',
  });
  String get autoCheckInCheckOut => _getText({
    'en': 'autoCheckInCheckOut',
    'tr': 'Otomatik Check-In/Out',
    'de': 'Auto Check-In/Out',
  });
  String get autoCheckInDescription => _getText({
    'en': 'autoCheckInDescription',
    'tr':
        'Lokasyona gelip gittiğinizde otomatik olarak check-in ve check-out yapılır',
    'de':
        'Automatisches Check-in und Check-out beim Ankommen und Verlassen von Standorten',
  });
  String get autoCheckInEnabled => _getText({
    'en': 'autoCheckInEnabled',
    'tr': 'Otomatik Check-In Aktif',
    'de': 'Auto Check-In aktiviert',
  });
  String get autoCheckInMessage => _getText({
    'en': 'autoCheckInMessage',
    'tr':
        '@minutes dakikadır bu lokasyondasınız. Otomatik olarak check-in yapıldı.',
    'de':
        'Sie sind seit @minutes Minuten an diesem Standort. Automatisch eingecheckt.',
  });
  String get autoCheckInNotification => _getText({
    'en': 'autoCheckInNotification',
    'tr': 'Otomatik Check-In',
    'de': 'Auto Check-In',
  });
  String get autoCheckOut => _getText({
    'en': 'autoCheckOut',
    'tr': 'Otomatik Check-Out',
    'de': 'Auto Check-Out',
  });
  String get autoCheckOutEnabled => _getText({
    'en': 'autoCheckOutEnabled',
    'tr': 'Otomatik Check-Out Aktif',
    'de': 'Auto Check-Out aktiviert',
  });
  String get autoCheckOutMessage => _getText({
    'en': 'autoCheckOutMessage',
    'tr':
        '@minutes dakikadır lokasyondan uzaktasınız. Otomatik olarak check-out yapıldı.',
    'de':
        'Sie sind seit @minutes Minuten vom Standort entfernt. Automatisch ausgecheckt.',
  });
  String get autoCheckOutNotification => _getText({
    'en': 'autoCheckOutNotification',
    'tr': 'Otomatik Check-Out',
    'de': 'Auto Check-Out',
  });
  String get back => _getText({'en': 'Back', 'tr': 'Back', 'de': 'Back'});
  String get beforeCheckIn => _getText({
    'en': 'beforeCheckIn',
    'tr': 'Önce iş oturumu başlatmalısınız!',
    'de': 'Sie müssen zuerst eine Arbeitssitzung starten!',
  });
  String get camera =>
      _getText({'en': 'Camera', 'tr': 'Camera', 'de': 'Camera'});
  String get cameraError => _getText({
    'en': 'Camera error: @error',
    'tr': 'Kamera hatası',
    'de': 'Kamera-Fehler',
  });
  String get cameraPermissionRequired => _getText({
    'en': 'Camera permission is required',
    'tr': 'Kamera izni gerekli',
    'de': 'Kamera-Berechtigung erforderlich',
  });
  String get canStopAnytime => _getText({
    'en': 'canStopAnytime',
    'tr': 'İstediğiniz zaman durdurabilirsiniz',
    'de': 'Sie können jederzeit stoppen',
  });
  String get cancel =>
      _getText({'en': 'Cancel', 'tr': 'İptal', 'de': 'Abbrechen'});
  String get cancelled =>
      _getText({'en': 'cancelled', 'tr': 'İptal Edildi', 'de': 'Abgebrochen'});
  String get cannotEndWorkSession => _getText({
    'en': 'cannotEndWorkSession',
    'tr': 'İş Oturumu Bitirilemez',
    'de': 'Arbeitssitzung Kann Nicht Beendet Werden',
  });
  String get carModeAutoSelected => _getText({
    'en': 'carModeAutoSelected',
    'tr': 'Araç modu otomatik seçili',
    'de': 'Automodus automatisch ausgewählt',
  });
  String get certificateError => _getText({
    'en': 'certificateError',
    'tr': 'Sertifika hatası',
    'de': 'Zertifikatsfehler',
  });
  String get changeStatus => _getText({
    'en': 'changeStatus',
    'tr': 'Durum Değiştir',
    'de': 'Status ändern',
  });
  String get checkIn =>
      _getText({'en': 'checkIn', 'tr': 'Check-in', 'de': 'Check-in'});
  String get checkInError => _getText({
    'en': 'checkInError',
    'tr': 'Check-in hatası',
    'de': 'Check-in Fehler',
  });
  String get checkInFailed => _getText({
    'en': 'checkInFailed',
    'tr': 'Check-in başarısız',
    'de': 'Check-in fehlgeschlagen',
  });
  String get checkInSuccess => _getText({
    'en': 'checkInSuccess',
    'tr': 'Check-in başarılı',
    'de': 'Check-in erfolgreich',
  });
  String get checkInToLocation => _getText({
    'en': 'checkInToLocation',
    'tr': 'Lokasyonda check-in yapın',
    'de': 'Am Standort einchecken',
  });
  String get checkOut =>
      _getText({'en': 'checkOut', 'tr': 'Check-out', 'de': 'Check-out'});
  String get checkOutError => _getText({
    'en': 'checkOutError',
    'tr': 'Check-out hatası',
    'de': 'Check-out Fehler',
  });
  String get checkOutFailed => _getText({
    'en': 'checkOutFailed',
    'tr': 'Check-out başarısız',
    'de': 'Check-out fehlgeschlagen',
  });
  String get checkOutSuccess => _getText({
    'en': 'checkOutSuccess',
    'tr': 'Check-out başarılı',
    'de': 'Check-out erfolgreich',
  });
  String get chooseFromGallery => _getText({
    'en': 'chooseFromGallery',
    'tr': 'Galeriden Seç',
    'de': 'Aus Galerie wählen',
  });
  String get city => _getText({'en': 'city', 'tr': 'Şehir', 'de': 'Stadt'});
  String get clearFilters => _getText({
    'en': 'clearFilters',
    'tr': 'Filtreleri Temizle',
    'de': 'Filter löschen',
  });
  String get close =>
      _getText({'en': 'Close', 'tr': 'Kapat', 'de': 'Schließen'});
  String get cluster =>
      _getText({'en': 'cluster', 'tr': 'Cluster', 'de': 'Cluster'});
  String get clusterLabel => _getText({
    'en': 'clusterLabel',
    'tr': 'Cluster Etiketi',
    'de': 'Cluster-Etikett',
  });
  String get complete =>
      _getText({'en': 'Complete', 'tr': 'Tamamla', 'de': 'Abschließen'});
  String get completeAndCheckout => _getText({
    'en': 'completeAndCheckout',
    'tr': 'İşi tamamlayıp check-out yapın',
    'de': 'Arbeit abschließen und auschecken',
  });
  String get completed =>
      _getText({'en': 'Completed', 'tr': 'Tamamlanan', 'de': 'Abgeschlossen'});
  String get completedArea => _getText({
    'en': 'completedArea',
    'tr': 'Tamamlanan Alan',
    'de': 'Abgeschlossene Fläche',
  });
  String get completedLocations => _getText({
    'en': 'completedLocations',
    'tr': 'Tamamlanan Lokasyon',
    'de': 'Abgeschlossene Standorte',
  });
  String get completedLocationsList => _getText({
    'en': 'completedLocationsList',
    'tr': 'Tamamlanan Lokasyonlar:',
    'de': 'Abgeschlossene Standorte:',
  });
  String get completingWork => _getText({
    'en': 'completingWork',
    'tr': 'İşi Tamamlıyorsunuz',
    'de': 'Arbeit abschließen',
  });
  String get completionRate => _getText({
    'en': 'completionRate',
    'tr': 'Tamamlanma Oranı',
    'de': 'Abschlussrate',
  });
  String get congratulations => _getText({
    'en': 'congratulations',
    'tr': '🎉 Tebrikler!',
    'de': '🎉 Glückwunsch!',
  });
  String get connectionError => _getText({
    'en': 'connectionError',
    'tr': 'Bağlantı hatası',
    'de': 'Verbindungsfehler',
  });
  String get connectionTimeout => _getText({
    'en': 'connectionTimeout',
    'tr': 'Bağlantı zaman aşımı',
    'de': 'Verbindungszeitüberschreitung',
  });
  String get continueAction =>
      _getText({'en': 'continueAction', 'tr': 'Devam Et', 'de': 'Fortfahren'});
  String get continueAnyway => _getText({
    'en': 'continueAnyway',
    'tr': 'Yine de iş oturumunu bitirmek istiyor musunuz?',
    'de': 'Möchten Sie die Arbeitssitzung trotzdem beenden?',
  });
  String get continueQuestion => _getText({
    'en': 'Do you want to continue?',
    'tr': 'Devam etmek istiyor musunuz?',
    'de': 'Möchten Sie fortfahren?',
  });
  String get continueText =>
      _getText({'en': 'Continue', 'tr': 'Continue', 'de': 'Continue'});
  String get continueWork =>
      _getText({'en': 'Continue Work', 'tr': 'Devam Et', 'de': 'Fortfahren'});
  String get continueWorkSession => _getText({
    'en': 'continueWorkSession',
    'tr': 'İş oturumuna devam ediliyor! GPS aktif.',
    'de': 'Arbeitssitzung wird fortgesetzt! GPS aktiv.',
  });
  String get coordinates => _getText({
    'en': 'coordinates',
    'tr': 'Koordinatlar:',
    'de': 'Koordinaten:',
  });
  String get coordinatesCopied => _getText({
    'en': 'coordinatesCopied',
    'tr': 'Koordinatlar panoya kopyalandı',
    'de': 'Koordinaten in Zwischenablage kopiert',
  });
  String get copyCoordinates => _getText({
    'en': 'copyCoordinates',
    'tr': 'Koordinatları Kopyala',
    'de': 'Koordinaten kopieren',
  });
  String get critical =>
      _getText({'en': 'critical', 'tr': 'Kritik', 'de': 'Kritisch'});
  String get currentTime => _getText({
    'en': 'currentTime',
    'tr': 'Şimdi: @time',
    'de': 'Jetzt: @time',
  });
  String get customer =>
      _getText({'en': 'customer', 'tr': 'Müşteri', 'de': 'Kunde'});
  String get customerName =>
      _getText({'en': 'customerName', 'tr': 'Müşteri Adı', 'de': 'Kundenname'});
  String get dailyProgress => _getText({
    'en': 'dailyProgress',
    'tr': 'Günlük İlerleme',
    'de': 'Tagesfortschritt',
  });
  String get dailyReport => _getText({
    'en': 'dailyReport',
    'tr': 'Günlük Rapor',
    'de': 'Tagesbericht',
  });
  String get date => _getText({'en': 'date', 'tr': 'Tarih', 'de': 'Datum'});
  String get dateTime => _getText({
    'en': 'dateTime',
    'tr': '📅 Tarih/Saat',
    'de': '📅 Datum/Zeit',
  });
  String get delete =>
      _getText({'en': 'Delete', 'tr': 'Delete', 'de': 'Delete'});
  String get departureDistance => _getText({
    'en': 'departureDistance',
    'tr': 'Uzaklık Mesafesi',
    'de': 'Abfahrtsentfernung',
  });
  String get departureTime => _getText({
    'en': 'departureTime',
    'tr': 'Ayrılma Süresi',
    'de': 'Abfahrtszeit',
  });
  String get description =>
      _getText({'en': 'description', 'tr': 'Açıklama', 'de': 'Beschreibung'});
  String get detail =>
      _getText({'en': 'detail', 'tr': 'Detay', 'de': 'Detail'});
  String get details =>
      _getText({'en': 'details', 'tr': 'Detaylar:', 'de': 'Details:'});
  String get device =>
      _getText({'en': 'device', 'tr': '📱 Cihaz', 'de': '📱 Gerät'});
  String get distance =>
      _getText({'en': 'distance', 'tr': 'Mesafe', 'de': 'Entfernung'});
  String get doYouWantToStart => _getText({
    'en': 'doYouWantToStart',
    'tr': 'İşe başlamak istiyor musunuz?',
    'de': 'Möchten Sie mit der Arbeit beginnen?',
  });
  String get doYouWantToStartWork => _getText({
    'en': 'doYouWantToStartWork',
    'tr': 'İşe başlamak istiyor musunuz?',
    'de': 'Möchten Sie mit der Arbeit beginnen?',
  });
  String get done => _getText({'en': 'Done', 'tr': 'Done', 'de': 'Done'});
  String get dragToReorder => _getText({
    'en': 'dragToReorder',
    'tr': 'Sürükle Bırak',
    'de': 'Ziehen & Ablegen',
  });
  String get duration =>
      _getText({'en': 'duration', 'tr': '@duration dk', 'de': '@duration Min'});
  String get dwellTime => _getText({
    'en': 'dwellTime',
    'tr': 'Bekleme Süresi',
    'de': 'Verweilzeit',
  });
  String get edit =>
      _getText({'en': 'Edit', 'tr': 'Düzenle', 'de': 'Bearbeiten'});
  String get email =>
      _getText({'en': 'email', 'tr': 'E-posta', 'de': 'E-Mail'});
  String get emailRequired => _getText({
    'en': 'emailRequired',
    'tr': 'E-posta adresi gerekli',
    'de': 'E-Mail-Adresse ist erforderlich',
  });
  String get endWork =>
      _getText({'en': 'endWork', 'tr': 'İşi Bitir', 'de': 'Arbeit beenden'});
  String get endWorkSession => _getText({
    'en': 'endWorkSession',
    'tr': 'İş Oturumu Bitir',
    'de': 'Arbeitssitzung beenden',
  });
  String get endWorkSessionTitle => _getText({
    'en': 'endWorkSessionTitle',
    'tr': 'İş Oturumu Bitir',
    'de': 'Arbeitssitzung Beenden',
  });
  String get english =>
      _getText({'en': 'english', 'tr': 'English', 'de': 'English'});
  String get error =>
      _getText({'en': 'Error', 'tr': 'Hata: @error', 'de': 'Fehler: @error'});
  String get errorDetails => _getText({
    'en': 'errorDetails',
    'tr': 'Hata Detayları',
    'de': 'Fehlerdetails',
  });
  String get estimatedFinish =>
      _getText({'en': 'estimatedFinish', 'tr': 'Bitiş', 'de': 'Ende'});
  String get estimatedTime => _getText({
    'en': 'estimatedTime',
    'tr': 'Tahmini Süre',
    'de': 'Geschätzte Zeit',
  });
  String get example => _getText({
    'en': 'example',
    'tr': 'Örn: Buzlanma var, tuz uygulandı',
    'de': 'Z.B.: Vereisung vorhanden, Salz aufgetragen',
  });
  String get exit => _getText({'en': 'exit', 'tr': 'Çık', 'de': 'Beenden'});
  String get exitApp =>
      _getText({'en': 'exitApp', 'tr': 'Uygulamadan Çık', 'de': 'App beenden'});
  String get exitAppConfirmation => _getText({
    'en': 'exitAppConfirmation',
    'tr': 'Uygulamadan çıkmak istediğinize emin misiniz?',
    'de': 'Sind Sie sicher, dass Sie die App beenden möchten?',
  });
  String get exitAppWarning => _getText({
    'en': 'exitAppWarning',
    'tr': 'Aktif iş oturumunuz varsa, bilgileriniz kaydedilecektir.',
    'de':
        'Wenn Sie eine aktive Arbeitssitzung haben, werden Ihre Informationen gespeichert.',
  });
  String get filter =>
      _getText({'en': 'Filter', 'tr': 'Filtrele', 'de': 'Filter'});
  String get filterByCluster => _getText({
    'en': 'filterByCluster',
    'tr': 'Cluster\'a Göre Filtrele',
    'de': 'Nach Cluster filtern',
  });
  String get finish =>
      _getText({'en': 'finish', 'tr': 'Bitir', 'de': 'Beenden'});
  String get forTestOrCancel => _getText({
    'en': 'forTestOrCancel',
    'tr': '(Test veya iptal durumları için)',
    'de': '(Für Test- oder Abbruchsituationen)',
  });
  String get gallery =>
      _getText({'en': 'Gallery', 'tr': 'Gallery', 'de': 'Gallery'});
  String get galleryError => _getText({
    'en': 'Gallery error: @error',
    'tr': 'Galeri hatası',
    'de': 'Galerie-Fehler',
  });
  String get gehwege1 =>
      _getText({'en': 'gehwege1', 'tr': 'Gehwege 1m', 'de': 'Gehwege 1m'});
  String get gehwege15 =>
      _getText({'en': 'gehwege15', 'tr': 'Gehwege 1.5m', 'de': 'Gehwege 1,5m'});
  String get german =>
      _getText({'en': 'german', 'tr': 'Deutsch', 'de': 'Deutsch'});
  String get getAccountInfo => _getText({
    'en': 'getAccountInfo',
    'tr': 'Sistem yöneticinizden hesap bilgilerinizi alın',
    'de':
        'Holen Sie sich Ihre Kontoinformationen von Ihrem Systemadministrator',
  });
  String get go => _getText({'en': 'go', 'tr': 'Git', 'de': 'Los'});
  String get goToAtLeastOneLocation => _getText({
    'en': 'goToAtLeastOneLocation',
    'tr': 'En az 1 lokasyona gidin',
    'de': 'Zu mindestens 1 Standort gehen',
  });
  String get googleMapsError => _getText({
    'en': 'googleMapsError',
    'tr': 'Google Maps açılamadı',
    'de': 'Google Maps konnte nicht geöffnet werden',
  });
  String get gpsTracking => _getText({
    'en': 'gpsTracking',
    'tr': 'GPS takibi açılacak',
    'de': 'GPS-Tracking wird aktiviert',
  });
  String get gpsTrackingEnabled => _getText({
    'en': 'gpsTrackingEnabled',
    'tr': 'GPS takibi açılacak',
    'de': 'GPS-Tracking wird aktiviert',
  });
  String get gpsWillBeActive => _getText({
    'en': 'gpsWillBeActive',
    'tr': 'GPS takibi açılacak',
    'de': 'GPS-Tracking wird aktiviert',
  });
  String get handreinigung => _getText({
    'en': 'handreinigung',
    'tr': 'Manuel Temizlik',
    'de': 'Manuelle Reinigung',
  });
  String get high => _getText({'en': 'high', 'tr': 'Yüksek', 'de': 'Hoch'});
  String get home =>
      _getText({'en': 'Home', 'tr': 'Ana Sayfa', 'de': 'Startseite'});
  String get hours => _getText({'en': 'hours', 'tr': 'sa', 'de': 'Std'});
  String get hoursMinutes => _getText({
    'en': 'hoursMinutes',
    'tr': '@hours s @mins dk',
    'de': '@hours Std @mins Min',
  });
  String get ifWorkCancelled => _getText({
    'en': 'ifWorkCancelled',
    'tr':
        'Eğer iş iptal olduysa (kar yağmadı vb.) lütfen yöneticinizle iletişime geçin.',
    'de':
        'Wenn die Arbeit abgesagt wurde (kein Schnee usw.), kontaktieren Sie bitte Ihren Vorgesetzten.',
  });
  String get images =>
      _getText({'en': 'images', 'tr': 'Fotoğraflar', 'de': 'Bilder'});
  String get imagesHint => _getText({
    'en': 'imagesHint',
    'tr': 'En az 1, en fazla 5 fotoğraf seçin',
    'de': 'Wählen Sie mindestens 1, maximal 5 Bilder',
  });
  String get inProgress =>
      _getText({'en': 'inProgress', 'tr': 'İşlemde', 'de': 'In Bearbeitung'});
  String get incomplete =>
      _getText({'en': 'Incomplete', 'tr': 'Incomplete', 'de': 'Incomplete'});
  String get isRouted =>
      _getText({'en': 'isRouted', 'tr': 'Rotalanmış', 'de': 'Ist geroutet'});
  String get issueDescriptionHint => _getText({
    'en': 'issueDescriptionHint',
    'tr': 'Sorun hakkında detaylı bilgi (opsiyonel)',
    'de': 'Detaillierte Informationen zum Problem (optional)',
  });
  String get issueDetail => _getText({
    'en': 'issueDetail',
    'tr': 'Sorun Detayı',
    'de': 'Problem-Details',
  });
  String get issueReportError => _getText({
    'en': 'issueReportError',
    'tr': '❌ Sorun bildirme hatası: @error',
    'de': '❌ Problem-Meldungsfehler: @error',
  });
  String get issueReportFailed => _getText({
    'en': 'issueReportFailed',
    'tr': 'Sorun bildirilemedi',
    'de': 'Problem konnte nicht gemeldet werden',
  });
  String get issueReportedSuccessfully => _getText({
    'en': 'issueReportedSuccessfully',
    'tr': 'Sorun başarıyla bildirildi',
    'de': 'Problem erfolgreich gemeldet',
  });
  String get issueSavedOffline => _getText({
    'en': 'issueSavedOffline',
    'tr': '✅ Sorun offline kaydedildi: @id',
    'de': '✅ Problem offline gespeichert: @id',
  });
  String get issueTitle => _getText({
    'en': 'issueTitle',
    'tr': 'Sorun Başlığı',
    'de': 'Problem-Titel',
  });
  String get issueTitleHint => _getText({
    'en': 'issueTitleHint',
    'tr': 'Sorunun kısa açıklaması',
    'de': 'Kurze Beschreibung des Problems',
  });
  String get issueTitleRequired => _getText({
    'en': 'issueTitleRequired',
    'tr': 'Sorun başlığı gerekli',
    'de': 'Problem-Titel ist erforderlich',
  });
  String get issues =>
      _getText({'en': 'Issues', 'tr': 'Issues', 'de': 'Issues'});
  String get issuesLoadFailed => _getText({
    'en': 'Failed to load issues',
    'tr': 'Sorunlar yüklenemedi',
    'de': 'Probleme konnten nicht geladen werden',
  });
  String get addressNotAvailable => _getText({
    'en': 'Address not available',
    'tr': 'Adres bilgisi yok',
    'de': 'Adresse nicht verfügbar',
  });
  String get hasAdminNotes => _getText({
    'en': 'Has Admin Notes',
    'tr': 'Admin Notu Var',
    'de': 'Admin-Notiz vorhanden',
  });
  String get language =>
      _getText({'en': 'language', 'tr': 'Dil', 'de': 'Sprache'});
  String get latitude =>
      _getText({'en': 'latitude', 'tr': 'Enlem', 'de': 'Breitengrad'});
  String get legend =>
      _getText({'en': 'legend', 'tr': 'Gösterge', 'de': 'Legende'});
  String get loadedFromCache => _getText({
    'en': 'loadedFromCache',
    'tr': 'Cache\'den yüklendi: @count lokasyon',
    'de': 'Aus Cache geladen: @count Standorte',
  });
  String get loading => _getText({
    'en': 'Loading...',
    'tr': 'Yükleniyor...',
    'de': 'Wird geladen...',
  });
  String get location =>
      _getText({'en': 'location', 'tr': '🏢 Lokasyon', 'de': '🏢 Standort'});
  String get locationDetails => _getText({
    'en': 'locationDetails',
    'tr': 'Lokasyon Detayları',
    'de': 'Standortdetails',
  });
  String get locationList => _getText({
    'en': 'locationList',
    'tr': 'Lokasyon Listesi',
    'de': 'Standortliste',
  });
  String get locationLoadingError => _getText({
    'en': 'locationLoadingError',
    'tr': '❌ Lokasyon yükleme hatası: @error',
    'de': '❌ Standort-Ladefehler: @error',
  });
  String get locationNotFound => _getText({
    'en': 'locationNotFound',
    'tr': 'Konum alınamadı: @error',
    'de': 'Standort nicht gefunden: @error',
  });
  String get locationPermissionRequired => _getText({
    'en': 'locationPermissionRequired',
    'tr': 'Konum izni gerekli',
    'de': 'Standortberechtigung erforderlich',
  });
  String get locations =>
      _getText({'en': 'Locations', 'tr': 'Locations', 'de': 'Locations'});
  String get locationsCompleted => _getText({
    'en': 'locationsCompleted',
    'tr': '@completed / @total lokasyon tamamlandı',
    'de': '@completed / @total Standorte abgeschlossen',
  });
  String get locationsFound => _getText({
    'en': 'locationsFound',
    'tr': '@count lokasyon bulundu',
    'de': '@count Standorte gefunden',
  });
  String get locationsList => _getText({
    'en': 'locationsList',
    'tr': 'Lokasyon Listesi',
    'de': 'Standortliste',
  });
  String get locationsLoadFailed => _getText({
    'en': 'Failed to load locations',
    'tr': 'Lokasyonlar yüklenemedi',
    'de': 'Standorte konnten nicht geladen werden',
  });
  String get locationsLoadedFromCache => _getText({
    'en': 'locationsLoadedFromCache',
    'tr': '📦 @count lokasyon cache\'den yüklendi',
    'de': '📦 @count Standorte aus Cache geladen',
  });
  String get locationsNotCompleted => _getText({
    'en': 'locationsNotCompleted',
    'tr': '⚠️ @remaining lokasyon henüz tamamlanmadı',
    'de': '⚠️ @remaining Standorte noch nicht abgeschlossen',
  });
  String get locationsSavedToOffline => _getText({
    'en': 'locationsSavedToOffline',
    'tr': '✅ @count lokasyon offline storage\'a kaydedildi',
    'de': '✅ @count Standorte im Offline-Speicher gespeichert',
  });
  String get locationsSuccessfullyCompleted => _getText({
    'en': 'locationsSuccessfullyCompleted',
    'tr': '@count lokasyon başarıyla tamamlandı',
    'de': '@count Standorte erfolgreich abgeschlossen',
  });
  String get login =>
      _getText({'en': 'Login', 'tr': 'Giriş', 'de': 'Anmelden'});
  String get loginButton =>
      _getText({'en': 'loginButton', 'tr': 'Giriş Yap', 'de': 'Anmelden'});
  String get loginFailed => _getText({
    'en': 'loginFailed',
    'tr': 'Giriş başarısız',
    'de': 'Anmeldung fehlgeschlagen',
  });
  String get loginSuccess => _getText({
    'en': 'loginSuccess',
    'tr': 'Giriş başarılı',
    'de': 'Anmeldung erfolgreich',
  });
  String get logout =>
      _getText({'en': 'Logout', 'tr': 'Çıkış', 'de': 'Abmelden'});
  String get logoutFailed => _getText({
    'en': 'logoutFailed',
    'tr': 'Çıkış başarısız',
    'de': 'Abmeldung fehlgeschlagen',
  });
  String get logoutSuccess => _getText({
    'en': 'logoutSuccess',
    'tr': 'Çıkış başarılı',
    'de': 'Abmeldung erfolgreich',
  });
  String get longitude =>
      _getText({'en': 'longitude', 'tr': 'Boylam', 'de': 'Längengrad'});
  String get low => _getText({'en': 'low', 'tr': 'Düşük', 'de': 'Niedrig'});
  String get m2 => _getText({'en': 'm2', 'tr': 'm²', 'de': 'm²'});
  String get manualCleaning => _getText({
    'en': 'manualCleaning',
    'tr': 'Manuel Temizlik',
    'de': 'Manuelle Reinigung',
  });
  String get manualSortActive => _getText({
    'en': 'manualSortActive',
    'tr': 'Manuel sıralama aktif',
    'de': 'Manuelle Sortierung aktiv',
  });
  String get map => _getText({'en': 'Map', 'tr': 'Harita', 'de': 'Karte'});
  String get mapFeatureComingSoon => _getText({
    'en': 'mapFeatureComingSoon',
    'tr': 'Harita özelliği yakında eklenecek',
    'de': 'Kartenfunktion kommt bald',
  });
  String get maxImagesReached => _getText({
    'en': 'maxImagesReached',
    'tr': 'En fazla 5 fotoğraf seçebilirsiniz',
    'de': 'Sie können maximal 5 Bilder auswählen',
  });
  String get maxPhotosLimit => _getText({
    'en': 'Maximum photos limit reached',
    'tr': 'En fazla 5 fotoğraf seçebilirsiniz',
    'de': 'Sie können bis zu 5 Fotos auswählen',
  });
  String get medium => _getText({'en': 'medium', 'tr': 'Orta', 'de': 'Mittel'});
  String get meters => _getText({'en': 'meters', 'tr': 'm', 'de': 'm'});
  String get minutes =>
      _getText({'en': 'minutes', 'tr': '@minutes dk', 'de': '@minutes Min'});
  String get minutesShort =>
      _getText({'en': 'minutesShort', 'tr': 'dk', 'de': 'Min'});
  String get motivationAlmostDone => _getText({
    'en': 'motivationAlmostDone',
    'tr': 'Neredeyse bitti! Devam et!',
    'de': 'Fast fertig! Weiter so!',
  });
  String get motivationHalfway => _getText({
    'en': 'motivationHalfway',
    'tr': 'Yarıyı geçtin! Harika gidiyorsun!',
    'de': 'Halbzeit! Großartige Arbeit!',
  });
  String get motivationPerfect => _getText({
    'en': 'motivationPerfect',
    'tr': 'Harika! Tüm lokasyonları tamamladın!',
    'de': 'Ausgezeichnet! Alle Standorte abgeschlossen!',
  });
  String get motivationQuarter => _getText({
    'en': 'motivationQuarter',
    'tr': 'Güzel başlangıç! Devam!',
    'de': 'Guter Start! Weiter so!',
  });
  String get motivationStart => _getText({
    'en': 'motivationStart',
    'tr': 'Başlayalım! İyi çalışmalar!',
    'de': 'Los geht\'s! Viel Erfolg!',
  });
  String get mustStartWorkSession => _getText({
    'en': 'mustStartWorkSession',
    'tr': 'Önce iş oturumu başlatmalısınız!',
    'de': 'Sie müssen zuerst eine Arbeitssitzung starten!',
  });
  String get myIssues =>
      _getText({'en': 'myIssues', 'tr': 'Sorunlarım', 'de': 'Meine Probleme'});
  String get myLocation =>
      _getText({'en': 'myLocation', 'tr': 'Konumum', 'de': 'Mein Standort'});
  String get navigate =>
      _getText({'en': 'navigate', 'tr': 'Navigasyon', 'de': 'Navigieren'});
  String get navigateTo => _getText({
    'en': 'navigateTo',
    'tr': 'Navigasyon:',
    'de': 'Navigieren zu:',
  });
  String get navigation =>
      _getText({'en': 'navigation', 'tr': 'Navigasyon', 'de': 'Navigation'});
  String get navigationError => _getText({
    'en': 'navigationError',
    'tr': 'Navigasyon hatası',
    'de': 'Navigationsfehler',
  });
  String get navigationFeatureComingSoon => _getText({
    'en': 'navigationFeatureComingSoon',
    'tr': 'Navigasyon özelliği yakında eklenecek',
    'de': 'Navigationsfunktion kommt bald',
  });
  String get navigationInfo => _getText({
    'en': 'navigationInfo',
    'tr': 'Navigasyon Bilgileri',
    'de': 'Navigationsinformationen',
  });
  String get navigationTip => _getText({
    'en':
        'You can view navigation within the app or open Google Maps in full screen',
    'tr':
        'Uygulama içinde kalarak navigasyonu görüntüleyebilir veya tam ekran için Google Maps\'i açabilirsiniz',
    'de':
        'Sie können die Navigation in der App anzeigen oder Google Maps im Vollbildmodus öffnen',
  });
  String get navigationOpened => _getText({
    'en': 'navigationOpened',
    'tr': 'Google Maps navigasyonu açıldı',
    'de': 'Google Maps Navigation geöffnet',
  });
  String get next => _getText({'en': 'Next', 'tr': 'Next', 'de': 'Next'});
  String get no => _getText({'en': 'No', 'tr': 'Hayır', 'de': 'Nein'});
  String get noActiveSession => _getText({
    'en': 'noActiveSession',
    'tr': 'Aktif iş oturumu yok',
    'de': 'Keine aktive Arbeitssitzung',
  });
  String get noAssignedLocations => _getText({
    'en': 'noAssignedLocations',
    'tr': 'Henüz atanmış lokasyonunuz yok',
    'de': 'Noch keine zugewiesenen Standorte',
  });
  String get noCachedData => _getText({
    'en': 'noCachedData',
    'tr': 'Çevrimdışı mod - Henüz cache\'lenmiş veri yok',
    'de': 'Offline-Modus - Noch keine zwischengespeicherten Daten',
  });
  String get noCheckInMade => _getText({
    'en': 'noCheckInMade',
    'tr': 'Hiç lokasyona check-in yapmadınız',
    'de': 'Sie haben an keinem Standort eingecheckt',
  });
  String get noCheckInYet => _getText({
    'en': 'noCheckInYet',
    'tr': 'Henüz hiçbir lokasyona check-in yapmadınız!',
    'de': 'Sie haben sich noch nicht an einem Standort eingecheckt!',
  });
  String get noCheckInYetBullet => _getText({
    'en': 'noCheckInYetBullet',
    'tr': 'Hiç lokasyona check-in yapmadınız',
    'de': 'Sie haben sich noch an keinem Standort eingecheckt',
  });
  String get noClusterSelected => _getText({
    'en': 'noClusterSelected',
    'tr': 'Cluster seçilmedi',
    'de': 'Kein Cluster ausgewählt',
  });
  String get noIssuesYet => _getText({
    'en': 'noIssuesYet',
    'tr': 'Henüz sorun bildirmediniz',
    'de': 'Noch keine Probleme gemeldet',
  });
  String get noLocationsFound => _getText({
    'en': 'noLocationsFound',
    'tr': 'Arama kriterlerinize uygun lokasyon bulunamadı',
    'de': 'Keine Standorte gefunden, die Ihren Suchkriterien entsprechen',
  });
  String get notFound => _getText({
    'en': 'notFound',
    'tr': 'Sayfa bulunamadı',
    'de': 'Seite nicht gefunden',
  });
  String get notStarted =>
      _getText({'en': 'notStarted', 'tr': 'Başlamadı', 'de': 'Nicht begonnen'});
  String get notStartedYet => _getText({
    'en': 'notStartedYet',
    'tr': 'Henüz hiçbir lokasyona check-in yapmadınız!',
    'de': 'Sie haben sich noch an keinem Standort eingecheckt!',
  });
  String get note => _getText({'en': 'note', 'tr': 'Not', 'de': 'Notiz'});
  String get noteHint => _getText({
    'en': 'noteHint',
    'tr': 'Örn: Buzlanma var, tuz uygulandı',
    'de': 'Z.B: Vereisung erkannt, Salz aufgebracht',
  });
  String get notesOptional => _getText({
    'en': 'notesOptional',
    'tr': 'Not (opsiyonel)',
    'de': 'Notizen (optional)',
  });
  String get now => _getText({'en': 'now', 'tr': 'Şimdi', 'de': 'Jetzt'});
  String get offline =>
      _getText({'en': 'offline', 'tr': 'Çevrimdışı', 'de': 'Offline'});
  String get offlineMode => _getText({
    'en': 'offlineMode',
    'tr': 'Çevrimdışı Mod - Veriler cihazda saklanıyor',
    'de': 'Offline-Modus - Daten auf Gerät gespeichert',
  });
  String get offlineModeLoadingFromCache => _getText({
    'en': 'offlineModeLoadingFromCache',
    'tr': '⚠️ Offline mod - Cache\'den yükleniyor...',
    'de': '⚠️ Offline-Modus - Aus Cache laden...',
  });
  String get offlineModeSavingPending => _getText({
    'en': 'offlineModeSavingPending',
    'tr': '⚠️ Offline mod - Sorun pending olarak kaydediliyor...',
    'de': '⚠️ Offline-Modus - Problem als ausstehend gespeichert...',
  });
  String get offlineSaved => _getText({
    'en': 'offlineSaved',
    'tr':
        'Sorun offline kaydedildi\nİnternet bağlantısı olunca otomatik gönderilecek',
    'de': 'Problem offline gespeichert\nWird automatisch gesendet, wenn online',
  });
  String get ok => _getText({'en': 'OK', 'tr': 'Tamam', 'de': 'OK'});
  String get open => _getText({'en': 'open', 'tr': 'Açık', 'de': 'Offen'});
  String get openInGoogleMaps => _getText({
    'en': 'openInGoogleMaps',
    'tr': 'Google Maps\'te Aç',
    'de': 'In Google Maps öffnen',
  });
  String get chooseNavigationOption => _getText({
    'en': 'Choose a navigation option',
    'tr': 'Navigasyon seçeneği seç',
    'de': 'Navigationsoption wählen',
  });
  String get googleMapsNavigationSubtitle => _getText({
    'en': 'Opens Google Maps with driving mode preselected',
    'tr': 'Google Maps araç modunda açılır',
    'de': 'Öffnet Google Maps im Fahrmodus',
  });
  String get openInTomTom => _getText({
    'en': 'Open TomTom Navigation',
    'tr': 'TomTom Navigasyonunu Aç',
    'de': 'TomTom Navigation öffnen',
  });
  String get tomTomNavigation => _getText({
    'en': 'TomTom Navigation',
    'tr': 'TomTom Navigasyon',
    'de': 'TomTom Navigation',
  });
  String get tomTomNavigationSubtitle => _getText({
    'en': 'Use the in-app TomTom route with live traffic',
    'tr': 'Canlı trafikli TomTom rotasını uygulama içinde kullan',
    'de': 'TomTom Route mit Live-Verkehr in der App nutzen',
  });
  String get tomTomNavigationActive => _getText({
    'en': 'Navigation is active',
    'tr': 'Navigasyon aktif',
    'de': 'Navigation ist aktiv',
  });
  String get tomTomNavigationInactive => _getText({
    'en': 'Navigation is inactive',
    'tr': 'Navigasyon pasif',
    'de': 'Navigation ist inaktiv',
  });
  String get tomTomRouteError => _getText({
    'en': 'Unable to fetch TomTom route',
    'tr': 'TomTom rotası alınamadı',
    'de': 'TomTom-Route konnte nicht geladen werden',
  });
  String get tomTomNoRoute => _getText({
    'en': 'No TomTom route could be generated.',
    'tr': 'TomTom rotası oluşturulamadı.',
    'de': 'Es konnte keine TomTom-Route erstellt werden.',
  });
  String get tomTomNoInstructions => _getText({
    'en': 'No instructions provided for this route.',
    'tr': 'Bu rota için talimat bulunamadı.',
    'de': 'Für diese Route sind keine Anweisungen vorhanden.',
  });
  String get tomTomInstructions => _getText({
    'en': 'Turn-by-turn instructions',
    'tr': 'Adım adım talimatlar',
    'de': 'Abbiegehinweise',
  });
  String get tomTomNextInstruction => _getText({
    'en': 'Next instruction',
    'tr': 'Sıradaki talimat',
    'de': 'Nächster Hinweis',
  });
  String get navigationProgress => _getText({
    'en': 'Progress: @percent',
    'tr': 'İlerleme: @percent',
    'de': 'Fortschritt: @percent',
  });
  String get trafficDelayLabel => _getText({
    'en': 'Traffic delay',
    'tr': 'Trafik gecikmesi',
    'de': 'Verkehrsverzögerung',
  });
  String get tomTomLiveDistance => _getText({
    'en': 'Distance to destination',
    'tr': 'Varışa mesafe',
    'de': 'Entfernung zum Ziel',
  });
  String get tomTomLiveEta => _getText({
    'en': 'Estimated arrival',
    'tr': 'Tahmini varış',
    'de': 'Geschätzte Ankunft',
  });
  String get tomTomArrived => _getText({
    'en': 'You have arrived at the destination.',
    'tr': 'Varış noktasına ulaştınız.',
    'de': 'Sie sind am Ziel angekommen.',
  });
  String get refreshRoute => _getText({
    'en': 'Refresh route',
    'tr': 'Rotayı yenile',
    'de': 'Route aktualisieren',
  });
  String get startNavigation => _getText({
    'en': 'Start navigation',
    'tr': 'Navigasyonu başlat',
    'de': 'Navigation starten',
  });
  String get stopNavigation => _getText({
    'en': 'Stop navigation',
    'tr': 'Navigasyonu durdur',
    'de': 'Navigation stoppen',
  });
  String get openInApp => _getText({
    'en': 'Open in App',
    'tr': 'Uygulama İçinde Aç',
    'de': 'In App öffnen',
  });
  String get openingPdf => _getText({
    'en': 'openingPdf',
    'tr': 'PDF açılıyor',
    'de': 'PDF wird geöffnet',
  });
  String get operatingSystem => _getText({
    'en': 'operatingSystem',
    'tr': '💻 İşletim Sistemi',
    'de': '💻 Betriebssystem',
  });
  String get operationFailed => _getText({
    'en': 'operationFailed',
    'tr': 'İşlem Başarısız',
    'de': 'Vorgang fehlgeschlagen',
  });
  String get orDidntCompleteStarted => _getText({
    'en': 'orDidntCompleteStarted',
    'tr': 'Veya başlattığınız lokasyonu tamamlamadınız',
    'de': 'Oder Sie haben den gestarteten Standort nicht abgeschlossen',
  });
  String get orNotCompletedLocation => _getText({
    'en': 'orNotCompletedLocation',
    'tr': 'Veya başlattığınız lokasyonu tamamlamadınız',
    'de': 'Oder Sie haben den begonnenen Standort nicht abgeschlossen',
  });
  String get parkingSpaces => _getText({
    'en': 'parkingSpaces',
    'tr': 'Park Alanları',
    'de': 'Parkplätze',
  });
  String get parkingSpacesPaths => _getText({
    'en': 'parkingSpacesPaths',
    'tr': 'Park Alanları (Yollar)',
    'de': 'Parkplätze (Wege)',
  });
  String get parkingSpacesSurface => _getText({
    'en': 'parkingSpacesSurface',
    'tr': 'Park Alanları (Yüzey)',
    'de': 'Parkplätze (Oberfläche)',
  });
  String get password =>
      _getText({'en': 'password', 'tr': 'Şifre', 'de': 'Passwort'});
  String get passwordMinLength => _getText({
    'en': 'passwordMinLength',
    'tr': 'Şifre en az 6 karakter olmalı',
    'de': 'Passwort muss mindestens 6 Zeichen lang sein',
  });
  String get passwordRequired => _getText({
    'en': 'passwordRequired',
    'tr': 'Şifre gerekli',
    'de': 'Passwort ist erforderlich',
  });
  String get pause => _getText({'en': 'Pause', 'tr': 'Pause', 'de': 'Pause'});
  String get pending =>
      _getText({'en': 'Pending', 'tr': 'Pending', 'de': 'Pending'});
  String get pendingIssues => _getText({
    'en': 'pendingIssues',
    'tr': '@count sorun senkronize edilmeyi bekliyor',
    'de': '@count Probleme warten auf Synchronisierung',
  });
  String get photo =>
      _getText({'en': 'Photo', 'tr': '🔢 Fotoğraf', 'de': '🔢 Foto'});
  String get photoInfo => _getText({
    'en': 'photoInfo',
    'tr': '--- Fotoğraf Bilgileri ---',
    'de': '--- Foto-Informationen ---',
  });
  String get photoInformation => _getText({
    'en': 'Photo Information',
    'tr': 'Fotoğraf Bilgileri',
    'de': 'Foto-Informationen',
  });
  String get photoNumber => _getText({
    'en': 'photoNumber',
    'tr': 'Fotoğraf @number:',
    'de': 'Foto @number:',
  });
  String get photoProcessingError => _getText({
    'en': 'Photo processing error: @error',
    'tr': 'Fotoğraf işleme hatası: @error',
    'de': 'Foto-Verarbeitungsfehler: @error',
  });
  String get photoSaved => _getText({
    'en': 'photoSaved',
    'tr': 'Fotoğraf kaydedildi',
    'de': 'Foto gespeichert',
  });
  String get photos =>
      _getText({'en': 'Photos', 'tr': 'Photos', 'de': 'Photos'});
  String get photosProcessed => _getText({
    'en': 'photosProcessed',
    'tr': '@count fotoğraf işlendi',
    'de': '@count Fotos verarbeitet',
  });
  String get previous =>
      _getText({'en': 'Previous', 'tr': 'Previous', 'de': 'Previous'});
  String get previousSessionFound => _getText({
    'en': 'Previous session found',
    'tr': 'Daha önce başlattığınız bir iş oturumu var.',
    'de': 'Sie haben eine zuvor gestartete Arbeitssitzung.',
  });
  String get priority =>
      _getText({'en': 'priority', 'tr': 'Önem Derecesi', 'de': 'Priorität'});
  String get proximityDistance => _getText({
    'en': 'proximityDistance',
    'tr': 'Yakınlık Mesafesi',
    'de': 'Nähe Entfernung',
  });
  String get proximityNotifications => _getText({
    'en': 'proximityNotifications',
    'tr': 'Lokasyonlara yaklaşınca bildirim alacaksınız',
    'de': 'Sie erhalten Benachrichtigungen, wenn Sie sich Standorten nähern',
  });
  String get receiveTimeout => _getText({
    'en': 'receiveTimeout',
    'tr': 'Alım zaman aşımı',
    'de': 'Empfangstimeout',
  });
  String get refresh =>
      _getText({'en': 'Refresh', 'tr': 'Yenile', 'de': 'Aktualisieren'});
  String get rejected =>
      _getText({'en': 'Rejected', 'tr': 'Rejected', 'de': 'Rejected'});
  String get remaining =>
      _getText({'en': 'Remaining', 'tr': 'Kalan', 'de': 'Verbleibend'});
  String get remainingTime =>
      _getText({'en': 'remainingTime', 'tr': 'Kalan', 'de': 'Verbleibend'});
  String get rememberMe => _getText({
    'en': 'rememberMe',
    'tr': 'Beni Hatırla',
    'de': 'Angemeldet bleiben',
  });
  String get reportDate => _getText({
    'en': 'reportDate',
    'tr': 'Bildirim Tarihi',
    'de': 'Meldedatum',
  });
  String get reportFeatureComingSoon => _getText({
    'en': 'reportFeatureComingSoon',
    'tr': 'Rapor oluşturma özelliği yakında...',
    'de': 'Berichtsfunktion kommt bald...',
  });
  String get reportIssue => _getText({
    'en': 'reportIssue',
    'tr': 'Sorun Bildir',
    'de': 'Problem melden',
  });
  String get reportedIssues => _getText({
    'en': 'reportedIssues',
    'tr': 'Bildirilen Sorunlar',
    'de': 'Gemeldete Probleme',
  });
  String get requestCancelled => _getText({
    'en': 'requestCancelled',
    'tr': 'İstek iptal edildi',
    'de': 'Anfrage abgebrochen',
  });
  String get resolved =>
      _getText({'en': 'resolved', 'tr': 'Çözüldü', 'de': 'Gelöst'});
  String get resume =>
      _getText({'en': 'Resume', 'tr': 'Resume', 'de': 'Resume'});
  String get retry => _getText({'en': 'Retry', 'tr': 'Retry', 'de': 'Retry'});
  String get routing =>
      _getText({'en': 'routing', 'tr': 'Rotalama', 'de': 'Routing'});
  String get save =>
      _getText({'en': 'Save', 'tr': 'Kaydet', 'de': 'Speichern'});
  String get search =>
      _getText({'en': 'Search', 'tr': 'Search', 'de': 'Search'});
  String get searchLocation => _getText({
    'en': 'searchLocation',
    'tr': 'Lokasyon ara...',
    'de': 'Standort suchen...',
  });
  String get selectAtLeastOnePhoto => _getText({
    'en': 'Please select at least one photo',
    'tr': 'En az 1 fotoğraf seçmelisiniz',
    'de': 'Sie müssen mindestens 1 Foto auswählen',
  });
  String get selectCluster => _getText({
    'en': 'selectCluster',
    'tr': 'Cluster Seçin',
    'de': 'Cluster auswählen',
  });
  String get selectClusterToStart => _getText({
    'en': 'selectClusterToStart',
    'tr': 'Lütfen lokasyonları görüntülemek için bir cluster seçin',
    'de': 'Bitte wählen Sie einen Cluster aus, um Standorte anzuzeigen',
  });
  String get selectLanguage => _getText({
    'en': 'selectLanguage',
    'tr': 'Dil Seçin',
    'de': 'Sprache auswählen',
  });
  String get selectPhoto => _getText({
    'en': 'Select Photo',
    'tr': 'Select Photo',
    'de': 'Select Photo',
  });
  String get selectPhotos => _getText({
    'en': 'Select Photos',
    'tr': 'Select Photos',
    'de': 'Select Photos',
  });
  String get selectedImages => _getText({
    'en': 'selectedImages',
    'tr': 'Seçilen Fotoğraflar',
    'de': 'Ausgewählte Bilder',
  });
  String get sendTimeout => _getText({
    'en': 'sendTimeout',
    'tr': 'Gönderim zaman aşımı',
    'de': 'Sendetimeout',
  });
  String get serverError => _getText({
    'en': 'serverError',
    'tr': 'Sunucu hatası: @code',
    'de': 'Serverfehler: @code',
  });
  String get serverErrorGeneric => _getText({
    'en': 'serverErrorGeneric',
    'tr': 'Sunucu hatası',
    'de': 'Serverfehler',
  });
  String get settings =>
      _getText({'en': 'Settings', 'tr': 'Ayarlar', 'de': 'Einstellungen'});
  String get settingsSaved => _getText({
    'en': 'settingsSaved',
    'tr': 'Ayarlar kaydedildi',
    'de': 'Einstellungen gespeichert',
  });
  String get share => _getText({'en': 'share', 'tr': 'Paylaş', 'de': 'Teilen'});
  String get sidewalks1_5m => _getText({
    'en': 'sidewalks1_5m',
    'tr': 'Gehwege 1.5m',
    'de': 'Gehwege 1,5m',
  });
  String get sidewalks1m =>
      _getText({'en': 'sidewalks1m', 'tr': 'Gehwege 1m', 'de': 'Gehwege 1m'});
  String get snowClearingWork => _getText({
    'en': 'snowClearingWork',
    'tr': 'Kar temizleme işine başlamak üzeresiniz.',
    'de': 'Sie sind dabei, Schneeräumarbeiten zu beginnen.',
  });
  String get sort => _getText({'en': 'Sort', 'tr': 'Sort', 'de': 'Sort'});
  String get sortByAreaAsc => _getText({
    'en': 'sortByAreaAsc',
    'tr': 'Alan (Küçükten Büyüğe)',
    'de': 'Fläche (Klein zu Groß)',
  });
  String get sortByAreaDesc => _getText({
    'en': 'sortByAreaDesc',
    'tr': 'Alan (Büyükten Küçüğe)',
    'de': 'Fläche (Groß zu Klein)',
  });
  String get sortByNearest =>
      _getText({'en': 'sortByNearest', 'tr': 'En Yakın', 'de': 'Am nächsten'});
  String get sortByRoute => _getText({
    'en': 'sortByRoute',
    'tr': 'Rota Sırası',
    'de': 'Routenreihenfolge',
  });
  String get sortByStatus => _getText({
    'en': 'sortByStatus',
    'tr': 'Duruma Göre',
    'de': 'Nach Status',
  });
  String get sortLabelAreaAsc => _getText({
    'en': 'sortLabelAreaAsc',
    'tr': 'Alan (Küçükten büyüğe)',
    'de': 'Fläche (Klein zu groß)',
  });
  String get sortLabelAreaDesc => _getText({
    'en': 'sortLabelAreaDesc',
    'tr': 'Alan (Büyükten küçüğe)',
    'de': 'Fläche (Groß zu klein)',
  });
  String get sortLabelManual => _getText({
    'en': 'sortLabelManual',
    'tr': 'Manuel sıralama (Sürükle bırak)',
    'de': 'Manuelle Sortierung (Ziehen & Ablegen)',
  });
  String get sortLabelNearest => _getText({
    'en': 'sortLabelNearest',
    'tr': 'En yakın lokasyonlar',
    'de': 'Nächstgelegene Standorte',
  });
  String get sortLabelRoute => _getText({
    'en': 'sortLabelRoute',
    'tr': 'Rota sırası (Ofisten başlayarak)',
    'de': 'Routenreihenfolge (Vom Büro aus)',
  });
  String get sortLabelStatus => _getText({
    'en': 'sortLabelStatus',
    'tr': 'Duruma göre (Tamamlanmayanlar önce)',
    'de': 'Nach Status (Unvollständige zuerst)',
  });
  String get sortManual => _getText({
    'en': 'sortManual',
    'tr': 'Manuel Sıralama',
    'de': 'Manuelle Sortierung',
  });
  String get sorting =>
      _getText({'en': 'sorting', 'tr': 'Sıralama', 'de': 'Sortierung'});
  String get start => _getText({'en': 'Start', 'tr': 'Başlat', 'de': 'Start'});
  String get startTime => _getText({
    'en': 'startTime',
    'tr': 'Başlangıç: @time',
    'de': 'Start: @time',
  });
  String get startWork =>
      _getText({'en': 'startWork', 'tr': 'İŞE BAŞLA', 'de': 'ARBEIT BEGINNEN'});
  String get startWorkSession => _getText({
    'en': 'startWorkSession',
    'tr': 'İş Oturumu Başlat',
    'de': 'Arbeitssitzung Starten',
  });
  String get startWorkSessionDesc => _getText({
    'en': 'startWorkSessionDesc',
    'tr': 'Kar temizleme işine başlamak üzeresiniz.',
    'de': 'Sie sind dabei, mit der Schneeräumung zu beginnen.',
  });
  String get startWorkSessionTitle => _getText({
    'en': 'Start Work Session',
    'tr': 'İş Oturumu Başlat',
    'de': 'Arbeitssitzung Starten',
  });
  String get startedAt =>
      _getText({'en': 'startedAt', 'tr': 'Başlangıç', 'de': 'Gestartet um'});
  String get state =>
      _getText({'en': 'state', 'tr': 'Eyalet', 'de': 'Bundesland'});
  String get stillEndSession => _getText({
    'en': 'stillEndSession',
    'tr': 'Yine de iş oturumunu bitirmek istiyor musunuz?',
    'de': 'Möchten Sie die Arbeitssitzung trotzdem beenden?',
  });
  String get stop => _getText({'en': 'Stop', 'tr': 'Stop', 'de': 'Stop'});
  String get submit =>
      _getText({'en': 'submit', 'tr': 'Gönder', 'de': 'Senden'});
  String get submitIssue => _getText({
    'en': 'submitIssue',
    'tr': 'Sorunu Bildir',
    'de': 'Problem melden',
  });
  String get success =>
      _getText({'en': 'Success', 'tr': 'Success', 'de': 'Success'});
  String get syncCompleted => _getText({
    'en': 'syncCompleted',
    'tr': 'Senkronizasyon tamamlandı',
    'de': 'Synchronisierung abgeschlossen',
  });
  String get syncFailed => _getText({
    'en': 'syncFailed',
    'tr': 'Senkronizasyon başarısız',
    'de': 'Synchronisierung fehlgeschlagen',
  });
  String get synchronize => _getText({
    'en': 'synchronize',
    'tr': 'Senkronize Et',
    'de': 'Synchronisieren',
  });
  String get synchronizing => _getText({
    'en': 'synchronizing',
    'tr': 'Senkronize ediliyor...',
    'de': 'Synchronisiere...',
  });
  String get takePhoto => _getText({
    'en': 'Take Photo',
    'tr': 'Fotoğraf Çek',
    'de': 'Foto aufnehmen',
  });
  String get time =>
      _getText({'en': 'time', 'tr': '@hour:@minute', 'de': '@hour:@minute'});
  String get toEndWorkSessionYouNeed => _getText({
    'en': 'toEndWorkSessionYouNeed',
    'tr': 'İş oturumunu bitirmek için:',
    'de': 'Um die Arbeitssitzung zu beenden, müssen Sie:',
  });
  String get total => _getText({'en': 'total', 'tr': 'Toplam', 'de': 'Gesamt'});
  String get totalArea => _getText({
    'en': 'totalArea',
    'tr': 'Toplam alan: @area',
    'de': 'Gesamtfläche: @area',
  });
  String get totalAreaLabel =>
      _getText({'en': 'totalAreaLabel', 'tr': 'Alan', 'de': 'Fläche'});
  String get totalLocations => _getText({
    'en': 'totalLocations',
    'tr': 'Toplam lokasyon: @count',
    'de': 'Gesamtstandorte: @count',
  });
  String get totalLocationsLabel => _getText({
    'en': 'totalLocationsLabel',
    'tr': 'Toplam lokasyon',
    'de': 'Gesamtstandorte',
  });
  String get totalTime =>
      _getText({'en': 'totalTime', 'tr': 'Toplam Süre', 'de': 'Gesamtzeit'});
  String get tryAgain => _getText({
    'en': 'tryAgain',
    'tr': 'Tekrar Dene',
    'de': 'Erneut versuchen',
  });
  String get turkish =>
      _getText({'en': 'turkish', 'tr': 'Türkçe', 'de': 'Türkçe'});
  String get unauthorized => _getText({
    'en': 'unauthorized',
    'tr': 'Kimlik doğrulama hatası',
    'de': 'Authentifizierungsfehler',
  });
  String get understood =>
      _getText({'en': 'understood', 'tr': 'Anladım', 'de': 'Verstanden'});
  String get unexpectedError => _getText({
    'en': 'Unexpected error: @error',
    'tr': 'Beklenmeyen hata: @error',
    'de': 'Unerwarteter Fehler: @error',
  });
  String get unknown =>
      _getText({'en': 'Unknown', 'tr': 'Bilinmeyen', 'de': 'Unbekannt'});
  String get unknownError => _getText({
    'en': 'unknownError',
    'tr': 'Bilinmeyen hata',
    'de': 'Unbekannter Fehler',
  });
  String get user =>
      _getText({'en': 'User', 'tr': '👤 Kullanıcı', 'de': '👤 Benutzer'});
  String get validEmail => _getText({
    'en': 'validEmail',
    'tr': 'Geçerli bir e-posta adresi girin',
    'de': 'Bitte geben Sie eine gültige E-Mail-Adresse ein',
  });
  String get vehiclePaths => _getText({
    'en': 'vehiclePaths',
    'tr': 'Araç Yolları',
    'de': 'Fahrzeugwege',
  });
  String get viewDetails => _getText({
    'en': 'viewDetails',
    'tr': 'Detayları Gör',
    'de': 'Details Anzeigen',
  });
  String get viewPdf =>
      _getText({'en': 'viewPdf', 'tr': 'PDF Görüntüle', 'de': 'PDF anzeigen'});
  String get waitingSync => _getText({
    'en': 'waitingSync',
    'tr': 'Senkronizasyon Bekliyor',
    'de': 'Warten auf Synchronisation',
  });
  String get wantToEndWorkSession => _getText({
    'en': 'wantToEndWorkSession',
    'tr': 'İş oturumunu bitirmek ister misiniz?',
    'de': 'Möchten Sie die Arbeitssitzung beenden?',
  });
  String get warning =>
      _getText({'en': 'warning', 'tr': 'Dikkat', 'de': 'Warnung'});
  String get waypointIndex => _getText({
    'en': 'waypointIndex',
    'tr': 'Durak Sırası',
    'de': 'Wegpunkt-Index',
  });
  String get welcome =>
      _getText({'en': 'welcome', 'tr': 'Hoş geldiniz,', 'de': 'Willkommen,'});
  String get whyThisError => _getText({
    'en': 'whyThisError',
    'tr': 'Neden bu hata?',
    'de': 'Warum dieser Fehler?',
  });
  String get willGetNotifications => _getText({
    'en': 'willGetNotifications',
    'tr': 'Lokasyonlara yaklaşınca bildirim alacaksınız',
    'de': 'Sie erhalten Benachrichtigungen bei Annäherung an Standorte',
  });
  String get workAreas => _getText({
    'en': 'workAreas',
    'tr': 'Çalışma Alanları',
    'de': 'Arbeitsbereiche',
  });
  String get workPlan => _getText({
    'en': 'workPlan',
    'tr': 'Çalışma Planım',
    'de': 'Mein Arbeitsplan',
  });
  String get workSessionActive => _getText({
    'en': 'workSessionActive',
    'tr': 'İş oturumu aktif',
    'de': 'Arbeitssitzung aktiv',
  });
  String get workSessionCompleted => _getText({
    'en': 'workSessionCompleted',
    'tr': 'İş oturumu tamamlandı! GPS kapatıldı.',
    'de': 'Arbeitssitzung abgeschlossen! GPS ausgeschaltet.',
  });
  String get workSessionCompletedGpsStopped => _getText({
    'en': 'workSessionCompletedGpsStopped',
    'tr': 'İş oturumu tamamlandı! GPS kapatıldı.',
    'de': 'Arbeitssitzung abgeschlossen! GPS gestoppt.',
  });
  String get workSessionStarted => _getText({
    'en': 'workSessionStarted',
    'tr': 'İş oturumu başlatıldı! GPS aktif.',
    'de': 'Arbeitssitzung gestartet! GPS aktiv.',
  });
  String get yes => _getText({'en': 'Yes', 'tr': 'Evet', 'de': 'Ja'});
  String get yesComplete =>
      _getText({'en': 'yesComplete', 'tr': 'Evet, Bitir', 'de': 'Ja, Fertig'});
  String get yesEnd =>
      _getText({'en': 'yesEnd', 'tr': 'Evet, Bitir', 'de': 'Ja, Beenden'});
  String get yesIStarted => _getText({
    'en': 'yesIStarted',
    'tr': 'Evet, Başladım',
    'de': 'Ja, ich habe begonnen',
  });
  String get yesStarted => _getText({
    'en': 'yesStarted',
    'tr': 'Evet, Başladım',
    'de': 'Ja, Ich Habe Begonnen',
  });
  String get zipCode =>
      _getText({'en': 'zipCode', 'tr': 'Posta Kodu', 'de': 'Postleitzahl'});

  // Total: 366 keys generated
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'tr', 'de'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
