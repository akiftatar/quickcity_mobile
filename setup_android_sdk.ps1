# Android SDK Kurulum ve Yapılandırma Scripti
# PowerShell'i Yönetici olarak çalıştırın

Write-Host "=== Android SDK Kurulum ve Yapılandırma ===" -ForegroundColor Cyan
Write-Host ""

# 1. Android Studio SDK yolunu kontrol et
Write-Host "[1/4] Android SDK yolunu arıyorum..." -ForegroundColor Yellow

$sdkPaths = @(
    "$env:LOCALAPPDATA\Android\Sdk",
    "$env:LOCALAPPDATA\Android\sdk",
    "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk",
    "C:\Android\Sdk",
    "$env:ProgramFiles\Android\Android Studio\sdk"
)

$sdkPath = $null
foreach ($path in $sdkPaths) {
    if (Test-Path $path) {
        $sdkPath = $path
        Write-Host "✓ SDK bulundu: $sdkPath" -ForegroundColor Green
        break
    }
}

if (-not $sdkPath) {
    Write-Host "✗ Android SDK bulunamadı!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Android Studio'yu kurmanız gerekiyor:" -ForegroundColor Yellow
    Write-Host "1. https://developer.android.com/studio adresinden Android Studio'yu indirin" -ForegroundColor White
    Write-Host "2. Android Studio'yu kurun ve ilk açılışta SDK'yı kurun" -ForegroundColor White
    Write-Host "3. Android Studio'da: File > Settings > Appearance & Behavior > System Settings > Android SDK" -ForegroundColor White
    Write-Host "   'Android SDK Location' yolunu not edin" -ForegroundColor White
    Write-Host "4. Bu scripti tekrar çalıştırın veya SDK yolunu manuel olarak girin" -ForegroundColor White
    Write-Host ""
    
    $manualPath = Read-Host "SDK yolunu manuel olarak girmek ister misiniz? (y/n)"
    if ($manualPath -eq "y" -or $manualPath -eq "Y") {
        $sdkPath = Read-Host "SDK yolunu girin (örn: C:\Users\eta\AppData\Local\Android\Sdk)"
        if (-not (Test-Path $sdkPath)) {
            Write-Host "✗ Bu yol mevcut değil!" -ForegroundColor Red
            exit 1
        }
    } else {
        exit 1
    }
}

# 2. SDK yolunu doğrula
Write-Host ""
Write-Host "[2/4] SDK bileşenlerini kontrol ediyorum..." -ForegroundColor Yellow

$requiredPaths = @(
    "platform-tools",
    "tools",
    "platforms"
)

$missingPaths = @()
foreach ($requiredPath in $requiredPaths) {
    $fullPath = Join-Path $sdkPath $requiredPath
    if (Test-Path $fullPath) {
        Write-Host "✓ $requiredPath bulundu" -ForegroundColor Green
    } else {
        Write-Host "✗ $requiredPath bulunamadı" -ForegroundColor Yellow
        $missingPaths += $requiredPath
    }
}

if ($missingPaths.Count -gt 0) {
    Write-Host ""
    Write-Host "Bazı SDK bileşenleri eksik görünüyor." -ForegroundColor Yellow
    Write-Host "Android Studio'yu açıp SDK Manager'dan gerekli bileşenleri kurun:" -ForegroundColor White
    Write-Host "File > Settings > Appearance & Behavior > System Settings > Android SDK" -ForegroundColor White
}

# 3. Ortam değişkenlerini ayarla
Write-Host ""
Write-Host "[3/4] Ortam değişkenlerini ayarlıyorum..." -ForegroundColor Yellow

try {
    # ANDROID_HOME
    [System.Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdkPath, [System.EnvironmentVariableTarget]::User)
    Write-Host "✓ ANDROID_HOME = $sdkPath" -ForegroundColor Green
    
    # ANDROID_SDK_ROOT
    [System.Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $sdkPath, [System.EnvironmentVariableTarget]::User)
    Write-Host "✓ ANDROID_SDK_ROOT = $sdkPath" -ForegroundColor Green
    
    # PATH'e ekle
    $currentPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
    $pathsToAdd = @(
        "$sdkPath\platform-tools",
        "$sdkPath\tools",
        "$sdkPath\tools\bin"
    )
    
    $newPathEntries = @()
    foreach ($pathToAdd in $pathsToAdd) {
        if ($currentPath -notlike "*$pathToAdd*") {
            $newPathEntries += $pathToAdd
            Write-Host "✓ PATH'e eklendi: $pathToAdd" -ForegroundColor Green
        } else {
            Write-Host "→ PATH'te zaten var: $pathToAdd" -ForegroundColor Gray
        }
    }
    
    if ($newPathEntries.Count -gt 0) {
        $newPath = ($newPathEntries -join ";") + ";" + $currentPath
        [System.Environment]::SetEnvironmentVariable('Path', $newPath, [System.EnvironmentVariableTarget]::User)
    }
    
} catch {
    Write-Host "✗ Ortam değişkenleri ayarlanırken hata oluştu: $_" -ForegroundColor Red
    Write-Host "Scripti Yönetici olarak çalıştırdığınızdan emin olun!" -ForegroundColor Yellow
    exit 1
}

# 4. Flutter'a SDK yolunu söyle
Write-Host ""
Write-Host "[4/4] Flutter yapılandırmasını güncelliyorum..." -ForegroundColor Yellow

try {
    flutter config --android-sdk $sdkPath
    Write-Host "✓ Flutter SDK yolunu ayarladı" -ForegroundColor Green
} catch {
    Write-Host "✗ Flutter config hatası: $_" -ForegroundColor Red
}

# 5. Sonuçları göster
Write-Host ""
Write-Host "=== Kurulum Tamamlandı! ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "ÖNEMLI: PowerShell'i kapatıp yeniden açın veya bilgisayarı yeniden başlatın" -ForegroundColor Yellow
Write-Host "Ardından şu komutu çalıştırın: flutter doctor -v" -ForegroundColor White
Write-Host ""
Write-Host "SDK Yolu: $sdkPath" -ForegroundColor Gray
Write-Host ""


