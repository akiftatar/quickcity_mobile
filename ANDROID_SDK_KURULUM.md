# Android SDK Kurulum Rehberi

## 1. Android Studio İndirme ve Kurulum

### Adım 1: Android Studio İndirin
1. Tarayıcınızda şu adresi açın: https://developer.android.com/studio
2. "Download Android Studio" butonuna tıklayın
3. İndirme başladığında exe dosyasının inmesini bekleyin (~1 GB)

### Adım 2: Android Studio'yu Kurun
1. İndirdiğiniz `.exe` dosyasını çalıştırın (yönetici yetkisi gerekebilir)
2. Kurulum sihirbazını takip edin:
   - İlk ekranda "Next" tıklayın
   - Bileşen seçiminde **tüm bileşenlerin seçili olduğundan emin olun** (Android SDK, Android SDK Platform, Android Virtual Device)
   - Kurulum yolunu not edin (genellikle `C:\Program Files\Android\Android Studio`)
   - "Install" butonuna tıklayın
   - Kurulum tamamlanana kadar bekleyin

### Adım 3: Android Studio'yu İlk Kez Açın
1. Android Studio'yu başlatın
2. İlk açılışta SDK kurulum sihirbazı açılacak
3. "Standard" kurulum seçeneğini seçin
4. SDK kurulum yolunu not edin (genellikle `C:\Users\<KullanıcıAdı>\AppData\Local\Android\Sdk`)
5. "Finish" butonuna tıklayın ve SDK bileşenlerinin indirilmesini bekleyin (~2-3 GB)

## 2. SDK Yolunu Bulma

Android Studio'yu açtıktan sonra:
1. `File > Settings` (veya `Ctrl + Alt + S`) tıklayın
2. Sol menüden: `Appearance & Behavior > System Settings > Android SDK`
3. "Android SDK Location" başlığının altındaki yolu kopyalayın
   - Örnek: `C:\Users\eta\AppData\Local\Android\Sdk`

## 3. Ortam Değişkenlerini Ayarlama

### Yöntem 1: PowerShell ile (Hızlı)
Aşağıdaki komutları PowerShell'de çalıştırın (SDK yolunu kendi yolunuzla değiştirin):

```powershell
# SDK yolunu değişken olarak ayarlayın (kendi yolunuzla değiştirin)
$sdkPath = "C:\Users\eta\AppData\Local\Android\Sdk"

# ANDROID_HOME ortam değişkenini ekle
[System.Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdkPath, [System.EnvironmentVariableTarget]::User)

# ANDROID_SDK_ROOT ortam değişkenini ekle
[System.Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $sdkPath, [System.EnvironmentVariableTarget]::User)

# PATH'e platform-tools ekle
$currentPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
$newPath = "$sdkPath\platform-tools;$sdkPath\tools;$sdkPath\tools\bin;$currentPath"
[System.Environment]::SetEnvironmentVariable('Path', $newPath, [System.EnvironmentVariableTarget]::User)

# Flutter'a SDK yolunu söyle
flutter config --android-sdk $sdkPath
```

### Yöntem 2: Manuel (Windows Ayarları)
1. Windows arama çubuğuna "ortam değişkenleri" yazın
2. "Ortam değişkenlerini düzenle" seçeneğine tıklayın
3. Kullanıcı değişkenleri bölümünde "Yeni" butonuna tıklayın:
   - Değişken adı: `ANDROID_HOME`
   - Değişken değeri: SDK yolu (örn: `C:\Users\eta\AppData\Local\Android\Sdk`)
4. Tekrar "Yeni" butonuna tıklayın:
   - Değişken adı: `ANDROID_SDK_ROOT`
   - Değişken değeri: SDK yolu (aynı yol)
5. `Path` değişkenini seçip "Düzenle" butonuna tıklayın
6. "Yeni" butonuna tıklayıp şu yolları ekleyin:
   - `%ANDROID_HOME%\platform-tools`
   - `%ANDROID_HOME%\tools`
   - `%ANDROID_HOME%\tools\bin`

## 4. Kurulumu Doğrulama

1. **PowerShell'i kapatıp yeniden açın** (değişkenlerin yüklenmesi için)
2. Şu komutları çalıştırın:

```powershell
# Flutter doctor kontrolü
flutter doctor -v

# Android SDK yolunu kontrol et
flutter config --list

# ADB kontrolü
adb --version
```

`flutter doctor` çıktısında Android toolchain'in yeşil tik ile görünmesi gerekiyor.

## 5. Gerekli SDK Bileşenlerini Kurma

Flutter için gerekli bileşenler otomatik kurulmazsa:

1. Android Studio'yu açın
2. `File > Settings > Appearance & Behavior > System Settings > Android SDK`
3. "SDK Platforms" sekmesinde:
   - ✅ Android 13.0 (Tiramisu) - API 33
   - ✅ Android 12.0 (S) - API 31
   - ✅ Android 11.0 (R) - API 30
4. "SDK Tools" sekmesinde:
   - ✅ Android SDK Build-Tools
   - ✅ Android SDK Command-line Tools
   - ✅ Android SDK Platform-Tools
   - ✅ Android Emulator
5. "Apply" butonuna tıklayın ve indirme/kurulumu bekleyin

## Sorun Giderme

### SDK bulunamıyorsa:
```powershell
flutter config --android-sdk "SDK_YOLU_BURAYA"
```

### Flutter doctor hala hata veriyorsa:
1. PowerShell'i yönetici olarak çalıştırın
2. Ortam değişkenlerini tekrar kontrol edin
3. Bilgisayarı yeniden başlatın

### License hatası alıyorsanız:
```powershell
flutter doctor --android-licenses
```
Tüm lisansları kabul edin (y tuşuna basarak).


