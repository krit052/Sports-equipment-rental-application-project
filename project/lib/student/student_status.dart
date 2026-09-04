import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/login/login.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_application_1/config/config.dart';

class StudentStatus extends StatefulWidget {
  const StudentStatus({super.key});

  @override
  State<StudentStatus> createState() => _StudentStatusState();
}

class _StudentStatusState extends State<StudentStatus> {
  final String baseUrl = "http://$defaultIp:$defaultPort/api";
  int? currentUserId;

  bool _isLoading = true;
  String _username = 'guest';
  StatusItem? _currentItem;

  @override
  void initState() {
    super.initState();
    _loadUserAndFetchData();
  }

  Future<void> _loadUserAndFetchData() async {
    final storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login again.")));
      setState(() => _isLoading = false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (route) => false,
      );
      return;
    }

    final jwt = JWT.decode(token);
    Map playload = jwt.payload;
    final userId = playload['user_id'] as int;

    setState(() => currentUserId = userId);
    await _fetchData();
  }

  Future<void> _fetchData() async {
    if (currentUserId == null) return;

    setState(() {
      _isLoading = true;
      _currentItem = null;
    });

    try {
      final userRes = await http
          .get(Uri.parse('$baseUrl/user/$currentUserId'))
          .timeout(const Duration(seconds: 8));
      String fetchedUsername = 'guest';
      if (userRes.statusCode == 200) {
        final userData = json.decode(userRes.body);
        fetchedUsername = userData['username'] ?? 'guest';
      }

      final statusRes = await http
          .get(Uri.parse('$baseUrl/student/status/$currentUserId'))
          .timeout(const Duration(seconds: 8));

      StatusItem? fetchedStatus;
      if (statusRes.statusCode == 200) {
        final statusData = json.decode(statusRes.body);
        if (statusData != null) {
          fetchedStatus = StatusItem.fromJson(statusData);
        }
      }

      if (mounted) {
        setState(() {
          _username = fetchedUsername;
          _currentItem = fetchedStatus;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error while loading status")),
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
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_circle_outlined,
              color: Colors.blue.shade700,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              _username,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.black),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    return RefreshIndicator(
      // ⭐️ เพิ่ม RefreshIndicator
      onRefresh: _loadUserAndFetchData, // ให้เรียกโหลดข้อมูลใหม่เมื่อมีการดึง
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24.0),
                _buildStatusSection(item: _currentItem),
                const SizedBox(height: 24.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection({StatusItem? item}) {
    Widget cardContent;
    if (item != null) {
      cardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.date,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  item.itemName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              Text(
                item.status,
                style: TextStyle(
                  color: _statusColor(item.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      cardContent = const Center(
        child: Text('No status', style: TextStyle(color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12.0),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: cardContent,
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    if (s == 'Pending') return Colors.orange;
    if (s == 'Requested Return') return Colors.purple;
    if (s == 'Borrowed') return Colors.teal;
    if (s == 'Rejected') return Colors.red;
    return Colors.black;
  }
}

class StatusItem {
  final String requestId;
  final String date;
  final String itemName;
  final String status;

  StatusItem({
    required this.requestId,
    required this.date,
    required this.itemName,
    required this.status,
  });

  factory StatusItem.fromJson(Map<String, dynamic> json) {
    String formatDate(String? dateStr) {
      if (dateStr == null) return 'N/A';
      try {
        final DateTime utcDateTime = DateTime.parse(dateStr);
        // แปลงจากเวลา UTC ให้เป็น "เวลาของเครื่อง" (Local Time)
        final DateTime localDateTime = utcDateTime.toLocal();
        return localDateTime.toString().split(' ')[0];
      } catch (e) {
        return dateStr.split('T')[0];
      }
    }

    return StatusItem(
      requestId: json['request_id'].toString(),
      date: formatDate(json['request_date']),
      itemName: json['asset_name'] ?? 'Unknown Item',
      status: json['asset_status'] ?? 'Unknown',
    );
  }
}
