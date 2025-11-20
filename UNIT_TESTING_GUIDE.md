# 🧪 Unit Test Nedir? - Tam Kılavuz

## 📌 Unit Test Nedir?

**Unit Test (Birim Test)**, yazılımın en küçük parçalarını (fonksiyon, metod, sınıf) **izole bir şekilde** test etmektir.

### 🎯 Amaçları:

1. ✅ **Kod kalitesini artırmak**
2. ✅ **Hataları erken yakalamak** (geliştirme aşamasında)
3. ✅ **Güvenle refactoring yapmak** (kod değişince testler bozulursa anında fark edilir)
4. ✅ **Dokümantasyon sağlamak** (kodun nasıl kullanılacağını gösterir)
5. ✅ **Regresyon önlemek** (eski özellikler bozulmaz)

---

## 🤔 Gerçek Hayat Örneği

Bir **araba** ürettiğinizi düşünün:

### ❌ Test Olmasaydı:
1. Arabayı tamamen monte et
2. Test sürüşüne çıkar
3. Fren çalışmıyorsa → **TÜM ARABAYI SÖK!**
4. Freni düzelt
5. Tekrar monte et
6. Tekrar test et
7. 😫 Çok zaman kaybı!

### ✅ Unit Test ile:
1. Freni ayrı test et → Çalışıyor mu?
2. Motoru ayrı test et → Çalışıyor mu?
3. Direksiyonu ayrı test et → Çalışıyor mu?
4. Hepsini birleştir → **İlk seferde çalışır!** 🎉

---

## 💻 Kod Örneği: Flutter'da Unit Test

### Test Edilecek Kod (Model)

