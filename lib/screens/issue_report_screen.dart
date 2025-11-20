import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/loading_overlay.dart';
import '../utils/photo_metadata_helper.dart';
import '../utils/image_watermark_helper.dart';

class IssueReportScreen extends StatefulWidget {
  final Location location;
  final ApiService apiService;

  const IssueReportScreen({
    super.key,
    required this.location,
    required this.apiService,
  });

  @override
  State<IssueReportScreen> createState() => _IssueReportScreenState();
}

class _IssueReportScreenState extends State<IssueReportScreen> {
  static const int _maxImageBytes = 10 * 1024 * 1024; // 10 MB
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  String _selectedPriority = 'medium';
  List<File> _selectedImages = [];
  List<PhotoMetadata> _photoMetadataList = [];
  bool _isLoading = false;
  String _errorMessage = '';

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Eski watermark dosyalarını temizle
    ImageWatermarkHelper.cleanupOldWatermarks();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportIssue),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitIssue,
            child: Text(
              l10n.submit,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lokasyon bilgisi
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.location,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.location.displayAddress,
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (widget.location.customer != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${l10n.customer}: ${widget.location.customer!.name}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Önem derecesi
                Text(
                  l10n.priority,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildPriorityChip('low', l10n.low, Colors.green),
                    _buildPriorityChip('medium', l10n.medium, Colors.orange),
                    _buildPriorityChip('high', l10n.high, Colors.red),
                    _buildPriorityChip('critical', l10n.critical, Colors.purple),
                  ],
                ),

                const SizedBox(height: 16),

                // Açıklama (zorunlu)
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: '${l10n.description} *',
                    hintText: l10n.issueDescriptionHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.issueTitleRequired; // "Bu alan zorunludur"
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Fotoğraflar
                Text(
                  l10n.images,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.imagesHint,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),

                // Fotoğraf seçim butonları
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImageFromCamera,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(l10n.takePhoto),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: Text(l10n.chooseFromGallery),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Seçilen fotoğraflar
                if (_selectedImages.isNotEmpty) ...[
                  Text(
                    '${l10n.selectedImages} (${_selectedImages.length}/5)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              FutureBuilder<bool>(
                                future: _selectedImages[index].exists(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  
                                  if (snapshot.data == true) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _selectedImages[index],
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              color: Colors.red[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.error,
                                              color: Colors.red,
                                              size: 40,
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.error,
                                        color: Colors.red,
                                        size: 40,
                                      ),
                                    );
                                  }
                                },
                              ),
                              // Metadata bilgi butonu
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: GestureDetector(
                                  onTap: () => _showPhotoMetadata(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.info_outline,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                              // Silme butonu
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Hata mesajı
                if (_errorMessage.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Gönder butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitIssue,
                    icon: const Icon(Icons.send),
                    label: Text(l10n.submitIssue),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _selectedPriority == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPriority = value;
        });
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      side: BorderSide(color: color),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      // Kamera izni kontrol et
      final permission = await Permission.camera.request();
      if (permission != PermissionStatus.granted) {
        _showError(AppLocalizations.of(context)!.cameraPermissionRequired);
        return;
      }

      if (_selectedImages.length >= 5) {
        _showError(AppLocalizations.of(context)!.maxPhotosLimit);
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        // Loading göster
        setState(() {
          _isLoading = true;
        });

        try {
          // Metadata topla
          final authService = Provider.of<AuthService>(context, listen: false);
          final userName = authService.currentUser?.fullName ?? AppLocalizations.of(context)!.unknown;
          
          final metadata = await PhotoMetadataHelper.collectMetadata(
            userName: userName,
            locationAddress: widget.location.displayAddress,
            photoIndex: _selectedImages.length + 1,
            totalPhotos: _selectedImages.length + 1,
          );

          // Dosyanın var olduğunu kontrol et
          final originalFile = File(image.path);
          if (!await originalFile.exists()) {
            throw Exception('Seçilen fotoğraf dosyası bulunamadı');
          }

          // Watermark ekle
          final watermarkedFile = await ImageWatermarkHelper.addWatermark(
            imageFile: originalFile,
            metadata: metadata,
          );

          // Watermark'lanmış dosyanın var olduğunu kontrol et
          if (!await watermarkedFile.exists()) {
            throw Exception('Watermark ekleme işlemi başarısız');
          }

          final isSizeValid = await _validateImageSize(watermarkedFile);
          if (!isSizeValid) {
            await watermarkedFile.delete().catchError((_) {});
            setState(() {
              _isLoading = false;
            });
            return;
          }

          setState(() {
            _selectedImages.add(watermarkedFile);
            _photoMetadataList.add(metadata);
            _isLoading = false;
          });

          // Kullanıcıya bilgi göster
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📸 ${l10n.photoSaved}\n${metadata.formattedDate}'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          _showError(AppLocalizations.of(context)!.photoProcessingError.replaceAll('@error', e.toString()));
        }
      }
    } catch (e) {
      _showError(AppLocalizations.of(context)!.cameraError.replaceAll('@error', e.toString()));
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      if (_selectedImages.length >= 5) {
        _showError(AppLocalizations.of(context)!.maxPhotosLimit);
        return;
      }

      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        // Loading göster
        setState(() {
          _isLoading = true;
        });

        try {
          final authService = Provider.of<AuthService>(context, listen: false);
          final userName = authService.currentUser?.fullName ?? AppLocalizations.of(context)!.unknown;
          
          int processedCount = 0;
          
          // Her fotoğraf için metadata topla ve watermark ekle
          for (int i = 0; i < images.length && _selectedImages.length < 5; i++) {
            final metadata = await PhotoMetadataHelper.collectMetadata(
              userName: userName,
              locationAddress: widget.location.displayAddress,
              photoIndex: _selectedImages.length + 1,
              totalPhotos: _selectedImages.length + images.length,
            );

            // Dosyanın var olduğunu kontrol et
            final originalFile = File(images[i].path);
            if (!await originalFile.exists()) {
              print('❌ Dosya bulunamadı: ${images[i].path}');
              continue; // Bu dosyayı atla, diğerlerine devam et
            }

            // Watermark ekle
            final watermarkedFile = await ImageWatermarkHelper.addWatermark(
              imageFile: originalFile,
              metadata: metadata,
            );

            // Watermark'lanmış dosyanın var olduğunu kontrol et
            if (!await watermarkedFile.exists()) {
              print('❌ Watermark işlemi başarısız: ${images[i].path}');
              continue; // Bu dosyayı atla
            }

            final isSizeValid = await _validateImageSize(watermarkedFile);
            if (!isSizeValid) {
              await watermarkedFile.delete().catchError((_) {});
              continue;
            }

            setState(() {
              _selectedImages.add(watermarkedFile);
              _photoMetadataList.add(metadata);
            });
            
            processedCount++;
          }

          setState(() {
            _isLoading = false;
          });

          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📸 ${l10n.photosProcessed.replaceAll('@count', '$processedCount')}'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          _showError(AppLocalizations.of(context)!.photoProcessingError.replaceAll('@error', e.toString()));
        }
      }
    } catch (e) {
      _showError(AppLocalizations.of(context)!.galleryError.replaceAll('@error', e.toString()));
    }
  }

  void _removeImage(int index) {
    if (index >= 0 && index < _selectedImages.length) {
      setState(() {
        _selectedImages.removeAt(index);
        if (index < _photoMetadataList.length) {
          _photoMetadataList.removeAt(index);
        }
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  void _showPhotoMetadata(int index) {
    if (index >= _photoMetadataList.length) return;
    
    final metadata = _photoMetadataList[index];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info, color: Color(0xFF1976D2)),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.photoInformation),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMetadataRow('📅 Tarih/Saat', metadata.formattedDate),
              if (metadata.latitude != null && metadata.longitude != null) ...[
                const Divider(),
                _buildMetadataRow(
                  '📍 Koordinatlar',
                  '${metadata.latitude!.toStringAsFixed(6)}, ${metadata.longitude!.toStringAsFixed(6)}',
                ),
              ],
              const Divider(),
              _buildMetadataRow('👤 Kullanıcı', metadata.userName),
              const Divider(),
              _buildMetadataRow('🏢 Lokasyon', metadata.locationAddress),
              if (metadata.deviceModel != null) ...[
                const Divider(),
                _buildMetadataRow('📱 Cihaz', metadata.deviceModel!),
              ],
              if (metadata.deviceOS != null) ...[
                const Divider(),
                _buildMetadataRow('💻 İşletim Sistemi', metadata.deviceOS!),
              ],
              const Divider(),
              _buildMetadataRow(
                '🔢 Fotoğraf',
                '${metadata.photoIndex} / ${metadata.totalPhotos}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var suffixIndex = 0;
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    return '${size.toStringAsFixed(suffixIndex == 0 ? 0 : 1)} ${suffixes[suffixIndex]}';
  }

  Future<bool> _validateImageSize(File file) async {
    final fileSize = await file.length();
    if (fileSize > _maxImageBytes) {
      final limitMb = (_maxImageBytes / (1024 * 1024)).toStringAsFixed(0);
      final readableSize = _formatFileSize(fileSize);
      _showError('Fotoğraf boyutu $readableSize. Maksimum $limitMb MB yüklenebilir. Lütfen fotoğrafı küçülterek tekrar deneyin.');
      return false;
    }
    return true;
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      _showError(AppLocalizations.of(context)!.selectAtLeastOnePhoto);
      return;
    }

    // Dosya yollarının geçerli olup olmadığını kontrol et
    final validImages = <File>[];
    for (int i = 0; i < _selectedImages.length; i++) {
      final file = _selectedImages[i];
      if (await file.exists()) {
        validImages.add(file);
      } else {
        print('❌ Dosya bulunamadı, atlanıyor: ${file.path}');
      }
    }
    
    if (validImages.isEmpty) {
      _showError('Hiçbir fotoğraf dosyası bulunamadı. Lütfen fotoğrafları yeniden seçin.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    for (final file in validImages) {
      final isSizeValid = await _validateImageSize(file);
      if (!isSizeValid) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }
    
    if (validImages.length != _selectedImages.length) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${validImages.length}/${_selectedImages.length} fotoğraf gönderiliyor'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Metadata bilgilerini description'a ekle
      String fullDescription = _descriptionController.text.trim();
      
      if (_photoMetadataList.isNotEmpty) {
        fullDescription += '\n\n--- Fotoğraf Bilgileri ---\n';
        for (int i = 0; i < _photoMetadataList.length; i++) {
          final metadata = _photoMetadataList[i];
          fullDescription += '\nFotoğraf ${i + 1}:\n';
          fullDescription += '📅 ${metadata.formattedDate}\n';
          if (metadata.latitude != null && metadata.longitude != null) {
            fullDescription += '📍 ${metadata.latitude!.toStringAsFixed(6)}, ${metadata.longitude!.toStringAsFixed(6)}\n';
          }
          fullDescription += '👤 ${metadata.userName}\n';
          if (metadata.deviceModel != null) {
            fullDescription += '📱 ${metadata.deviceModel}\n';
          }
        }
      }
      
      // Connectivity kontrolü
      final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
      final syncService = Provider.of<SyncService>(context, listen: false);
      
      if (connectivityService.isOnline) {
        // ONLINE - Direkt API'ye gönder
        final result = await widget.apiService.reportIssue(
          locationId: widget.location.id,
          description: fullDescription,
          priority: _selectedPriority,
          images: validImages,
        );

        if (result['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true); // Başarılı bildirim
          }
        } else {
          _showError(result['message']);
        }
      } else {
        // OFFLINE - Pending olarak kaydet
        print('⚠️ Offline mod - Sorun pending olarak kaydediliyor...');
        
        final issueData = {
          'location_id': widget.location.id,
          'description': fullDescription,
          'priority': _selectedPriority,
          'image_paths': validImages.map((f) => f.path).toList(),
          'metadata': _photoMetadataList.map((m) => m.toJson()).toList(),
        };
        
        final tempId = await OfflineStorageService.savePendingIssue(issueData);
        await syncService.updatePendingCount();
        
        print('✅ Sorun offline kaydedildi: $tempId');
        
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.offlineSaved),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context, true); // Başarılı offline kayıt
        }
      }
    } catch (e) {
      print('❌ Sorun bildirme hatası: $e');
      _showError(AppLocalizations.of(context)!.unexpectedError.replaceAll('@error', e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
