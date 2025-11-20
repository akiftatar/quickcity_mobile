import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/issue.dart';
import '../services/api_service.dart';

class IssueDetailScreen extends StatefulWidget {
  final Issue issue;
  final ApiService apiService;

  const IssueDetailScreen({
    super.key,
    required this.issue,
    required this.apiService,
  });

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  late Issue _issue;

  @override
  void initState() {
    super.initState();
    _issue = widget.issue;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.issueDetail),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Durum ve Önem
            Row(
              children: [
                _buildStatusBadge(_issue.status),
                const SizedBox(width: 8),
                _buildPriorityBadge(_issue.priority),
              ],
            ),

            const SizedBox(height: 20),

            // Adres Bilgisi
            if (_issue.address != null && _issue.address!.isNotEmpty)
              ...[
                _buildSection(
                  title: l10n.address,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, size: 20, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _issue.address!,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

            // Açıklama
            _buildSection(
              title: l10n.description,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _issue.description ?? _issue.title,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Tarih Bilgileri
            _buildSection(
              title: l10n.reportDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text(
                      _issue.reportedAt,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Fotoğraflar
            if (_issue.imagePaths.isNotEmpty) ...[
              _buildSection(
                title: '${l10n.images} (${_issue.imagePaths.length})',
                child: SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _issue.imagePaths.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _showImageFullScreen(_issue.imagePaths[index]),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _issue.imagePaths[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, size: 40),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Admin Notları
            if (_issue.adminNotes != null && _issue.adminNotes!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSection(
                title: '💬 ${l10n.adminNotes}',
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[300]!, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note, size: 20, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _issue.adminNotes!,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_issue.resolvedBy != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.blue[700]),
                              const SizedBox(width: 6),
                              Text(
                                _issue.resolvedBy!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[900],
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'open':
        color = Colors.orange;
        text = l10n.open;
        icon = Icons.error_outline;
        break;
      case 'in_progress':
        color = Colors.blue;
        text = l10n.inProgress;
        icon = Icons.sync;
        break;
      case 'resolved':
        color = Colors.green;
        text = l10n.resolved;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.grey;
        text = l10n.cancelled;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        text = status;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String text;

    switch (priority) {
      case 'low':
        color = Colors.green;
        text = l10n.low;
        break;
      case 'medium':
        color = Colors.orange;
        text = l10n.medium;
        break;
      case 'high':
        color = Colors.red;
        text = l10n.high;
        break;
      case 'critical':
        color = Colors.purple;
        text = l10n.critical;
        break;
      default:
        color = Colors.grey;
        text = priority;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showImageFullScreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image, size: 64, color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
