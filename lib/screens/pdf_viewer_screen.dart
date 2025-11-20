import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import '../l10n/app_localizations.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _currentPage = 1; // Kullanıcıya gösterilen sayfa (1'den başlar)
  int _totalPages = 0;
  bool _isReady = false;
  String _errorMessage = '';
  PDFViewController? _pdfViewController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          if (_isReady && _totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.close),
                  ),
                ],
              ),
            )
          : PDFView(
              filePath: widget.filePath,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              pageSnap: true,
              defaultPage: _currentPage,
              fitPolicy: FitPolicy.BOTH,
              preventLinkNavigation: false,
              onRender: (pages) {
                setState(() {
                  _totalPages = pages ?? 0;
                  _isReady = true;
                  _currentPage = 1; // İlk sayfa
                });
              },
              onError: (error) {
                setState(() {
                  _errorMessage = 'PDF yüklenirken hata oluştu: $error';
                });
              },
              onPageError: (page, error) {
                setState(() {
                  _errorMessage = 'Sayfa $page yüklenirken hata: $error';
                });
              },
              onViewCreated: (PDFViewController pdfViewController) {
                setState(() {
                  _pdfViewController = pdfViewController;
                });
              },
              onLinkHandler: (String? uri) {
                // PDF içindeki linkler için
              },
              onPageChanged: (int? page, int? total) {
                setState(() {
                  _currentPage = (page ?? 0) + 1; // PDFView 0-indexed, UI 1-indexed
                });
              },
            ),
      bottomNavigationBar: _isReady && _totalPages > 1
          ? Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    onPressed: _currentPage > 1 && _pdfViewController != null
                        ? () async {
                            await _pdfViewController!.setPage(0);
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1 && _pdfViewController != null
                        ? () async {
                            await _pdfViewController!.setPage(_currentPage - 2);
                          }
                        : null,
                  ),
                  Text(
                    'Sayfa $_currentPage / $_totalPages',
                    style: const TextStyle(fontSize: 14),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _totalPages && _pdfViewController != null
                        ? () async {
                            await _pdfViewController!.setPage(_currentPage);
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page),
                    onPressed: _currentPage < _totalPages && _pdfViewController != null
                        ? () async {
                            await _pdfViewController!.setPage(_totalPages - 1);
                          }
                        : null,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
