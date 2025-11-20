import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/issue.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_storage_service.dart';
import '../widgets/skeleton_loaders.dart';
import 'issue_detail_screen.dart';

class MyIssuesScreen extends StatefulWidget {
  const MyIssuesScreen({super.key});

  @override
  State<MyIssuesScreen> createState() => _MyIssuesScreenState();
}

class _MyIssuesScreenState extends State<MyIssuesScreen> {
  final ApiService _apiService = ApiService();
  List<Issue> _issues = [];
  List<Map<String, dynamic>> _pendingIssues = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Search and filter
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedPriority;
  bool _showOnlyWithAdminNotes = false;
  String _sortBy = 'newest'; // newest, oldest, priority

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      // Token'ı set et
      if (authService.token != null) {
        _apiService.setToken(authService.token!);
      }

      if (connectivityService.isOnline) {
        // ONLINE - API'den çek
        final result = await _apiService.getIssues();

        if (result['success'] == true) {
          setState(() {
            _issues = result['issues'] ?? [];
          });

          // Offline'a da kaydet
          await OfflineStorageService.saveIssues(_issues);
        } else {
          setState(() {
            _errorMessage = result['message'] ?? AppLocalizations.of(context)!.issuesLoadFailed;
          });
        }
      } else {
        // OFFLINE - Cache'den yükle
        _issues = await OfflineStorageService.getIssues();
      }