\`\`\`dart
// user.dart
class User {
  final String firstname;
  final String lastname;
  final List<String> roles;

  User({
    required this.firstname,
    required this.lastname,
    required this.roles,
  });

  // Full name getter
  String get fullName => '$firstname $lastname';

  // Admin mi kontrolü
  bool get isAdmin {
    return roles.any((role) => role.toLowerCase() == 'admin');
  }
}
\`\`\`

### Test Kodu

\`\`\`dart
// user_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quickcity_mobile/models/user.dart';

void main() {
  // Test Grubu: İlgili testleri gruplar
  group('User Model Tests', () {
    
    // Test 1: Full name testi
    test('fullName doğru birleştirilmeli', () {
      // Arrange (Hazırlık): Test verisi hazırla
      final user = User(
        firstname: 'Ahmet',
        lastname: 'Yılmaz',
        roles: [],
      );

      // Act (Aksiyon): Test edilecek kodu çalıştır
      final result = user.fullName;

      // Assert (Doğrulama): Sonucu kontrol et
      expect(result, 'Ahmet Yılmaz');
    });

    // Test 2: Admin kontrolü
    test('isAdmin doğru çalışmalı', () {
      final adminUser = User(
        firstname: 'Admin',
        lastname: 'User',
        roles: ['admin'],
      );

      final normalUser = User(
        firstname: 'Normal',
        lastname: 'User',
        roles: ['user'],
      );

      expect(adminUser.isAdmin, true);   // ✅ Admin
      expect(normalUser.isAdmin, false); // ❌ Admin değil
    });
  });
}
\`\`\`

---

## 🏗️ Test Yapısı (AAA Pattern)

Her test **3 aşamadan** oluşur:

### 1. **Arrange (Hazırlık)**
Test verilerini ve nesneleri hazırla.

\`\`\`dart
final user = User(
  firstname: 'Ahmet',
  lastname: 'Yılmaz',
  roles: ['admin'],
);
\`\`\`

### 2. **Act (Aksiyon)**
Test edilecek fonksiyonu/metodu çalıştır.

\`\`\`dart
final isAdmin = user.isAdmin;
\`\`\`

### 3. **Assert (Doğrulama)**
Sonucun beklentiye uygun olduğunu kontrol et.

\`\`\`dart
expect(isAdmin, true);
\`\`\`

---

## ✅ Projenizde Eklediğimiz Testler

### 📁 Test Yapısı:
\`\`\`
test/
  ├── models/
  │   ├── user_test.dart          (7 test ✅)
  │   └── location_test.dart      (15 test ✅)
  │
  └── services/
      └── auth_service_test.dart  (6 test ✅)

TOPLAM: 28 Test ✅
\`\`\`

### 🎯 Test Edilen Özellikler:

#### **User Model (7 test)**
- ✅ JSON parsing
- ✅ fullName birleştirme
- ✅ isAdmin kontrolü
- ✅ isSuperAdmin kontrolü
- ✅ Büyük/küçük harf duyarsızlığı
- ✅ toJson serialize
- ✅ Null değer handling

#### **Location Model (15 test)**
- ✅ Location parsing
- ✅ displayAddress formatlaması
- ✅ WorkAreas hesaplamaları
- ✅ Cluster bazlı alan hesabı (MFILE, HFILE, UFILE)
- ✅ Güvenli int/double parsing
- ✅ Attachments array/string handling

#### **AuthService (6 test)**
- ✅ Başlangıç durumu
- ✅ rememberMe varsayılan değer
- ✅ Admin/SuperAdmin/User role kontrolleri
- ✅ Çoklu role desteği

---

## 🚀 Testleri Çalıştırma

### Tüm Testleri Çalıştır
\`\`\`bash
flutter test
\`\`\`

**Çıktı:**
\`\`\`
00:01 +28: All tests passed! ✅
\`\`\`

### Belirli Bir Test Dosyası
\`\`\`bash
flutter test test/models/user_test.dart
\`\`\`

### Watch Mode (Otomatik)
\`\`\`bash
flutter test --watch
\`\`\`
Kod değiştikçe otomatik test çalışır.

### Coverage (Kapsama) Raporu
\`\`\`bash
flutter test --coverage
\`\`\`

---

## 📊 Test Sonuçlarını Okuma

### Başarılı Test
\`\`\`
00:00 +1: User Model Tests fullName doğru birleştirilmeli ✅
\`\`\`
- \`+1\`: 1 test başarılı
- Yeşil ✅ işareti

### Başarısız Test
\`\`\`
00:00 +5 -1: User Model Tests isAdmin kontrolü [E]
  Expected: true
  Actual: false
\`\`\`
- \`-1\`: 1 test başarısız
- Kırmızı ❌ işareti
- Hata detayları gösterilir

---

## 🎨 Expect (Doğrulama) Çeşitleri

### Temel Eşitlik
\`\`\`dart
expect(actualValue, expectedValue);
expect(2 + 2, 4);
expect(user.name, 'Ahmet');
\`\`\`

### Boolean
\`\`\`dart
expect(user.isAdmin, isTrue);
expect(user.isActive, isFalse);
\`\`\`

### Null Kontrol
\`\`\`dart
expect(user.email, isNotNull);
expect(user.phoneNumber, isNull);
\`\`\`

### Koleksiyon
\`\`\`dart
expect(locations, isEmpty);
expect(locations, isNotEmpty);
expect(locations.length, 5);
expect(locations, contains(location1));
\`\`\`

### Sayı Karşılaştırma
\`\`\`dart
expect(age, greaterThan(18));
expect(temperature, lessThan(100));
expect(price, closeTo(99.99, 0.01)); // 99.99 ± 0.01
\`\`\`

### String
\`\`\`dart
expect(address, startsWith('Berlin'));
expect(email, endsWith('@test.com'));
expect(text, contains('önemli'));
\`\`\`

### Exception
\`\`\`dart
expect(() => divide(10, 0), throwsException);
expect(() => parseJson('invalid'), throwsFormatException);
\`\`\`

---

## 🔍 Neden Unit Test Yazmalıyız?

### ✅ Faydaları:

1. **Güven**: Kod değiştirince korkmadan refactor yapabilirsin
2. **Hız**: Bug'ları development'ta yakalarsan, production'da düzeltmekten 10x daha hızlı
3. **Dokümantasyon**: Testler kodun nasıl kullanılacağını gösterir
4. **Kalite**: Daha az bug, daha mutlu kullanıcı
5. **Uyku**: Gece rahat uyursun çünkü kodun test edilmiş 😴

### 💰 Maliyet Karşılaştırması:

| Aşama | Bug Düzeltme Maliyeti |
|-------|----------------------|
| Development (Unit Test) | 1x ⚡ |
| QA/Testing | 10x 💰 |
| Production | 100x 💸💸💸 |
| Kullanıcıda Patlama | 1000x 💀 |

**Sonuç:** Test yazmak, yazılan zamanı fazlasıyla geri kazandırır!

---

## 🎯 Best Practices (En İyi Uygulamalar)

### ✅ YAPIN:
- Her fonksiyon/metod için en az 1 test yazın
- Edge case'leri test edin (null, boş, negatif)
- Test adlarını açıklayıcı yapın
- AAA pattern kullanın (Arrange-Act-Assert)
- Testleri küçük ve bağımsız tutun

### ❌ YAPMAYIN:
- Testler birbirine bağımlı olmasın
- Gerçek API/Database kullanmayın (mock kullanın)
- Testleri atlayıp "sonra yazarım" demeyin
- Tüm kodu test etmeye çalışmayın (önemli yerleri test edin)

---

## 🔄 Test-Driven Development (TDD)

### Klasik Yöntem:
1. Kod yaz
2. Test yaz
3. Test et

### TDD Yöntem (Önerilen):
1. **❌ Test yaz (kırmızı - başarısız)**
2. **✅ Kodu yaz (yeşil - başarılı)**
3. **♻️ Refactor yap**
4. Tekrarla

**Avantajı:** Daha temiz kod, daha az bug!

---

## 📈 Coverage (Kapsama) Hedefleri

### Minimum Coverage:
- **Models**: 90%+ (kolay ve kritik)
- **Services**: 70%+ (business logic)
- **Widgets**: 50%+ (UI - opsiyonel)
- **Genel Proje**: 60%+

### Not:
> "100% coverage = %100 bug-free değildir!"
> Önemli olan, kritik kodların test edilmesidir.

---

## 🎓 Sonuç: Unit Test'in Altın Kuralı

> **"Hiç test yoksa, hiçbir şey çalışmıyor demektir."**
> **"Tüm testler geçiyorsa, her şey çalışıyor demektir."**

### Sizin Projenizde Şu An:
- ✅ **28 Test Yazıldı**
- ✅ **28 Test Başarılı**
- ✅ **Model Coverage: ~80%**
- ✅ **Güvenle Geliştirmeye Devam Edebilirsiniz!**

---

## 📚 Kaynaklar

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Test README](test/README.md) - Detaylı komutlar

---

## 🚀 Hızlı Başlangıç

1. Test dosyası oluştur: \`test/models/my_model_test.dart\`
2. Test yaz:
   \`\`\`dart
   import 'package:flutter_test/flutter_test.dart';
   
   void main() {
     test('İlk testim', () {
       expect(2 + 2, 4);
     });
   }
   \`\`\`
3. Çalıştır: \`flutter test\`
4. ✅ Başarılı!

---

## 💡 Sonraki Adımlar

1. ✅ **Yapıldı:** Model testleri
2. 📝 **Sonraki:** Servis testleri (API mock ile)
3. 📝 **Sonraki:** Widget testleri
4. 📝 **Sonraki:** Integration testleri
5. 📝 **Sonraki:** CI/CD entegrasyonu

---

**Happy Testing! 🧪✨**

> "Kod test edilmedikçe çalışmıyor sayılır." - Software Engineering Proverb

