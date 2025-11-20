import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'issue_report_screen.dart';
import 'pdf_viewer_screen.dart';

class LocationDetailScreen extends StatefulWidget {
  final Location location;
  final ApiService apiService;

  const LocationDetailScreen({
    super.key,
    required this.location,
    required this.apiService,
  });

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  bool _isLoadingPdf = false;
  String? _pdfPath;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAdmin = authService.currentUser?.isAdmin ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.locationDetails),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          // Sorun bildir butonu
          IconButton(
            icon: const Icon(Icons.report_problem),
            onPressed: _reportIssue,
            tooltip: l10n.reportIssue,
          ),
          if (widget.location.attachments.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _downloadAndViewPdf,
              tooltip: l10n.viewPdf,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Adres Bilgileri
            _buildSection(
              title: l10n.address,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.location.displayAddress,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.location.description != null && 
                      widget.location.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.location.description!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Konum Bilgileri
            _buildSection(
              title: l10n.location,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(l10n.latitude, widget.location.lat.toString()),
                  _buildInfoRow(l10n.longitude, widget.location.lng.toString()),
                  _buildInfoRow(l10n.city, widget.location.city ?? '-'),
                  _buildInfoRow(l10n.state, widget.location.state ?? '-'),
                  _buildInfoRow(l10n.zipCode, widget.location.zip ?? '-'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Müşteri Bilgileri (Sadece Admin/SuperAdmin)
            if (isAdmin && widget.location.customer != null) ...[
              _buildSection(
                title: l10n.customer,
                child: _buildInfoRow(
                  l10n.customerName,
                  widget.location.customer!.name,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Çalışma Alanları (Sadece Admin/SuperAdmin)
            if (isAdmin) ...[
              _buildSection(
                title: l10n.workAreas,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      l10n.gehwege1,
                      '${widget.location.workAreas.gehwege1.toStringAsFixed(2)} m²',
                    ),
                    _buildInfoRow(
                      l10n.gehwege15,
                      '${widget.location.workAreas.gehwege15.toStringAsFixed(2)} m²',
                    ),
                    _buildInfoRow(
                      l10n.parkingSpacesSurface,
                      '${widget.location.workAreas.parkingSpacesSurface.toStringAsFixed(2)} m²',
                    ),
                    _buildInfoRow(
                      l10n.parkingSpacesPaths,
                      '${widget.location.workAreas.parkingSpacesPaths.toStringAsFixed(2)} m²',
                    ),
                    _buildInfoRow(
                      l10n.handreinigung,
                      '${widget.location.workAreas.handreinigung.toStringAsFixed(2)} m²',
                    ),
                    const Divider(),
                    _buildInfoRow(
                      l10n.totalArea,
                      '${widget.location.workAreas.totalArea.toStringAsFixed(2)} m²',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Rotalama Bilgileri
            _buildSection(
              title: l10n.routing,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    l10n.waypointIndex,
                    widget.location.waypointIndex?.toString() ?? '-',
                  ),
                  _buildInfoRow(
                    l10n.isRouted,
                    widget.location.isRouted ? l10n.yes : l10n.no,
                  ),
                  _buildInfoRow(
                    l10n.clusterLabel,
                    widget.location.clusterLabel,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // PDF Attachments
            if (widget.location.attachments.isNotEmpty)
              _buildSection(
                title: l10n.attachments,
                child: Column(
                  children: widget.location.attachments.map((attachment) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(attachment.toString()),
                        trailing: _isLoadingPdf
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download),
                        onTap: _downloadAndViewPdf,
                      ),
                    );
                  }).toList(),
                ),
              ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
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
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: isTotal ? const Color(0xFF1976D2) : Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal ? const Color(0xFF1976D2) : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndViewPdf() async {
    if (widget.location.attachments.isEmpty) return;

    setState(() {
      _isLoadingPdf = true;
      _errorMessage = null;
    });

    try {
      // İlk attachment'ı al
      final attachment = widget.location.attachments.first.toString();
      
      // PDF URL'ini oluştur
      final pdfUrl = 'http://212.91.237.42/storage/$attachment';
      
      // AuthService'ten token al
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Dio ile PDF'yi indir
      final dio = Dio();
      
      // Token varsa header'a ekle
      if (authService.token != null) {
        dio.options.headers['Authorization'] = 'Bearer ${authService.token}';
      }
      
      // Geçici dizin al
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(attachment);
      final filePath = path.join(tempDir.path, fileName);
      
      // Dosya zaten varsa indirme
      final file = File(filePath);
      if (!await file.exists()) {
        // PDF'yi indir
        await dio.download(
          pdfUrl,
          filePath,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
            validateStatus: (status) => status! < 500,
          ),
        );
        
        // Dosyanın var olduğunu kontrol et
        if (!await file.exists()) {
          throw Exception('PDF dosyası indirilemedi');
        }
      }
      
      // PDF viewer ekranını aç
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              filePath: filePath,
              fileName: fileName,
            ),
          ),
        );
        
        // Başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.openingPdf}: $attachment'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'PDF yüklenirken hata oluştu: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF yüklenirken hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingPdf = false;
      });
    }
  }

  void _reportIssue() {
    final l10n = AppLocalizations.of(context)!;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IssueReportScreen(
          location: widget.location,
          apiService: widget.apiService,
        ),
      ),
    ).then((success) {
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.issueReportedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
}
