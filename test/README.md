# 🧪 Test Kılavuzu

## Test Çalıştırma

### Tüm Testleri Çalıştır
```bash
flutter test
```

### Belirli Bir Test Dosyasını Çalıştır
```bash
flutter test test/models/user_test.dart
```

### Verbose Mod (Detaylı Çıktı)
```bash
flutter test --verbose
```

### Coverage Raporu Oluştur
```bash
flutter test --coverage
```

Sonra coverage raporunu görüntüle:
```bash
# Windows
genhtml coverage/lcov.info -o coverage/html
start coverage/html/index.html

# Mac/Linux
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Test Yapısı

### 📁 Klasör Organizasyonu
```
test/
  ├── models/               # Model testleri
  │   ├── user_test.dart
  │   ├── location_test.dart
  │   └── issue_test.dart
  │
  ├── services/             # Servis testleri
  │   ├── auth_service_test.dart
  │   ├── api_service_test.dart
  │   └── work_session_service_test.dart
  │
  ├── widgets/              # Widget testleri (opsiyonel)
  │   └── location_card_test.dart
  │
  └── integration/          # Entegrasyon testleri (opsiyonel)
      └── login_flow_test.dart
```

---

## Test Yazma Kuralları

### ✅ İyi Test Özellikleri:
1. **Bağımsız**: Her test diğerlerinden bağımsız çalışmalı
2. **Hızlı**: Milisaniyeler içinde tamamlanmalı
3. **Tekrarlanabilir**: Her seferinde aynı sonucu vermeli
4. **Anlaşılır**: Ne test edildiği açıkça anlaşılmalı
5. **Bakımı Kolay**: Kod değişince güncellemesi kolay olmalı

### 📝 Test Yazma Kalıbı (AAA Pattern):

```dart
test('Test açıklaması', () {
  // Arrange (Hazırlık): Test verilerini hazırla
  final user = User(
    id: '1',
    username: 'test',
    firstname: 'Test',
    lastname: 'User',
    email: 'test@test.com',
    roles: ['admin'],
    createdAt: '',
    updatedAt: '',
  );

  // Act (Aksiyon): Test edilecek kodu çalıştır
  final isAdmin = user.isAdmin;

  // Assert (Doğrulama): Sonucu kontrol et
  expect(isAdmin, true);
});
```

---

## Expect (Doğrulama) Örnekleri

### Temel Eşitlikler
```dart
expect(actualValue, expectedValue);
expect(2 + 2, 4);
expect(user.name, 'Ahmet');
```

### Boolean Kontroller
```dart
expect(user.isAdmin, isTrue);
expect(user.isActive, isFalse);
```

### Null Kontroller
```dart
expect(user.email, isNotNull);
expect(user.phoneNumber, isNull);
```

### Koleksiyon Kontroller
```dart
expect(locations, isEmpty);
expect(locations, isNotEmpty);
expect(locations.length, 5);
expect(locations, contains(location1));
```

### Tip Kontroller
```dart
expect(user, isA<User>());
expect(locations, isA<List<Location>>());
```

### Sayı Karşılaştırmaları
```dart
expect(area, greaterThan(0));
expect(temperature, lessThan(100));
expect(price, closeTo(99.99, 0.01)); // 99.99 ± 0.01
```

### String Kontroller
```dart
expect(address, startsWith('Berlin'));
expect(email, endsWith('@test.com'));
expect(text, contains('önemli'));
```

### Exception Testleri
```dart
expect(() => divide(10, 0), throwsException);
expect(() => parseJson('invalid'), throwsFormatException);
```

---

## Mock Kullanımı (İleri Seviye)

Gerçek API'leri test etmek yerine mock (sahte) veriler kullanırız.

### Mockito Paketi Ekle
```yaml
dev_dependencies:
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

