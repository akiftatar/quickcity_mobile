# 🎨 QuickCity Winterdienst - Logo Kurulum Rehberi

## 📋 **GEREKLİ LOGO DOSYALARI**

### **1. Ana Logo (Zorunlu)**
- **Dosya Adı:** `app_icon.png`
- **Boyut:** **1024x1024 px**
- **Format:** PNG (şeffaf arka plan önerilir)
- **Konum:** `assets/icon/app_icon.png`

### **2. Android Adaptive Icon (Önerilen)**
- **Dosya Adı:** `app_icon_foreground.png`
- **Boyut:** **1024x1024 px**
- **Format:** PNG (şeffaf arka plan **zorunlu**)
- **İçerik:** Logo merkezde 432x432 px alanda olmalı
- **Konum:** `assets/icon/app_icon_foreground.png`

---

## 📐 **LOGO TASARIM KURALLARI**

### **Ana Logo (app_icon.png):**
```
┌────────────────────────┐
│                        │
│                        │
│      QUICKCITY         │
│    ❄️ WINTER ❄️        │
│                        │
│                        │
└────────────────────────┘
     1024x1024 px
```

**Öneriler:**
- ✅ Kare format (1:1 oran)
- ✅ Merkezde logo
- ✅ Kenarlarda 10% boşluk
- ✅ Kontrast yüksek renkler
- ✅ Basit ve tanınabilir
- ❌ Çok ince detaylar
- ❌ Küçük yazılar

### **Android Adaptive Icon (app_icon_foreground.png):**
```
┌────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░ │ ← Safe zone (boş)
│ ░░  ┌──────────────┐  ░░  │
│ ░░  │              │  ░░  │
│ ░░  │  QUICKCITY   │  ░░  │ ← Logo burada
│ ░░  │     ❄️       │  ░░  │   (432x432 px)
│ ░░  │              │  ░░  │
│ ░░  └──────────────┘  ░░  │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└────────────────────────────┘
       1024x1024 px
```

**Önemli:**
- Logo **merkeze** yerleştirin
- Etrafta **296 px boşluk** bırakın
- **Şeffaf arka plan** kullanın

---

## 🗂️ **DOSYA YAPISI**

Projenizde şu klasör yapısını oluşturun:

```
quickcity_mobile/
├─ assets/
│  └─ icon/
│     ├─ app_icon.png              (1024x1024 px)
│     └─ app_icon_foreground.png   (1024x1024 px - opsiyonel)
├─ android/
├─ ios/
└─ pubspec.yaml
```

---

## 🚀 **KURULUM ADIMLARI**

### **Adım 1: Logo Dosyalarını Ekleyin**
```bash
# Klasörü oluşturun
mkdir -p assets/icon

# Logo dosyalarınızı buraya kopyalayın
# assets/icon/app_icon.png
# assets/icon/app_icon_foreground.png (opsiyonel)
```

### **Adım 2: Paketi Yükleyin**
```bash
flutter pub get
```

### **Adım 3: İkonları Oluşturun**
```bash
flutter pub run flutter_launcher_icons
```

**Çıktı:**
```
Creating icons...
✓ Android icons created
✓ iOS icons created
✓ Icon generation completed
```

### **Adım 4: Kontrol Edin**
```bash
# Android ikonları
ls android/app/src/main/res/mipmap-*/ic_launcher.png

# iOS ikonları (Mac'te)
ls ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

---

## 🎨 **LOGO TASARIM ÖRNEKLERİ**

### **Örnek 1: Basit Logo**
```
┌─────────────┐
│             │
│  QuickCity  │
│     ❄️      │
│   Winter    │
│             │
└─────────────┘
```

### **Örnek 2: Marka Logosu**
```
┌─────────────┐
│   ╔═══╗     │
│   ║ QC║     │
│   ╚═══╝     │
│     ❄️      │
│  WINTERD.   │
└─────────────┘
```

### **Örnek 3: Icon + Text**
```
┌─────────────┐
│    ___      │
│   /❄️\     │
│  |QC |      │
│   \__/      │
│  Winter     │
└─────────────┘
```

---

## 🔧 **PUBSPECyaml YAPILANDIRMASI**

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  
  # Android Adaptive Icon (Opsiyonel)
  adaptive_icon_background: "#FFFFFF"  # veya "#1976D2" (mavi)
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
  
  # Özelleştirme (Opsiyonel)
  min_sdk_android: 21
  web:
    generate: true
    image_path: "assets/icon/app_icon.png"
  windows:
    generate: true
    image_path: "assets/icon/app_icon.png"
```

---

## 📱 **FARKLI PLATFORMLAR**

### **Android:**
- ✅ Normal icon (tüm boyutlar)
- ✅ Adaptive icon (Android 8.0+)
- ✅ Round icon

### **iOS:**
- ✅ App icon (tüm boyutlar)
- ✅ iPad icon
- ✅ App Store icon (1024x1024)

### **Web (Bonus):**
- ✅ Favicon
- ✅ Manifest icons

---

## ⚠️ **SIKÇA YAPILAN HATALAR**

1. ❌ **Logo çok küçük** → Minimum 1024x1024 px kullanın
2. ❌ **Şeffaf arka plan yok** → PNG formatında şeffaflık kullanın
3. ❌ **Adaptive icon merkezde değil** → Logoyu tam merkeze yerleştirin
4. ❌ **Çok detaylı logo** → Basit ve tanınabilir tutun
5. ❌ **Kare format değil** → 1:1 oran kullanın

---

## 🎯 **HIZLI BAŞLANGIÇ**

Eğer hemen test etmek istiyorsanız:

```bash
# 1. Geçici bir logo oluşturun (online araçlar)
https://logo.com
https://canva.com

# 2. 1024x1024 px boyutunda indirin

# 3. assets/icon/ klasörüne kopyalayın

# 4. Komutları çalıştırın
flutter pub get
flutter pub run flutter_launcher_icons

# 5. Uygulamayı test edin
flutter run
```

---

## 📞 **YARDIM**

Logo ile ilgili sorun yaşıyorsanız:
- ✅ Dosya yollarını kontrol edin
- ✅ Boyutları doğrulayın (1024x1024 px)
- ✅ PNG formatında olduğundan emin olun
- ✅ `flutter pub get` komutunu çalıştırın

---

**Hazırladığınız logoyu `assets/icon/` klasörüne ekleyip `flutter pub run flutter_launcher_icons` komutunu çalıştırdığınızda her şey otomatik olarak yapılacak!** 🎉

