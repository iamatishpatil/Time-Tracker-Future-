import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/theme/pulse_colors.dart';
import 'package:frontend/core/theme/pulse_text_styles.dart';
import 'package:frontend/core/widgets/pulse_card.dart';
import 'package:frontend/core/widgets/pulse_shimmer.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/services/pdf_service.dart';

class UserPayslipsScreen extends StatefulWidget {
  const UserPayslipsScreen({super.key});

  @override
  State<UserPayslipsScreen> createState() => _UserPayslipsScreenState();
}

class _UserPayslipsScreenState extends State<UserPayslipsScreen> {
  List<dynamic> _payslips = [];
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _settings;
  bool _isLoading = true;
  bool _isPayrollEnabled = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Performance Fix: Fetch user and settings IN PARALLEL
      final initialResults = await Future.wait([
        ApiService.getStoredUser(),
        ApiService.getSettings(),
      ]);
      final user = initialResults[0] as Map<String, dynamic>?;
      final settings = initialResults[1] as Map<String, dynamic>;
      if (user != null) {
        final data = await ApiService.getUserPayslips(user['id']);
        if (mounted) {
          setState(() {
            _user = user;
            _settings = settings;
            _payslips = data;
            _isPayrollEnabled = (settings['payrollEnabled'] ?? 1) != 0;
          });
        }
      }
    } catch (e) {
        if (mounted) {
          setState(() {
            _isPayrollEnabled = false; // Assume disabled on error or if settings can't be fetched
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPayslip(dynamic payslip) async {
    if (_user == null) return;
    setState(() => _isDownloading = true);
    try {
      await PdfService.generateIndividualPayslip(payslip, _user!, _settings ?? {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPayrollEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Payslips')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.money_off, size: 64, color: PulseColors.textHint),
              const SizedBox(height: 16),
              Text('Payslips Not Available', style: PulseTextStyles.h3),
              const SizedBox(height: 8),
              Text('Your administrator has disabled this feature.', style: PulseTextStyles.caption),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My Payslips')),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PulseShimmer.list(count: 5, itemHeight: 90),
            )
          : _payslips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: PulseColors.border),
                      const SizedBox(height: 16),
                      Text('No payslips available', style: PulseTextStyles.h3),
                      Text('You will see your payslips here when generated.', style: PulseTextStyles.caption),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _payslips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _payslips[index];
                    final date = DateTime(item['year'], item['month']);
                    final netSalaryStr = '₹${item['netSalary'].toString()}';
                    
                    return PulseCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PulseColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.receipt, color: PulseColors.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${DateFormat('MMMM yyyy').format(date)}', style: PulseTextStyles.bodyBold),
                                const SizedBox(height: 4),
                                Text(netSalaryStr, style: PulseTextStyles.h3.copyWith(color: PulseColors.success)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _isDownloading ? null : () => _downloadPayslip(item),
                            icon: _isDownloading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.download, color: PulseColors.accent),
                            tooltip: 'Download PDF',
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1);
                  },
                ),
    );
  }
}