### Mock Oluştur
```dart
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Mock sınıfları oluştur
@GenerateMocks([ApiService])
void main() {
  test('API çağrısı mock ile test edilir', () async {
    // Mock servis oluştur
    final mockApiService = MockApiService();
    
    // Mock davranışı tanımla
    when(mockApiService.login('test@test.com', 'password'))
        .thenAnswer((_) async => {
          'success': true,
          'token': 'fake_token',
        });
    
    // Mock servisi kullan
    final result = await mockApiService.login('test@test.com', 'password');
    
    // Doğrula
    expect(result['success'], true);
    expect(result['token'], 'fake_token');
    
    // Çağrının yapıldığını doğrula
    verify(mockApiService.login('test@test.com', 'password')).called(1);
  });
}
```

---

## Widget Testing Örneği

```dart
testWidgets('Login butonu tıklanabilir olmalı', (WidgetTester tester) async {
  // Widget'ı oluştur
  await tester.pumpWidget(
    MaterialApp(
      home: LoginScreen(),
    ),
  );

  // Email ve password gir
  await tester.enterText(
    find.byKey(const Key('email_field')),
    'test@test.com',
  );
  await tester.enterText(
    find.byKey(const Key('password_field')),
    'password123',
  );

  // Login butonunu bul ve tıkla
  final loginButton = find.text('Giriş Yap');
  expect(loginButton, findsOneWidget);
  
  await tester.tap(loginButton);
  await tester.pump(); // Widget'ı yeniden çiz

  // Sonucu kontrol et
  expect(find.text('Yükleniyor...'), findsOneWidget);
});
```

---

## Test Coverage Hedefleri

### ✅ Minimum Coverage:
- **Models**: 90%+ (kolay ve önemli)
- **Services**: 70%+ (business logic)
- **Widgets**: 50%+ (UI testleri opsiyonel)
- **Genel**: 60%+

### 📊 Coverage Raporunu Kontrol Et:
```bash
flutter test --coverage
lcov --summary coverage/lcov.info
```

---

## Continuous Integration (CI)

### GitHub Actions Örneği
`.github/workflows/test.yml`:
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info
```

---

## Faydalı Komutlar

```bash
# Tek bir test grubu çalıştır
flutter test --name "User Model Tests"

# Testleri paralel çalıştır (hızlandırır)
flutter test --concurrency=4

# Watch mode (kod değişince otomatik çalıştır)
flutter test --watch

# Sadece başarısız testleri göster
flutter test --reporter=compact

# Test dosyalarını pattern ile filtrele
flutter test test/models/
```

---

## Sık Karşılaşılan Hatalar

### 1. "Null check operator used on a null value"
```dart
// ❌ Yanlış
expect(user.email, 'test@test.com');

// ✅ Doğru
expect(user.email, isNotNull);
expect(user.email, 'test@test.com');
```

### 2. "setUp ve tearDown"
```dart
void main() {
  late AuthService authService;
  
  // Her test öncesi çalışır
  setUp(() {
    authService = AuthService();
  });
  
  // Her test sonrası çalışır
  tearDown(() {
    authService.dispose();
  });
  
  test('Test 1', () {
    // authService kullanılabilir
  });
}
```

### 3. "Async test"
```dart
// ❌ Yanlış (async/await unutulmuş)
test('Async test', () {
  final result = authService.login('test@test.com', 'password');
  expect(result['success'], true);
});

// ✅ Doğru
test('Async test', () async {
  final result = await authService.login('test@test.com', 'password');
  expect(result['success'], true);
});
```

---

## Kaynaklar

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Test Coverage Best Practices](https://martinfowler.com/bliki/TestCoverage.html)

---

## 🎯 Hızlı Başlangıç

1. Test dosyası oluştur: `test/models/user_test.dart`
2. Test yaz:
   ```dart
   import 'package:flutter_test/flutter_test.dart';
   
   void main() {
     test('İlk testim', () {
       expect(2 + 2, 4);
     });
   }
   ```
3. Çalıştır: `flutter test`
4. Başarılı! ✅

---

## ⚡ Pro İpuçları

1. **Her commit öncesi testleri çalıştır**
2. **Önce test yaz, sonra kodu yaz (TDD)**
3. **Test adlarını açıklayıcı yaz**
4. **Edge case'leri test et (null, boş liste, negatif sayı)**
5. **100% coverage hedefleme, önemli yerleri test et**
6. **Mock kullanarak testleri hızlandır**
7. **CI/CD'ye entegre et**

Happy Testing! 🚀