      // Pending (offline bildirilen) sorunları da yükle
      _pendingIssues = await OfflineStorageService.getPendingIssues();

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.error.replaceAll('@error', e.toString());
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myIssues),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIssues,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const ListSkeleton(
              itemCount: 6,
              skeletonItem: IssueCardSkeleton(),
            )
          : _buildContent(),
    );
  }

  // Get filtered and sorted issues
  List<Issue> _getFilteredIssues() {
    var filtered = List<Issue>.from(_issues);
    
    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((issue) {
        final query = _searchQuery.toLowerCase();
        return issue.title.toLowerCase().contains(query) ||
               (issue.description?.toLowerCase().contains(query) ?? false) ||
               (issue.address?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    // Status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((issue) => issue.status == _selectedStatus).toList();
    }
    
    // Priority filter
    if (_selectedPriority != null) {
      filtered = filtered.where((issue) => issue.priority == _selectedPriority).toList();
    }
    
    // Admin notes filter
    if (_showOnlyWithAdminNotes) {
      filtered = filtered.where((issue) => 
        issue.adminNotes != null && issue.adminNotes!.isNotEmpty
      ).toList();
    }
    
    // Sort
    switch (_sortBy) {
      case 'newest':
        filtered.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.reportedAt.compareTo(b.reportedAt));
        break;
      case 'priority':
        final priorityOrder = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1};
        filtered.sort((a, b) {
          final aPriority = priorityOrder[a.priority.toLowerCase()] ?? 0;
          final bPriority = priorityOrder[b.priority.toLowerCase()] ?? 0;
          return bPriority.compareTo(aPriority);
        });
        break;
    }
    
    return filtered;
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadIssues,
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      );
    }

    if (_issues.isEmpty && _pendingIssues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.noIssuesYet,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final filteredIssues = _getFilteredIssues();
    final hasActiveFilters = _searchQuery.isNotEmpty || 
                            _selectedStatus != null || 
                            _selectedPriority != null || 
                            _showOnlyWithAdminNotes;

    return Column(
      children: [
        // İstatistik Dashboard
        _buildStatisticsDashboard(l10n),
        
        // Arama Çubuğu
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: '${l10n.search}... (${l10n.address}, ${l10n.description})',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: _showFilterDialog,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        // Hızlı Filtreler
        if (hasActiveFilters || _sortBy != 'newest')
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (hasActiveFilters)
                  _buildFilterChip(
                    label: l10n.clearFilters,
                    icon: Icons.clear_all,
                    onTap: () {
                      setState(() {
                        _searchQuery = '';
                        _selectedStatus = null;
                        _selectedPriority = null;
                        _showOnlyWithAdminNotes = false;
                      });
                    },
                    isActive: false,
                  ),
                _buildSortChip(l10n),
                if (_selectedStatus != null)
                  _buildFilterChip(
                    label: _getStatusText(_selectedStatus!, l10n),
                    icon: Icons.label,
                    onTap: () => setState(() => _selectedStatus = null),
                    isActive: true,
                  ),
                if (_selectedPriority != null)
                  _buildFilterChip(
                    label: _getPriorityText(_selectedPriority!, l10n),
                    icon: Icons.priority_high,
                    onTap: () => setState(() => _selectedPriority = null),
                    isActive: true,
                  ),
                if (_showOnlyWithAdminNotes)
                  _buildFilterChip(
                    label: l10n.hasAdminNotes,
                    icon: Icons.note,
                    onTap: () => setState(() => _showOnlyWithAdminNotes = false),
                    isActive: true,
                  ),
              ],
            ),
          ),

        // Sorun Listesi
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadIssues,
            child: filteredIssues.isEmpty && hasActiveFilters
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Filtrelere uygun sorun bulunamadı',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _selectedStatus = null;
                              _selectedPriority = null;
                              _showOnlyWithAdminNotes = false;
                            });
                          },
                          child: Text(l10n.clearFilters),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Pending (Offline) Sorunlar
                      if (_pendingIssues.isNotEmpty) ...[
                        _buildSectionHeader('📦 ${l10n.waitingSync}', _pendingIssues.length),
                        ..._pendingIssues.map((pending) => _buildPendingIssueCard(pending)),
                        const SizedBox(height: 16),
                      ],

                      // Sync Edilmiş Sorunlar
                      if (filteredIssues.isNotEmpty) ...[
                        _buildSectionHeader(
                          '📋 ${l10n.reportedIssues}',
                          filteredIssues.length,
                          total: _issues.length,
                        ),
                        ...filteredIssues.map((issue) => _buildIssueCard(issue)),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsDashboard(AppLocalizations l10n) {
    final openCount = _issues.where((i) => i.status == 'open').length;
    final inProgressCount = _issues.where((i) => i.status == 'in_progress').length;
    final resolvedCount = _issues.where((i) => i.status == 'resolved').length;
    final withNotesCount = _issues.where((i) => i.adminNotes != null && i.adminNotes!.isNotEmpty).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'İstatistikler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '${l10n.open}',
                  openCount.toString(),
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  l10n.inProgress,
                  inProgressCount.toString(),
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  l10n.resolved,
                  resolvedCount.toString(),
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  l10n.hasAdminNotes,
                  withNotesCount.toString(),
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isActive,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue[700],
      ),
    );
  }

  Widget _buildSortChip(AppLocalizations l10n) {
    String sortLabel;
    IconData sortIcon;
    
    switch (_sortBy) {
      case 'newest':
        sortLabel = 'En Yeni';
        sortIcon = Icons.arrow_downward;
        break;
      case 'oldest':
        sortLabel = 'En Eski';
        sortIcon = Icons.arrow_upward;
        break;
      case 'priority':
        sortLabel = 'Öncelik';
        sortIcon = Icons.priority_high;
        break;
      default:
        sortLabel = 'Sırala';
        sortIcon = Icons.sort;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sortIcon, size: 16),
            const SizedBox(width: 4),
            Text(sortLabel),
          ],
        ),
        selected: true,
        onSelected: (_) => _showSortDialog(l10n),
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.green[100],
        checkmarkColor: Colors.green[700],
      ),
    );
  }

  void _showFilterDialog() {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.filter),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Filter
              Text(
                'Durum',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterOption(
                    label: l10n.open,
                    value: 'open',
                    selected: _selectedStatus == 'open',
                    onTap: () {
                      setState(() {
                        _selectedStatus = _selectedStatus == 'open' ? null : 'open';
                      });
                    },
                  ),
                  _buildFilterOption(
                    label: l10n.inProgress,
                    value: 'in_progress',
                    selected: _selectedStatus == 'in_progress',
                    onTap: () {
                      setState(() {
                        _selectedStatus = _selectedStatus == 'in_progress' ? null : 'in_progress';
                      });
                    },
                  ),
                  _buildFilterOption(
                    label: l10n.resolved,
                    value: 'resolved',
                    selected: _selectedStatus == 'resolved',
                    onTap: () {
                      setState(() {
                        _selectedStatus = _selectedStatus == 'resolved' ? null : 'resolved';
                      });
                    },
                  ),
                  _buildFilterOption(
                    label: l10n.cancelled,
                    value: 'cancelled',
                    selected: _selectedStatus == 'cancelled',
                    onTap: () {
                      setState(() {
                        _selectedStatus = _selectedStatus == 'cancelled' ? null : 'cancelled';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Priority Filter
              Text(
                l10n.priority,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterOption(
                    label: l10n.low,
                    value: 'low',
                    selected: _selectedPriority == 'low',
                    onTap: () {
                      setState(() {
                        _selectedPriority = _selectedPriority == 'low' ? null : 'low';
                      });
                    },
                  ),
                  _buildFilterOption(
                    label: l10n.medium,
                    value: 'medium',
                    selected: _selectedPriority == 'medium',
                    onTap: () {
                      setState(() {
                        _selectedPriority = _selectedPriority == 'medium' ? null : 'medium';
                      });
                    },
                  ),
                  _buildFilterOption(
                    label: l10n.high,
                    value: 'high',
                    selected: _selectedPriority == 'high',
                    onTap: () {
                      setState(() {
                        _selectedPriority = _selectedPriority == 'high' ? null : 'high';
                      });
                    },
                  ),
                  _buildFilterOption(
                    label: l10n.critical,
                    value: 'critical',
                    selected: _selectedPriority == 'critical',
                    onTap: () {
                      setState(() {
                        _selectedPriority = _selectedPriority == 'critical' ? null : 'critical';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Admin Notes Filter
              CheckboxListTile(
                title: Text(l10n.hasAdminNotes),
                value: _showOnlyWithAdminNotes,
                onChanged: (value) {
                  setState(() {
                    _showOnlyWithAdminNotes = value ?? false;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption({
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  void _showSortDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sort),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('En Yeni'),
              value: 'newest',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('En Eski'),
              value: 'oldest',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text(l10n.priority),
              value: 'priority',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status, AppLocalizations l10n) {
    switch (status) {
      case 'open':
        return l10n.open;
      case 'in_progress':
        return l10n.inProgress;
      case 'resolved':
        return l10n.resolved;
      case 'cancelled':
        return l10n.cancelled;
      default:
        return status;
    }
  }

  String _getPriorityText(String priority, AppLocalizations l10n) {
    switch (priority) {
      case 'low':
        return l10n.low;
      case 'medium':
        return l10n.medium;
      case 'high':
        return l10n.high;
      case 'critical':
        return l10n.critical;
      default:
        return priority;
    }
  }

  Widget _buildSectionHeader(String title, int count, {int? total}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              total != null && total != count ? '$count / $total' : count.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingIssueCard(Map<String, dynamic> pending) {
    final l10n = AppLocalizations.of(context)!;
    
    final address = pending['address']?.toString() ?? 
                    pending['location']?['formatted_address']?.toString() ??
                    pending['location']?['address']?.toString();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pending['description']?.toString().split('\n').first ?? l10n.reportIssue,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Adres bilgisi
                      if (address != null && address.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Icon(Icons.location_off, size: 16, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              l10n.addressNotAvailable,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[400],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sync, size: 14, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              l10n.waitingSync,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.cloud_upload, color: Colors.orange[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    
    return Slidable(
      key: ValueKey(issue.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _openIssueDetail(issue),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.visibility,
            label: l10n.viewDetails,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _editIssue(issue),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: l10n.edit,
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _openIssueDetail(issue),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Önem rengi çubuğu
                    Container(
                      width: 4,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _getPriorityColor(issue.priority),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // İçerik
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Başlık
                          Text(
                            issue.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Adres bilgisi
                          if (issue.address != null && issue.address!.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    issue.address!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Icon(Icons.location_off, size: 16, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.addressNotAvailable,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[400],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          // Tarih
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                issue.reportedAt,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Durum ve diğer bilgiler
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildStatusBadge(issue.status),
                              if (issue.imagePaths.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.photo, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${issue.imagePaths.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (issue.adminNotes != null && issue.adminNotes!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.note, size: 14, color: Colors.blue[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.hasAdminNotes,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editIssue(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    
    // Şimdilik sadece bilgi ver
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.edit} ${issue.title}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String text;

    switch (status) {
      case 'open':
        color = Colors.orange;
        text = l10n.open;
        break;
      case 'in_progress':
        color = Colors.blue;
        text = l10n.inProgress;
        break;
      case 'resolved':
        color = Colors.green;
        text = l10n.resolved;
        break;
      case 'cancelled':
        color = Colors.grey;
        text = l10n.cancelled;
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    final normalizedPriority = priority.toLowerCase();
    switch (normalizedPriority) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _openIssueDetail(Issue issue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IssueDetailScreen(
          issue: issue,
          apiService: _apiService,
        ),
      ),
    ).then((_) => _loadIssues()); // Geri dönünce yenile
  }
}
