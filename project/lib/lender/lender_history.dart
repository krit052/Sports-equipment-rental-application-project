import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/login/login.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_application_1/config/config.dart';

class Lenderhistory extends StatefulWidget {
  const Lenderhistory({super.key});

  @override
  State<Lenderhistory> createState() => _LenderhistoryState();
}

class _LenderhistoryState extends State<Lenderhistory> {
  final String baseUrl = "http://$defaultIp:$defaultPort/api";
  int? userId;

  bool _isLoading = true;
  List<HistoryItem> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _loadUserAndFetch();
  }

  Future<void> _loadUserAndFetch() async {
    // ========== ดึง user_id จาก token ==========
    final storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'token');

    final jwt = JWT.decode(token!);
    Map payload = jwt.payload;

    userId = payload['user_id'] as int;

    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login again.")));
      setState(() => _isLoading = false);
      return;
    }
    await _fetchData();
  }

  Future<void> _fetchData() async {
    if (userId == null) return;
    setState(() {
      _isLoading = true;
      _historyItems = [];
    });

    try {
      final storage = FlutterSecureStorage();
      String? token = await storage.read(key: 'token');
      final response = await http
          .get(
            Uri.parse('$baseUrl/lender/history/$userId'),
            headers: token != null ? {'Authorization': 'Bearer $token'} : {},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _historyItems = data
              .map((jsonItem) => HistoryItem.fromJson(jsonItem))
              .toList();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load history: ${response.statusCode}'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error while loading history")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = AppBar().preferredSize.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = 16.0;
    final minCardHeight =
        screenHeight - appBarHeight - topPadding - bottomPadding;

    return Scaffold(
      backgroundColor: Colors.blue.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade100,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.black),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minCardHeight),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24.0),
                          _buildHistorySection(items: _historyItems),
                          const SizedBox(height: 24.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHistorySection({required List<HistoryItem> items}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'History',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12.0),
          if (items.isEmpty)
            const Center(
              child: Text(
                'No history found.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildHistoryCard(item: items[index]);
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 12.0),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard({required HistoryItem item}) {
    Color getStatusColor(String status) {
      if (status == 'Approved') return Colors.green;
      if (status == 'Rejected') return Colors.red;
      return Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request ID #${item.requestId}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.item,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.dateRange,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  item.status,
                  style: TextStyle(
                    color: getStatusColor(item.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lender',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                item.lender,
                style: const TextStyle(color: Colors.black, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Returned',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                item.returnedBy,
                style: const TextStyle(color: Colors.black, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HistoryItem {
  final String item;
  final String dateRange;
  final String lender;
  final String returnedBy;
  final String status;
  final String requestId;

  HistoryItem({
    required this.item,
    required this.dateRange,
    required this.lender,
    required this.returnedBy,
    required this.status,
    required this.requestId,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    String formatDate(String? dateStr) {
      if (dateStr == null) return 'N/A';
      try {
        final DateTime utcDateTime = DateTime.parse(dateStr);
        final DateTime localDateTime = utcDateTime.toLocal();
        return localDateTime.toString().split(' ')[0];
      } catch (e) {
        return dateStr.split('T')[0];
      }
    }

    final String dateRange =
        "${formatDate(json['borrow_date'])} To ${formatDate(json['return_date'])}";

    final String requestStatus = json['request_status'] ?? 'Unknown';
    final String requestId = (json['request_id'] ?? '').toString();

    return HistoryItem(
      item: json['asset_name'] ?? 'Unknown Item',
      dateRange: dateRange,
      lender: json['lender_name'] ?? '-',
      returnedBy: json['staff_name'] ?? '-',
      status: requestStatus,
      requestId: requestId.isEmpty ? '-' : requestId,
    );
  }
}
