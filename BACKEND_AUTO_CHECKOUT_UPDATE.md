# Backend - Otomatik Check-Out ile Check-In Güncellemesi

## 🎯 Amaç

Farklı session'da aktif check-in varsa, backend otomatik olarak eski check-in'i check-out yapıp yeni check-in'i gerçekleştirecek. Bu sayede kullanıcı daha sorunsuz bir deneyim yaşayacak.

## 📝 Backend Güncellemesi

### LocationLogService veya WorkSessionService - checkIn() Fonksiyonu

```php
public function checkIn(array $data): LocationLog
{
    // İş oturumunun aktif olduğunu kontrol et
    $session = WorkSession::findOrFail($data['work_session_id']);
    if ($session->status !== 'active') {
        throw new \Exception('İş oturumu aktif değil.');
    }
    
    // Aynı session içinde bu lokasyonda aktif check-in var mı kontrol et
    $activeCheckInSameSession = LocationLog::where('work_session_id', $data['work_session_id'])
        ->where('location_id', $data['location_id'])
        ->where('status', 'checked_in')
        ->first();
        
    if ($activeCheckInSameSession) {
        throw new \Exception('Bu iş oturumunda bu lokasyona zaten check-in yapılmış.');
    }
    
    // ✅ YENİ: Farklı session'da aktif check-in varsa otomatik check-out yap
    $activeCheckInOtherSession = LocationLog::where('user_id', $data['user_id'])
        ->where('location_id', $data['location_id'])
        ->where('status', 'checked_in')
        ->where('work_session_id', '!=', $data['work_session_id'])
        ->with('workSession')
        ->first();
        
    if ($activeCheckInOtherSession) {
        // Otomatik check-out yap
        $duration = $activeCheckInOtherSession->calculateDuration();
        
        $activeCheckInOtherSession->update([
            'checked_out_at' => now(),
            'check_out_latitude' => $data['latitude'] ?? $activeCheckInOtherSession->check_in_latitude,
            'check_out_longitude' => $data['longitude'] ?? $activeCheckInOtherSession->check_in_longitude,
            'check_out_notes' => 'Önceki session\'dan otomatik check-out (yeni session başlatıldı)',
            'status' => 'checked_out',
            'duration' => (int) $duration, // ✅ int'e cast et
        ]);
        
        // Log yaz (opsiyonel)
        \Log::info("Otomatik check-out yapıldı", [
            'log_id' => $activeCheckInOtherSession->id,
            'old_session_id' => $activeCheckInOtherSession->work_session_id,
            'new_session_id' => $data['work_session_id'],
            'location_id' => $data['location_id'],
            'user_id' => $data['user_id'],
            'duration_seconds' => $duration,
        ]);
    }
    
    // Şimdi yeni check-in yap
    return LocationLog::create([
        'work_session_id' => $data['work_session_id'],
        'location_id' => $data['location_id'],
        'user_id' => $data['user_id'],
        'checked_in_at' => now(),
        'check_in_latitude' => $data['latitude'] ?? null,
        'check_in_longitude' => $data['longitude'] ?? null,
        'check_in_notes' => $data['notes'] ?? null,
        'status' => 'checked_in',
    ]);
}
```

## ⚠️ Önemli Notlar

### 1. Transaction Kullanın

Eğer veritabanı tutarlılığını garantilemek istiyorsanız, otomatik check-out ve yeni check-in işlemlerini bir transaction içinde yapın:

```php
public function checkIn(array $data): LocationLog
{
    return DB::transaction(function () use ($data) {
        // ... tüm kontroller ve işlemler buraya ...
        
        // Otomatik check-out
        if ($activeCheckInOtherSession) {
            // ... check-out işlemi ...
        }
        
        // Yeni check-in
        return LocationLog::create([...]);
    });
}
```

### 2. calculateDuration() Fonksiyonunu Kontrol Edin

`calculateDuration()` fonksiyonunun **int** döndürdüğünden emin olun:

```php
// LocationLog.php
public function calculateDuration(): int
{
    if (!$this->checked_out_at || !$this->checked_in_at) {
        return 0;
    }
    
    $seconds = $this->checked_out_at->diffInSeconds($this->checked_in_at);
    return (int) $seconds; // ✅ int'e cast et
}
```

### 3. Check-Out Koordinatları

Otomatik check-out'ta:
- Eğer yeni check-in'de koordinat varsa, onu kullanın
- Yoksa eski check-in'in koordinatlarını kullanın
- Her ikisi de yoksa null bırakın

## ✅ Avantajlar

1. **Kullanıcı Deneyimi**: Kullanıcı manuel olarak eski session'ı bitirmek zorunda kalmaz
2. **Otomatik İşlem**: Backend otomatik olarak eski check-in'i kapatır
3. **Veri Bütünlüğü**: Her check-in bir check-out ile sonlanır
4. **Mobil Uygulama Basitleşir**: Mobil uygulama artık bu durumu handle etmek zorunda değil

## 🔄 Mobil Uygulama Etkisi

Backend güncellendikten sonra:
- ✅ Backend otomatik olarak eski check-in'i check-out yapacak
- ✅ Yeni check-in direkt başarılı olacak (400 hatası gelmeyecek)
- ✅ Mobil uygulamadaki farklı session kontrol kodları çalışmayacak (zarar vermez, sadece gereksiz)

**Sonuç:** Mobil uygulamada değişiklik yapmaya gerek yok. Mevcut kod geriye dönük uyumluluk için kalabilir.

## 📋 Test Senaryoları

1. ✅ Aynı session içinde tekrar check-in → Hata vermeli
2. ✅ Farklı session'da aktif check-in varsa → Otomatik check-out + yeni check-in
3. ✅ Check-out yapılmış lokasyona check-in → Normal check-in
4. ✅ İlk check-in → Normal check-in

