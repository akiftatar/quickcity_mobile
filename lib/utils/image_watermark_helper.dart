import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'photo_metadata_helper.dart';

class ImageWatermarkHelper {
  /// Fotoğrafa watermark ekle
  static Future<File> addWatermark({
    required File imageFile,
    required PhotoMetadata metadata,
  }) async {
    try {
      // Resmi yükle
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw Exception('Resim yüklenemedi');
      }

      // Non-nullable değişkene ata
      img.Image image = decodedImage;

      // Watermark metnini oluştur
      final watermarkLines = _buildWatermarkLines(metadata);

      // Watermark alanı boyutları
      final lineHeight = 20;
      final padding = 10;
      final watermarkHeight = (watermarkLines.length * lineHeight) + (padding * 2);

      // Yarı saydam siyah arka plan çiz (alt kısım)
      image = img.fillRect(
        image,
        x1: 0,
        y1: image.height - watermarkHeight,
        x2: image.width,
        y2: image.height,
        color: img.ColorRgba8(0, 0, 0, 180), // Yarı saydam siyah
      );

      // Metinleri yaz
      int yPosition = image.height - watermarkHeight + padding;
      for (final line in watermarkLines) {
        image = img.drawString(
          image,
          line,
          font: img.arial14,
          x: padding,
          y: yPosition,
          color: img.ColorRgba8(255, 255, 255, 255), // Beyaz
        );
        yPosition += lineHeight;
      }

      // Kalıcı dosya olarak kaydet (cache yerine documents kullan)
      final documentsDir = await getApplicationDocumentsDirectory();
      final watermarkDir = Directory(path.join(documentsDir.path, 'watermarked_photos'));
      
      // Dizin yoksa oluştur
      if (!await watermarkDir.exists()) {
        await watermarkDir.create(recursive: true);
      }
      
      final fileName = 'watermarked_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final watermarkedFile = File(path.join(watermarkDir.path, fileName));

      // JPEG olarak kaydet
      final encodedImage = img.encodeJpg(image, quality: 90);
      await watermarkedFile.writeAsBytes(encodedImage);

      return watermarkedFile;
    } catch (e) {
      print('Watermark ekleme hatası: $e');
      // Hata durumunda orijinal dosyayı döndür
      return imageFile;
    }
  }

  /// Watermark için metin satırlarını oluştur
  static List<String> _buildWatermarkLines(PhotoMetadata metadata) {
    final lines = <String>[];

    // Tarih/Saat
    lines.add('${_getEmoji("📅")} ${metadata.formattedDate}');

    // GPS Koordinatları
    if (metadata.latitude != null && metadata.longitude != null) {
      lines.add(
        '${_getEmoji("📍")} ${metadata.latitude!.toStringAsFixed(6)}, ${metadata.longitude!.toStringAsFixed(6)}',
      );
    }

    // Kullanıcı
    lines.add('${_getEmoji("👤")} ${metadata.userName}');

    // Cihaz
    if (metadata.deviceModel != null) {
      lines.add('${_getEmoji("📱")} ${metadata.deviceModel}');
    }

    // Fotoğraf numarası
    lines.add('${_getEmoji("🔢")} Foto ${metadata.photoIndex}/${metadata.totalPhotos}');

    return lines;
  }

  /// Emoji karakterlerini ASCII'ye çevir (image paketi emoji desteklemiyor)
  static String _getEmoji(String emoji) {
    switch (emoji) {
      case "📅":
        return "[T]"; // Tarih
      case "📍":
        return "[L]"; // Lokasyon
      case "👤":
        return "[U]"; // User
      case "📱":
        return "[D]"; // Device
      case "🔢":
        return "[#]"; // Numara
      default:
        return "";
    }
  }

  /// Batch watermark ekleme (birden fazla fotoğraf için)
  static Future<List<File>> addWatermarkBatch({
    required List<File> imageFiles,
    required List<PhotoMetadata> metadataList,
  }) async {
    final watermarkedFiles = <File>[];

    for (int i = 0; i < imageFiles.length; i++) {
      if (i < metadataList.length) {
        final watermarkedFile = await addWatermark(
          imageFile: imageFiles[i],
          metadata: metadataList[i],
        );
        watermarkedFiles.add(watermarkedFile);
      } else {
        watermarkedFiles.add(imageFiles[i]);
      }
    }

    return watermarkedFiles;
  }

  /// Eski watermark dosyalarını temizle (24 saatten eski)
  static Future<void> cleanupOldWatermarks() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final watermarkDir = Directory(path.join(documentsDir.path, 'watermarked_photos'));
      
      if (await watermarkDir.exists()) {
        final files = await watermarkDir.list().toList();
        final now = DateTime.now();
        
        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            final age = now.difference(stat.modified);
            
            // 24 saatten eski dosyaları sil
            if (age.inHours > 24) {
              try {
                await file.delete();
                print('🗑️ Eski watermark dosyası silindi: ${file.path}');
              } catch (e) {
                print('❌ Dosya silinemedi: ${file.path} - $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ Watermark temizleme hatası: $e');
    }
  }
}
