import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'main.dart';
import 'widgets/ai_chat_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    this.isAdmin = false,
  });

  final Map<String, dynamic> user;
  final bool isAdmin;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  String? _profileImageUrl;
  bool _isUploading = false;
  bool _showSuccessBanner = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Use 4 tabs if admin, 3 tabs if regular user
    final tabCount = widget.isAdmin ? 4 : 3;
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes to update icons
    });
    _loadProfilePhoto();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfilePhoto() async {
    final path = widget.user['profile_photo_path'] as String?;
    if (path == null || path.isEmpty) {
      return;
    }
    final url = _supabase.storage.from('profile-photos').getPublicUrl(path);
    setState(() {
      _profileImageUrl = _cacheBustedUrl(url);
    });
  }

  String _cacheBustedUrl(String url) =>
      '$url?cb=${DateTime.now().millisecondsSinceEpoch}';

  Future<void> _chooseSourceAndUpload() async {
    if (_isUploading) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Upload profile photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickAndUpload(ImageSource.camera);
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickAndUpload(ImageSource.gallery);
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade200,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      setState(() {
        _isUploading = true;
      });
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      final bytes = await picked.readAsBytes();
      await _uploadToSupabase(
        bytes: bytes,
        fileExt: picked.name.split('.').last,
        mimeType: picked.mimeType ?? 'image/${picked.name.split('.').last}',
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _uploadToSupabase({
    required Uint8List bytes,
    required String fileExt,
    required String mimeType,
  }) async {
    final storage = _supabase.storage.from('profile-photos');
    final userId = (widget.user['id'] ?? widget.user['email']).toString();
    final sanitizedExt = fileExt.toLowerCase();
    final filePath =
        '$userId/profile-${DateTime.now().millisecondsSinceEpoch}.$sanitizedExt';

    await storage.uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );

    await _supabase
        .from('users')
        .update({'profile_photo_path': filePath})
        .eq('id', widget.user['id']);

    final url = storage.getPublicUrl(filePath);

    if (!mounted) return;
    setState(() {
      _profileImageUrl = _cacheBustedUrl(url);
      _isUploading = false;
      _showSuccessBanner = true;
    });

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showSuccessBanner = false);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile photo uploaded successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurple.shade900,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ChaRo Parcel Tracker',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Hello, ${widget.user['full_name']}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: _chooseSourceAndUpload,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? Icon(Icons.person_outline,
                              color: Colors.white.withOpacity(0.8), size: 30)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3.0,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: [
              Tab(
                icon: Icon(
                  _tabController.index == 0
                      ? Icons.home
                      : Icons.home_outlined,
                ),
                text: 'Home',
              ),
              Tab(
                icon: Icon(
                  _tabController.index == 1
                      ? Icons.person
                      : Icons.person_outline,
                ),
                text: 'Profile',
              ),
              Tab(
                icon: Icon(
                  _tabController.index == 2
                      ? Icons.settings
                      : Icons.settings_outlined,
                ),
                text: 'Settings',
              ),
              // Admin tab - only show if user is admin
              if (widget.isAdmin)
                Tab(
                  icon: Icon(
                    _tabController.index == 3
                        ? Icons.admin_panel_settings
                        : Icons.admin_panel_settings_outlined,
                  ),
                  text: 'Admin',
                ),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade900,
                Colors.indigo.shade900,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              if (_showSuccessBanner)
                Container(
                  width: double.infinity,
                  color: Colors.green.withOpacity(0.15),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Profile photo updated successfully!',
                        style: TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _HomeTab(user: widget.user),
                    _ProfileTab(
                      user: widget.user,
                      isUploading: _isUploading,
                      onUploadRequested: _chooseSourceAndUpload,
                    ),
                    _SettingsTab(),
                    // Admin tab - only show if user is admin
                    if (widget.isAdmin) _AdminTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.user});

  final Map<String, dynamic> user;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _recentParcels = [];
  int _activeParcelsCount = 0;
  int _arrivingTodayCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParcels();
  }

  Future<void> _loadParcels() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.user['id'];
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Fetch all parcels for this user
      final allParcels = await _supabase
          .from('parcels')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Filter active parcels (not Delivered)
      final activeParcels = (allParcels as List)
          .where((p) => (p['status'] as String?)?.toLowerCase() != 'delivered')
          .toList();

      // Count parcels arriving today (you can customize this logic)
      // For now, we'll count in-transit parcels
      final arrivingToday = activeParcels
          .where((p) => (p['status'] as String?)?.toLowerCase() == 'in transit')
          .length;

      // Get recent parcels (last 5)
      final recentParcels = (allParcels as List).take(5).toList();

      if (mounted) {
        setState(() {
          _activeParcelsCount = activeParcels.length;
          _arrivingTodayCount = arrivingToday;
          _recentParcels = recentParcels.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddParcelDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => _AddParcelDialog(user: widget.user),
    );
    
    // Refresh parcels after adding
    if (result == true) {
      _loadParcels();
    }
  }

  void _showTrackParcelDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => _TrackParcelDialog(user: widget.user),
    );
  }

  void _showAIChatDialog(BuildContext context) {
    final userId = widget.user['id']?.toString() ?? '';
    final userName = widget.user['full_name']?.toString() ?? 'User';
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => AIChatDialog(
        userId: userId,
        userName: userName,
      ),
    );
  }

  void _showLiveMapDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => _LiveMapDialog(user: widget.user),
    );
  }

  String _formatStatus(String? status, DateTime? createdAt) {
    if (status == null) return 'Unknown';
    
    final statusLower = status.toLowerCase();
    String timeAgo = '';
    
    if (createdAt != null) {
      final now = DateTime.now();
      final difference = now.difference(createdAt);
      
      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        timeAgo = 'Just now';
      }
    }

    switch (statusLower) {
      case 'delivered':
        return 'Delivered • $timeAgo';
      case 'in transit':
        return 'In Transit • ETA: 4 hours';
      case 'pending':
        return 'Pending • $timeAgo';
      case 'out for delivery':
        return 'Out for Delivery • $timeAgo';
      default:
        return '$status • $timeAgo';
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'delivered':
        return Colors.green;
      case 'in transit':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'out for delivery':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getCardColor(String? status) {
    if (status == null) return Colors.grey.shade200;
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'delivered':
        return const Color(0xFFC8E6C9); // Light green
      case 'in transit':
        return const Color(0xFFFFF9C4); // Light yellow
      case 'pending':
        return const Color(0xFFBBDEFB); // Light blue
      case 'out for delivery':
        return const Color(0xFFE1BEE7); // Light purple
      default:
        return Colors.grey.shade200;
    }
  }

  IconData _getStatusIcon(String? status) {
    if (status == null) return Icons.help_outline;
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'delivered':
        return Icons.check_circle;
      case 'in transit':
      case 'out for delivery':
        return Icons.local_shipping_rounded;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadParcels,
        color: Colors.deepPurple,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Parcels Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF9B59B6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Parcels',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _isLoading
                            ? const SizedBox(
                                height: 48,
                                width: 48,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 3,
                                ),
                              )
                            : Text(
                                '$_activeParcelsCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        const SizedBox(height: 4),
                        Text(
                          _arrivingTodayCount > 0
                              ? '$_arrivingTodayCount arriving today'
                              : 'No arrivals today',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 60,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Quick Action Buttons
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.add_box_outlined,
                    label: 'Add Parcel',
                    color: const Color(0xFFE1BEE7), // Light purple
                    onTap: () {
                      _showAddParcelDialog(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'Track Parcel',
                    color: const Color(0xFFB2DFDB), // Light teal
                    onTap: () {
                      _showTrackParcelDialog(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.map_outlined,
                    label: 'Live Map',
                    color: const Color(0xFFFFCCBC), // Light orange
                    onTap: () {
                      _showLiveMapDialog(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Recent Parcels Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Parcels',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to all parcels
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF9B59B6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Parcel Cards
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _recentParcels.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No parcels yet',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first parcel to get started',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: _recentParcels.map((parcel) {
                          final parcelId = parcel['parcel_id'] as String? ?? 'N/A';
                          final fromCounty = parcel['from_county'] as String? ?? '';
                          final toCounty = parcel['to_county'] as String? ?? '';
                          final status = parcel['status'] as String?;
                          final createdAt = parcel['created_at'] != null
                              ? DateTime.tryParse(parcel['created_at'].toString())
                              : null;
                          
                          final statusText = _formatStatus(status, createdAt);
                          final statusColor = _getStatusColor(status);
                          final cardColor = _getCardColor(status);
                          final statusIcon = _getStatusIcon(status);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ParcelCard(
                              parcelId: parcelId,
                              route: '$fromCounty → $toCounty',
                              status: statusText,
                              statusColor: statusColor,
                              backgroundColor: cardColor,
                              icon: statusIcon,
                              iconColor: statusColor,
                            ),
                          );
                        }).toList(                      ),
                    ),
          ],
        ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAIChatDialog(context);
        },
        backgroundColor: const Color(0xFF7B1FA2), // Dark purple
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({
    required this.parcelId,
    required this.route,
    required this.status,
    required this.statusColor,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  final String parcelId;
  final String route;
  final String status;
  final Color statusColor;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to parcel details
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withOpacity(0.3), width: 2),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parcelId,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    route,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 13,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.user,
    required this.isUploading,
    required this.onUploadRequested,
  });

  final Map<String, dynamic> user;
  final bool isUploading;
  final VoidCallback onUploadRequested;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cards = [
      {
        'label': 'Full name',
        'value': user['full_name'] ?? '',
        'icon': Icons.person_outline,
      },
      {
        'label': 'Email',
        'value': user['email'] ?? '',
        'icon': Icons.email_outlined,
      },
      {
        'label': 'Member since',
        'value': _formatDate(user['created_at']),
        'icon': Icons.calendar_today_outlined,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your profile',
                  style: textTheme.titleMedium
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...cards.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                          ),
                          child: Icon(item['icon'] as IconData, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['label'] as String,
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['value'] as String,
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile photo',
                  style: textTheme.titleMedium
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Upload or change your profile picture. You can pick from your gallery or take a new photo.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: isUploading ? null : onUploadRequested,
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(isUploading ? 'Uploading...' : 'Upload photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '—';
    try {
      final dt = DateTime.tryParse(rawDate.toString());
      if (dt == null) return '—';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '—';
    }
  }
}

// Settings Tab
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 12),
              Text('Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
  }

  void _handleLogout(BuildContext context) {
    // Navigate to AuthScreen (sign-in page)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // Logout Button
                GestureDetector(
                  onTap: () => _showLogoutDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.2),
                          ),
                          child: const Icon(
                            Icons.logout,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Logout',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Sign out from your account',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 47 Counties of Kenya
const List<String> _kenyaCounties = [
  'Baringo', 'Bomet', 'Bungoma', 'Busia', 'Elgeyo-Marakwet',
  'Embu', 'Garissa', 'Homa Bay', 'Isiolo', 'Kajiado',
  'Kakamega', 'Kericho', 'Kiambu', 'Kilifi', 'Kirinyaga',
  'Kisii', 'Kisumu', 'Kitui', 'Kwale', 'Laikipia',
  'Lamu', 'Machakos', 'Makueni', 'Mandera', 'Marsabit',
  'Meru', 'Migori', 'Mombasa', 'Murang\'a', 'Nairobi',
  'Nakuru', 'Nandi', 'Narok', 'Nyamira', 'Nyandarua',
  'Nyeri', 'Samburu', 'Siaya', 'Taita-Taveta', 'Tana River',
  'Tharaka-Nithi', 'Trans Nzoia', 'Turkana', 'Uasin Gishu',
  'Vihiga', 'Wajir', 'West Pokot'
];

const List<String> _courierServices = [
  'G4S',
  'EASYCOACH',
  'ENACOACH',
  'COASTLINE',
  'MBUKINYA',
];

class _AddParcelDialog extends StatefulWidget {
  const _AddParcelDialog({required this.user});

  final Map<String, dynamic> user;

  @override
  State<_AddParcelDialog> createState() => _AddParcelDialogState();
}

class _AddParcelDialogState extends State<_AddParcelDialog> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _valueController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  
  String? _fromCounty;
  String? _toCounty;
  String? _courierService;
  bool _isLoading = false;
  String? _generatedParcelId;

  @override
  void initState() {
    super.initState();
    _generateParcelId();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _weightController.dispose();
    _valueController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  Future<void> _generateParcelId() async {
    try {
      // Get the highest parcel number for the current year
      final currentYear = DateTime.now().year;
      final parcels = await _supabase
          .from('parcels')
          .select('parcel_id')
          .like('parcel_id', 'PARC-%-$currentYear')
          .order('parcel_id', ascending: false)
          .limit(1);

      int nextNumber = 1;
      if (parcels.isNotEmpty) {
        final lastId = parcels[0]['parcel_id'] as String;
        final parts = lastId.split('-');
        if (parts.length >= 2) {
          final numberStr = parts[1];
          nextNumber = (int.tryParse(numberStr) ?? 0) + 1;
        }
      }

      setState(() {
        _generatedParcelId = 'PARC-${nextNumber.toString().padLeft(4, '0')}-$currentYear';
      });
    } catch (e) {
      // If table doesn't exist or error, start from 1
      final currentYear = DateTime.now().year;
      setState(() {
        _generatedParcelId = 'PARC-0001-$currentYear';
      });
    }
  }

  Future<void> _addParcel() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fromCounty == null || _toCounty == null || _courierService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.from('parcels').insert({
        'parcel_id': _generatedParcelId,
        'user_id': widget.user['id'],
        'from_county': _fromCounty,
        'to_county': _toCounty,
        'courier_service': _courierService,
        'description': _descriptionController.text.trim(),
        'weight': double.tryParse(_weightController.text) ?? 0.0,
        'value': double.tryParse(_valueController.text) ?? 0.0,
        'recipient_name': _recipientNameController.text.trim(),
        'recipient_phone': _recipientPhoneController.text.trim(),
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parcel added successfully, please track it'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding parcel: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A90E2), Color(0xFF9B59B6)],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add New Parcel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Form Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Parcel ID (Read-only)
                          TextFormField(
                            initialValue: _generatedParcelId ?? 'Generating...',
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Parcel ID',
                              prefixIcon: const Icon(Icons.qr_code),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // From County (Searchable Dropdown)
                          _SearchableDropdown(
                            label: 'From County *',
                            value: _fromCounty,
                            items: _kenyaCounties,
                            onChanged: (value) {
                              setState(() => _fromCounty = value);
                            },
                            icon: Icons.location_on_outlined,
                          ),
                          const SizedBox(height: 16),
                          
                          // To County (Searchable Dropdown)
                          _SearchableDropdown(
                            label: 'To County *',
                            value: _toCounty,
                            items: _kenyaCounties,
                            onChanged: (value) {
                              setState(() => _toCounty = value);
                            },
                            icon: Icons.location_city_outlined,
                          ),
                          const SizedBox(height: 16),
                          
                          // Courier Service
                          _SearchableDropdown(
                            label: 'Courier Service *',
                            value: _courierService,
                            items: _courierServices,
                            onChanged: (value) {
                              setState(() => _courierService = value);
                            },
                            icon: Icons.local_shipping_outlined,
                          ),
                          const SizedBox(height: 16),
                          
                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              prefixIcon: const Icon(Icons.description_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          
                          // Weight
                          TextFormField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Weight (kg)',
                              prefixIcon: const Icon(Icons.scale_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Value
                          TextFormField(
                            controller: _valueController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Value (KES)',
                              prefixIcon: const Icon(Icons.attach_money),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Recipient Name
                          TextFormField(
                            controller: _recipientNameController,
                            decoration: InputDecoration(
                              labelText: 'Recipient Name',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Recipient Phone
                          TextFormField(
                            controller: _recipientPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Recipient Phone',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _addParcel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B59B6),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Add Parcel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _SearchableDropdown extends StatelessWidget {
  const _SearchableDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showSearchDialog(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value ?? 'Select $label',
          style: TextStyle(
            color: value == null ? Colors.grey : Colors.black87,
          ),
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        List<String> filteredItems = items;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select $label'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (query) {
                        setState(() {
                          searchQuery = query;
                          filteredItems = items
                              .where((item) => item
                                  .toLowerCase()
                                  .contains(query.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return ListTile(
                            title: Text(item),
                            onTap: () {
                              onChanged(item);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Track Parcel Dialog
class _TrackParcelDialog extends StatefulWidget {
  const _TrackParcelDialog({required this.user});

  final Map<String, dynamic> user;

  @override
  State<_TrackParcelDialog> createState() => _TrackParcelDialogState();
}

class _TrackParcelDialogState extends State<_TrackParcelDialog> {
  final _parcelIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _parcel;
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _parcelIdController.dispose();
    super.dispose();
  }

  Future<void> _searchParcel() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _parcel = null;
    });

    try {
      final parcelId = _parcelIdController.text.trim();
      final userId = widget.user['id'];

      final result = await _supabase
          .from('parcels')
          .select()
          .eq('parcel_id', parcelId)
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _parcel = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching parcel: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    String timeAgo;
    if (difference.inDays > 0) {
      timeAgo = '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      timeAgo = '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      timeAgo = 'Just now';
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} • $timeAgo';
  }

  Future<List<Map<String, dynamic>>> _getTrackingEvents() async {
    if (_parcel == null) return [];

    final events = <Map<String, dynamic>>[];
    final parcelId = _parcel!['parcel_id']?.toString() ?? '';
    final createdAt = _parcel!['created_at'] != null
        ? DateTime.tryParse(_parcel!['created_at'].toString())
        : null;

    // Event 1: Parcel added successfully
    if (createdAt != null) {
      events.add({
        'title': 'Parcel added successfully',
        'time': createdAt,
        'isCompleted': true,
        'icon': Icons.check_circle,
        'color': Colors.green,
        'notes': null,
      });
    }

    // Fetch tracking history from database
    try {
      final history = await _supabase
          .from('tracking_history')
          .select()
          .eq('parcel_id', parcelId)
          .order('updated_at', ascending: true);

      if (history != null && history.isNotEmpty) {
        for (var entry in history) {
          final status = entry['status']?.toString() ?? 'Unknown';
          final location = entry['location']?.toString();
          final notes = entry['notes']?.toString();
          final updatedAt = entry['updated_at'] != null
              ? DateTime.tryParse(entry['updated_at'].toString())
              : null;

          if (updatedAt != null) {
            String title = status;
            if (location != null && location.isNotEmpty) {
              title = '$status - $location';
            }

            events.add({
              'title': title,
              'time': updatedAt,
              'isCompleted': true,
              'icon': _getStatusIcon(status),
              'color': _getStatusColor(status),
              'notes': notes,
            });
          }
        }
      }
    } catch (e) {
      // If tracking_history table doesn't exist yet, continue with basic events
      print('Error fetching tracking history: $e');
    }

    // Sort by time (oldest first)
    events.sort((a, b) {
      final timeA = a['time'] as DateTime?;
      final timeB = b['time'] as DateTime?;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeA.compareTo(timeB);
    });

    return events;
  }

  IconData _getStatusIcon(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'delivered':
        return Icons.check_circle;
      case 'in transit':
      case 'out for delivery':
        return Icons.local_shipping;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'delivered':
        return Colors.green;
      case 'in transit':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'out for delivery':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF9B59B6)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Track Parcel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Input
                      TextFormField(
                        controller: _parcelIdController,
                        decoration: InputDecoration(
                          labelText: 'Enter Parcel ID',
                          hintText: 'e.g., PARC-0001-2025',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a parcel ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Search Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _searchParcel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7B1FA2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Search',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Timeline
                      if (_hasSearched && !_isLoading) ...[
                        if (_parcel == null)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Parcel not found. Please check the parcel ID and try again.',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          // Parcel Info Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Parcel ID: ${_parcel!['parcel_id']}',
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Route: ${_parcel!['from_county']} → ${_parcel!['to_county']}',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Status: ${_parcel!['status'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Timeline Title
                          const Text(
                            'Tracking Timeline',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Vertical Timeline
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _getTrackingEvents(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'No tracking events available',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );
                              }

                              final events = snapshot.data!;
                              return Column(
                                children: events.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final event = entry.value;
                                  final isLast = index == events.length - 1;
                                  final time = event['time'] as DateTime?;
                                  final notes = event['notes'] as String?;

                                  return _TimelineEvent(
                                    title: event['title'] as String,
                                    time: time,
                                    isCompleted: event['isCompleted'] as bool,
                                    icon: event['icon'] as IconData,
                                    color: event['color'] as Color,
                                    isLast: isLast,
                                    notes: notes,
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Timeline Event Widget (Vertical)
class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({
    required this.title,
    required this.time,
    required this.isCompleted,
    required this.icon,
    required this.color,
    required this.isLast,
    this.notes,
  });

  final String title;
  final DateTime? time;
  final bool isCompleted;
  final IconData icon;
  final Color color;
  final bool isLast;
  final String? notes;

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    String timeAgo;
    if (difference.inDays > 0) {
      timeAgo = '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      timeAgo = '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      timeAgo = 'Just now';
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} • $timeAgo';
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line and Icon
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? color : Colors.grey.shade300,
                  border: Border.all(
                    color: isCompleted ? color : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isCompleted ? Colors.white : Colors.grey.shade600,
                  size: 20,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? color : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Event Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(time),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  // Notes section
                  if (notes != null && notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: 18,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              notes!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontStyle: FontStyle.italic,
                              ),
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
      ),
    );
  }
}

// County coordinates mapping for Kenya (approximate center coordinates)
const Map<String, LatLng> _kenyaCountyCoordinates = {
  'Baringo': LatLng(0.4667, 35.9667),
  'Bomet': LatLng(-0.7833, 35.3333),
  'Bungoma': LatLng(0.5667, 34.5667),
  'Busia': LatLng(0.4667, 34.1167),
  'Elgeyo-Marakwet': LatLng(0.5167, 35.5167),
  'Embu': LatLng(-0.5333, 37.4500),
  'Garissa': LatLng(-0.4500, 39.6500),
  'Homa Bay': LatLng(-0.5167, 34.4500),
  'Isiolo': LatLng(0.3500, 37.5833),
  'Kajiado': LatLng(-1.8500, 36.7833),
  'Kakamega': LatLng(0.2833, 34.7500),
  'Kericho': LatLng(-0.3667, 35.2833),
  'Kiambu': LatLng(-1.1667, 36.8167),
  'Kilifi': LatLng(-3.6333, 39.8500),
  'Kirinyaga': LatLng(-0.5000, 37.3333),
  'Kisii': LatLng(-0.6833, 34.7667),
  'Kisumu': LatLng(-0.0917, 34.7681),
  'Kitui': LatLng(-1.3667, 38.0167),
  'Kwale': LatLng(-4.1833, 39.4500),
  'Laikipia': LatLng(0.0333, 36.3667),
  'Lamu': LatLng(-2.2667, 40.9000),
  'Machakos': LatLng(-1.5167, 37.2667),
  'Makueni': LatLng(-1.8000, 37.6167),
  'Mandera': LatLng(3.9333, 41.8500),
  'Marsabit': LatLng(2.3333, 37.9833),
  'Meru': LatLng(0.0500, 37.6500),
  'Migori': LatLng(-1.0667, 34.4667),
  'Mombasa': LatLng(-4.0435, 39.6682),
  'Murang\'a': LatLng(-0.7167, 37.1500),
  'Nairobi': LatLng(-1.2921, 36.8219),
  'Nakuru': LatLng(-0.3031, 36.0800),
  'Nandi': LatLng(0.1833, 35.1167),
  'Narok': LatLng(-1.0833, 35.8667),
  'Nyamira': LatLng(-0.5667, 34.9500),
  'Nyandarua': LatLng(-0.5167, 36.4167),
  'Nyeri': LatLng(-0.4167, 36.9500),
  'Samburu': LatLng(1.1000, 36.9833),
  'Siaya': LatLng(0.0667, 34.2833),
  'Taita-Taveta': LatLng(-3.4000, 38.3667),
  'Tana River': LatLng(-1.5167, 40.0167),
  'Tharaka-Nithi': LatLng(-0.3000, 37.6500),
  'Trans Nzoia': LatLng(1.0167, 35.0167),
  'Turkana': LatLng(3.1167, 35.6000),
  'Uasin Gishu': LatLng(0.5167, 35.2833),
  'Vihiga': LatLng(0.0833, 34.7167),
  'Wajir': LatLng(1.7500, 40.0500),
  'West Pokot': LatLng(1.7833, 35.1167),
};

class _LiveMapDialog extends StatefulWidget {
  const _LiveMapDialog({required this.user});

  final Map<String, dynamic> user;

  @override
  State<_LiveMapDialog> createState() => _LiveMapDialogState();
}

class _LiveMapDialogState extends State<_LiveMapDialog> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _parcels = [];
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _parcelsByCounty = {};
  Map<String, List<LatLng>> _parcelRoutes = {}; // parcel_id -> route coordinates
  Map<String, Color> _parcelColors = {}; // parcel_id -> unique color

  // Center of Kenya
  static const LatLng _kenyaCenter = LatLng(-0.0236, 37.9062);
  static const double _initialZoom = 6.5;

  // Color palette for parcel routes
  static const List<Color> _routeColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
    Colors.deepOrange,
    Colors.lime,
    Colors.brown,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _loadParcels();
  }

  Future<void> _loadParcels() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.user['id'];
      
      // Fetch all parcels for this user (excluding delivered)
      final parcels = await _supabase
          .from('parcels')
          .select()
          .eq('user_id', userId)
          .neq('status', 'Delivered')
          .order('created_at', ascending: false);

      final parcelsList = (parcels as List).cast<Map<String, dynamic>>();
      
      // Build routes for each parcel
      final Map<String, List<LatLng>> routes = {};
      final Map<String, Color> colors = {};
      
      for (int i = 0; i < parcelsList.length; i++) {
        final parcel = parcelsList[i];
        final parcelId = parcel['parcel_id']?.toString() ?? '';
        
        // Assign unique color to each parcel
        colors[parcelId] = _routeColors[i % _routeColors.length];
        
        // Build route from tracking history
        final route = await _buildParcelRoute(parcelId, parcel);
        if (route.length >= 2) {
          routes[parcelId] = route;
        }
      }

      // Group parcels by from_county
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var parcel in parcels as List) {
        final county = parcel['from_county'] as String? ?? 'Unknown';
        if (!grouped.containsKey(county)) {
          grouped[county] = [];
        }
        grouped[county]!.add(parcel.cast<String, dynamic>());
      }

      if (mounted) {
        setState(() {
          _parcels = parcels.cast<Map<String, dynamic>>();
          _parcelsByCounty = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading parcels: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<LatLng>> _buildParcelRoute(String parcelId, Map<String, dynamic> parcel) async {
    final List<LatLng> route = [];
    
    // Start with from_county (initial location)
    final fromCounty = parcel['from_county']?.toString();
    if (fromCounty != null && _kenyaCountyCoordinates.containsKey(fromCounty)) {
      route.add(_kenyaCountyCoordinates[fromCounty]!);
    }
    
    // Fetch tracking history for this parcel
    try {
      final history = await _supabase
          .from('tracking_history')
          .select()
          .eq('parcel_id', parcelId)
          .order('updated_at', ascending: true);
      
      if (history != null && history.isNotEmpty) {
        for (var entry in history) {
          final location = entry['location']?.toString();
          if (location != null && 
              location.isNotEmpty && 
              _kenyaCountyCoordinates.containsKey(location)) {
            final coordinates = _kenyaCountyCoordinates[location]!;
            // Only add if different from last point
            if (route.isEmpty || route.last != coordinates) {
              route.add(coordinates);
            }
          }
        }
      }
      
      // Also check current_location if available
      final currentLocation = parcel['current_location']?.toString();
      if (currentLocation != null && 
          currentLocation.isNotEmpty && 
          _kenyaCountyCoordinates.containsKey(currentLocation)) {
        final coordinates = _kenyaCountyCoordinates[currentLocation]!;
        // Only add if different from last point
        if (route.isEmpty || route.last != coordinates) {
          route.add(coordinates);
        }
      }
    } catch (e) {
      print('Error fetching tracking history for $parcelId: $e');
    }
    
    return route;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade900, Colors.indigo.shade900],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Parcel Map',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Parcel routes and locations',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Map
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _parcels.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No parcels to display',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _kenyaCenter,
                            initialZoom: _initialZoom,
                            minZoom: 5.0,
                            maxZoom: 18.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.parcel_tracking_app',
                            ),
                            // Polyline layer for routes
                            PolylineLayer(
                              polylines: _buildPolylines(),
                            ),
                            MarkerLayer(
                              markers: _buildMarkers(),
                            ),
                          ],
                        ),
            ),
            // Legend/Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.deepPurple.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing ${_parcels.length} active parcel${_parcels.length != 1 ? 's' : ''} with routes',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_parcelRoutes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Parcel Routes:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _parcels.length,
                        itemBuilder: (context, index) {
                          final parcel = _parcels[index];
                          final parcelId = parcel['parcel_id']?.toString() ?? 'N/A';
                          final color = _parcelColors[parcelId] ?? Colors.blue;
                          final hasRoute = _parcelRoutes.containsKey(parcelId) && 
                                         _parcelRoutes[parcelId]!.length >= 2;
                          
                          if (!hasRoute) return const SizedBox.shrink();
                          
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  parcelId.length > 12 
                                      ? '${parcelId.substring(0, 12)}...'
                                      : parcelId,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (_parcelsByCounty.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _parcelsByCounty.length,
                        itemBuilder: (context, index) {
                          final entry = _parcelsByCounty.entries.elementAt(index);
                          final county = entry.key;
                          final count = entry.value.length;
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.deepPurple.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  county,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.deepPurple.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade700,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Polyline> _buildPolylines() {
    final List<Polyline> polylines = [];
    
    print('Building polylines: ${_parcelRoutes.length} routes available');
    
    _parcelRoutes.forEach((parcelId, route) {
      print('Processing route for $parcelId: ${route.length} points');
      if (route.length >= 2) {
        final color = _parcelColors[parcelId] ?? Colors.blue;
        print('Adding polyline for $parcelId with color: $color');
        polylines.add(
          Polyline(
            points: route,
            strokeWidth: 4.0,
            color: color,
            borderStrokeWidth: 2.0,
            borderColor: Colors.white,
          ),
        );
      } else {
        print('Skipping $parcelId: Only ${route.length} point(s), need at least 2');
      }
    });
    
    print('Total polylines created: ${polylines.length}');
    return polylines;
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];
    final Map<LatLng, List<Map<String, dynamic>>> locationsMap = {};

    // Group parcels by their current location
    for (var parcel in _parcels) {
      final parcelId = parcel['parcel_id']?.toString() ?? '';
      final route = _parcelRoutes[parcelId];
      
      if (route != null && route.isNotEmpty) {
        // Use the last location in the route (current location)
        final currentLocation = route.last;
        if (!locationsMap.containsKey(currentLocation)) {
          locationsMap[currentLocation] = [];
        }
        locationsMap[currentLocation]!.add(parcel);
      } else {
        // Fallback to from_county if no route
        final fromCounty = parcel['from_county']?.toString();
        if (fromCounty != null && _kenyaCountyCoordinates.containsKey(fromCounty)) {
          final coordinates = _kenyaCountyCoordinates[fromCounty]!;
          if (!locationsMap.containsKey(coordinates)) {
            locationsMap[coordinates] = [];
          }
          locationsMap[coordinates]!.add(parcel);
        }
      }
    }

    // Create markers for each location
    locationsMap.forEach((location, parcels) {
      final parcel = parcels.first;
      final parcelId = parcel['parcel_id']?.toString() ?? '';
      final color = _parcelColors[parcelId] ?? Colors.deepPurple.shade700;
      
      markers.add(
        Marker(
          point: location,
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _showLocationParcelsInfo(location, parcels),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  parcels.length > 1 ? '${parcels.length}' : '1',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });

    return markers;
  }

  void _showLocationParcelsInfo(
      LatLng location, List<Map<String, dynamic>> parcels) {
    // Find county name from coordinates
    String? countyName;
    _kenyaCountyCoordinates.forEach((county, coords) {
      if (coords == location) {
        countyName = county;
      }
    });
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  countyName ?? 'Current Location',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${parcels.length} parcel${parcels.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: parcels.length,
                itemBuilder: (context, index) {
                  final parcel = parcels[index];
                  final parcelId = parcel['parcel_id'] as String? ?? 'N/A';
                  final toCounty = parcel['to_county'] as String? ?? 'N/A';
                  final status = parcel['status'] as String? ?? 'Unknown';
                  final parcelColor = _parcelColors[parcelId] ?? Colors.blue;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: parcelColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: parcelColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                parcelId,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'To: $toCounty',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'delivered':
        return Colors.green;
      case 'in transit':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'out for delivery':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showCountyParcelsInfo(
      String county, List<Map<String, dynamic>> parcels) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$county County',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${parcels.length} parcel${parcels.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: parcels.length,
                itemBuilder: (context, index) {
                  final parcel = parcels[index];
                  final parcelId = parcel['parcel_id'] as String? ?? 'N/A';
                  final toCounty = parcel['to_county'] as String? ?? 'N/A';
                  final status = parcel['status'] as String? ?? 'Unknown';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.local_shipping,
                            color: Colors.deepPurple.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parcelId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'To: $toCounty',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}

// Admin Tab Widget
class _AdminTab extends StatefulWidget {
  const _AdminTab();

  @override
  State<_AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends State<_AdminTab> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allParcels = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllParcels();
  }

  Future<void> _loadAllParcels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('parcels')
          .select('*, users(full_name, email)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allParcels = (response as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading parcels: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredParcels {
    if (_searchQuery.isEmpty) {
      return _allParcels;
    }

    final query = _searchQuery.toLowerCase();
    return _allParcels.where((parcel) {
      final parcelId = (parcel['parcel_id'] ?? '').toString().toLowerCase();
      final fromCounty = (parcel['from_county'] ?? '').toString().toLowerCase();
      final toCounty = (parcel['to_county'] ?? '').toString().toLowerCase();
      final status = (parcel['status'] ?? '').toString().toLowerCase();
      final ownerName = (parcel['users']?['full_name'] ?? '').toString().toLowerCase();
      final ownerEmail = (parcel['users']?['email'] ?? '').toString().toLowerCase();

      return parcelId.contains(query) ||
          fromCounty.contains(query) ||
          toCounty.contains(query) ||
          status.contains(query) ||
          ownerName.contains(query) ||
          ownerEmail.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.deepPurple.shade900,
            Colors.indigo.shade900,
          ],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadAllParcels,
        child: CustomScrollView(
          slivers: [
            // Header with Search
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Panel',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage all parcels • ${_allParcels.length} total',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by parcel ID, owner, county, status...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            // Parcels List
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else if (_filteredParcels.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty
                            ? Icons.inbox_outlined
                            : Icons.search_off,
                        size: 64,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No parcels found'
                            : 'No parcels match your search',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final parcel = _filteredParcels[index];
                      final parcelId = parcel['parcel_id']?.toString() ?? 'N/A';
                      final fromCounty = parcel['from_county']?.toString() ?? 'N/A';
                      final toCounty = parcel['to_county']?.toString() ?? 'N/A';
                      final status = parcel['status']?.toString() ?? 'Unknown';
                      final ownerName = parcel['users']?['full_name']?.toString() ?? 'Unknown';
                      final ownerEmail = parcel['users']?['email']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white.withOpacity(0.1),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            parcelId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                '$fromCounty → $toCounty',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Owner: $ownerName',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () {
                              _showUpdateParcelDialog(context, parcel);
                            },
                          ),
                        ),
                      );
                    },
                    childCount: _filteredParcels.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showUpdateParcelDialog(BuildContext context, Map<String, dynamic> parcel) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _UpdateParcelDialog(
        parcel: parcel,
        onUpdate: () {
          _loadAllParcels();
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'delivered':
        return Colors.green;
      case 'in transit':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'out for delivery':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Update Parcel Dialog Widget
class _UpdateParcelDialog extends StatefulWidget {
  const _UpdateParcelDialog({
    required this.parcel,
    required this.onUpdate,
  });

  final Map<String, dynamic> parcel;
  final VoidCallback onUpdate;

  @override
  State<_UpdateParcelDialog> createState() => _UpdateParcelDialogState();
}

class _UpdateParcelDialogState extends State<_UpdateParcelDialog> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedStatus;
  String? _selectedLocation;
  final TextEditingController _notesController = TextEditingController();
  bool _isUpdating = false;

  static const List<String> _statusOptions = [
    'Pending',
    'In Transit',
    'Out for Delivery',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.parcel['status']?.toString() ?? 'Pending';
    _selectedLocation = widget.parcel['current_location']?.toString() ??
        widget.parcel['from_county']?.toString();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateParcel() async {
    if (_selectedStatus == null || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both status and location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final updateData = <String, dynamic>{
        'status': _selectedStatus,
        'current_location': _selectedLocation,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update parcel
      await _supabase
          .from('parcels')
          .update(updateData)
          .eq('parcel_id', widget.parcel['parcel_id']);

      // Save to tracking_history
      final notes = _notesController.text.trim();
      if (_selectedStatus != widget.parcel['status']?.toString() || 
          _selectedLocation != widget.parcel['current_location']?.toString() ||
          notes.isNotEmpty) {
        await _supabase.from('tracking_history').insert({
          'parcel_id': widget.parcel['parcel_id'],
          'status': _selectedStatus,
          'location': _selectedLocation,
          'notes': notes.isNotEmpty ? notes : null,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdate();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parcel ${widget.parcel['parcel_id']} updated successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating parcel: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcelId = widget.parcel['parcel_id']?.toString() ?? 'N/A';
    final fromCounty = widget.parcel['from_county']?.toString() ?? 'N/A';
    final toCounty = widget.parcel['to_county']?.toString() ?? 'N/A';
    final ownerName = widget.parcel['users']?['full_name']?.toString() ?? 'Unknown';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade800,
              Colors.indigo.shade900,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Update Parcel',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(label: 'Parcel ID', value: parcelId),
                          const SizedBox(height: 8),
                          _InfoRow(label: 'Owner', value: ownerName),
                          const SizedBox(height: 8),
                          _InfoRow(label: 'Route', value: '$fromCounty → $toCounty'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Status *',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                        dropdownColor: Colors.deepPurple.shade800,
                        style: const TextStyle(color: Colors.white),
                        items: _statusOptions.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Row(
                              children: [
                                Icon(
                                  _getStatusIcon(status),
                                  color: _getStatusColor(status),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(status),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _isUpdating
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedStatus = value;
                                });
                              },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Current Location *',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedLocation,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: const Icon(
                            Icons.location_on,
                            color: Colors.white70,
                          ),
                        ),
                        dropdownColor: Colors.deepPurple.shade800,
                        style: const TextStyle(color: Colors.white),
                        items: _kenyaCounties.map((county) {
                          return DropdownMenuItem(
                            value: county,
                            child: Text(county),
                          );
                        }).toList(),
                        onChanged: _isUpdating
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedLocation = value;
                                });
                              },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Notes (Optional)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      enabled: !_isUpdating,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add any additional notes...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isUpdating
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isUpdating ? null : _updateParcel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Update Parcel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'delivered':
        return Colors.green;
      case 'in transit':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'out for delivery':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'delivered':
        return Icons.check_circle;
      case 'in transit':
      case 'out for delivery':
        return Icons.local_shipping;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help_outline;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}


