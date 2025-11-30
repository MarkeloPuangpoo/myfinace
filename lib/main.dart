import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/background_service.dart';
import 'screens/statistics_screen.dart';
import 'core/app_theme.dart';
import 'data/database.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Background Service
  await initializeService();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shadow Accountant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _permissionGranted = false;
  final AppDatabase _database = AppDatabase();
  double _totalBalance = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadBalance();
  }

  Future<void> _checkPermission() async {
    bool? isGranted = await NotificationsListener.hasPermission;
    setState(() {
      _permissionGranted = isGranted ?? false;
    });
  }

  Future<void> _requestPermission() async {
    await NotificationsListener.openPermissionSettings();
  }

  Future<void> _loadBalance() async {
    final income = await _database.getTotalIncome();
    final expense = await _database.getTotalExpense();
    if (mounted) {
      setState(() {
        _totalBalance = income - expense;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good Evening,',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'My Finance',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(Icons.notifications_none, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Balance Section
              Center(
                child: Column(
                  children: [
                    Text(
                      'Total Balance',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        letterSpacing: 1.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            NumberFormat.currency(
                              symbol: '฿',
                            ).format(_totalBalance),
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Status Indicators (Minimal)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatusChip(
                    label: 'Service',
                    isActive: true, // Always running if app is open
                    activeColor: AppTheme.success,
                  ),
                  const SizedBox(width: 16),
                  _buildStatusChip(
                    label: 'Permission',
                    isActive: _permissionGranted,
                    activeColor: AppTheme.success,
                    onTap: _permissionGranted ? null : _requestPermission,
                  ),
                ],
              ),
              const SizedBox(height: 50),

              // Menu Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildMenuCard(
                      context,
                      title: 'Statistics',
                      subtitle: 'View Report',
                      icon: Icons.bar_chart,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StatisticsScreen(),
                          ),
                        ).then((_) => _loadBalance());
                      },
                    ),
                    _buildMenuCard(
                      context,
                      title: 'Settings',
                      subtitle: 'Preferences',
                      icon: Icons.settings_outlined,
                      onTap: () {
                        // TODO: Implement settings
                      },
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

  Widget _buildStatusChip({
    required String label,
    required bool isActive,
    required Color activeColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // แก้ไข: ใช้ .withValues(alpha: ...) แทน .withOpacity(...)
          color: isActive
              ? activeColor.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            // แก้ไข: ใช้ .withValues(alpha: ...)
            color: isActive
                ? activeColor.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? activeColor : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              // แก้ไข: ใช้ .withValues(alpha: ...)
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // แก้ไข: ใช้ .withValues(alpha: ...)
                color: AppTheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
