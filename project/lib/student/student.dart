import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'student_history.dart';
import 'student_status.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/login/login.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_application_1/config/config.dart';

class Student extends StatefulWidget {
  const Student({super.key});

  @override
  State<Student> createState() => _StudentState();
}

class _StudentState extends State<Student> with RouteAware {
  final String baseApi = "http://$defaultIp:$defaultPort/api";
  int? borrowerId;
  List<Map<String, dynamic>> equipmentList = [];
  List<Map<String, dynamic>> _filteredList = [];
  Map<String, dynamic>? _activeStatusItem;
  bool _loading = true;
  int canBorrowToday = 1;
  int _notificationCount = 0; // จำนวนการแจ้งเตือน
  Timer? _notificationTimer;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    fetchAssets();
    fetchNotificationCount();
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchNotificationCount();
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
        _filterEquipment();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
    _timer?.cancel();
    _notificationTimer?.cancel();
  }

  void _filterEquipment() {
    if (_searchQuery.isEmpty) {
      _filteredList = equipmentList;
    } else {
      _filteredList = equipmentList
          .where(
            (item) => (item['asset_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_searchQuery),
          )
          .toList();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    fetchAssets();
    fetchNotificationCount(); // รีเฟรช badge หลังกลับจาก status/history
  }

  Future<void> fetchAssets() async {
    setState(() {
      _loading = true;
      _activeStatusItem = null;
    });

    final storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login again.")));
      setState(() => _loading = false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (route) => false,
      );
      return;
    }

    final jwt = JWT.decode(token);
    Map payload = jwt.payload;
    borrowerId = payload['user_id'] as int;

    try {
      // API 1: Status
      final statusUrl = Uri.parse('$baseApi/student/status/$borrowerId');
      final statusResponse = await http
          .get(statusUrl)
          .timeout(const Duration(seconds: 10));

      if (statusResponse.statusCode == 200) {
        //final statusData = jsonDecode(statusResponse.body);
        final dynamic decodedBody = jsonDecode(statusResponse.body);
        final Map<String, dynamic>? statusData = decodedBody is Map
            ? decodedBody as Map<String, dynamic>
            : null;
        setState(() {
          if (statusData != null) {
            canBorrowToday = statusData['can_borrow_today'] ?? 0;
            _activeStatusItem = null;

            final assetStatus = statusData['asset_status'] ?? '';
            final returnStatus = statusData['return_status'] ?? '';

            // กรณี Pending/Borrowed ที่ยังไม่ Return
            if ((assetStatus == 'Pending' || assetStatus == 'Borrowed') &&
                returnStatus != 'Returned' &&
                returnStatus != 'Requested Return') {
              _activeStatusItem = statusData;
            }
          } else {
            // กำหนดค่าเริ่มต้นเมื่อไม่มี Request History เลย
            canBorrowToday = 1;
            _activeStatusItem = null;
          }
        });
      }

      // API 2: Assets
      final assetUrl = Uri.parse(
        '$baseApi/student/asset?borrower_id=$borrowerId',
      );
      final assetResponse = await http
          .get(assetUrl)
          .timeout(const Duration(seconds: 10));

      if (assetResponse.statusCode == 200) {
        final data = jsonDecode(assetResponse.body);
        if (data['success'] == true) {
          setState(() {
            equipmentList = List<Map<String, dynamic>>.from(data['assets']);
            _filteredList = equipmentList;
          });
        } else {
          setState(() {
            equipmentList = [];
            _filteredList = [];
          });
        }
      } else {
        setState(() {
          equipmentList = [];
          _filteredList = [];
        });
      }
    } catch (e) {
      debugPrint("fetchAssets error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error while loading assets')),
        );
      }
    } finally {
      setState(() => _loading = false);
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

  Future<bool> _hasActiveRequest() async {
    if (_activeStatusItem == null) return false;
    final status = _activeStatusItem!['asset_status']?.toString();
    return status == 'Pending' || status == 'Borrowed';
  }

  Future<void> confirmBorrow(int assetId, String assetName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Borrow"),
        content: Text("Borrow $assetName for 7 days?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final blocked = await _hasActiveRequest();
      if (blocked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You have an active request. Cannot borrow until completed.',
            ),
          ),
        );
        return;
      }
      borrowEquipment(assetId, assetName);
    }
  }

  Future<void> borrowEquipment(int assetId, String assetName) async {
    if (borrowerId == null) return;

    final body = {
      "borrower_id": borrowerId.toString(),
      "asset_id": assetId.toString(),
      "borrow_date": DateTime.now().toString().substring(0, 10),
      "return_date": DateTime.now()
          .add(const Duration(days: 7))
          .toString()
          .substring(0, 10),
    };

    try {
      final res = await http
          .post(
            Uri.parse("$baseApi/student/borrow"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Borrow request sent")));
        await fetchAssets();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Borrow failed: ${res.statusCode}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Network error")));
      }
    }
  }

  Future<void> requestReturn(int requestId, String assetName) async {
    try {
      final res = await http
          .put(Uri.parse("$baseApi/student/returnAsset/$requestId"))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200) {
        // ✅ แจ้งเตือน staff ทันทีหลัง student return
        await http.post(Uri.parse("$baseApi/notifyReturn"));
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Return successful")));
        await fetchAssets();

        // ดึงจำนวนแจ้งเตือนล่าสุดของ student (ถ้ามี)
        await fetchNotificationCount();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Return failed: ${res.statusCode}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Network error")));
      }
    }
  }

  // ✅ ฟังก์ชัน 1: ดึงจำนวนแจ้งเตือน
  Future<void> fetchNotificationCount() async {
    final storage = const FlutterSecureStorage();
    String? token = await storage.read(key: 'token');
    if (borrowerId == null || token == null) return;

    final response = await http.get(
      Uri.parse('$baseApi/student/notificationCount/$borrowerId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _notificationCount = int.tryParse(data['count'].toString()) ?? 0;
        });
      }
    }
  }

  // ✅ ฟังก์ชัน 2: ล้างการแจ้งเตือน (เรียกเมื่อกดปุ่มกระดิ่ง)
  Future<void> clearNotifications() async {
    if (_notificationCount == 0) return;
    final storage = const FlutterSecureStorage();
    String? token = await storage.read(key: 'token');
    if (borrowerId == null || token == null) return;

    await http.delete(
      Uri.parse('$baseApi/student/clearNotifications/$borrowerId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    setState(() => _notificationCount = 0);
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Available':
        return Colors.green;
      case 'Borrowed':
        return Colors.teal;
      case 'Pending':
        return Colors.orange;
      case 'Disabled':
        return Colors.red;
      case 'Requested Return':
        return Colors.purple;
      default:
        return Colors.black;
    }
  }

  final String imageBaseUrl = "http://$defaultIp:$defaultPort";
  String buildImageUrl(String? imageField) {
    if (imageField == null || imageField.isEmpty) {
      return "$imageBaseUrl/public/image/default.jpg";
    } else {
      return "$imageBaseUrl$imageField";
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canReturn = false;
    int returnRequestId = 0;
    String returnAssetName = '';
    if (_activeStatusItem != null) {
      final assetStatus = _activeStatusItem!['asset_status']?.toString() ?? '';
      final returnStatus =
          _activeStatusItem!['return_status']?.toString() ?? '';

      if (assetStatus == 'Borrowed' &&
          returnStatus != 'Returned' &&
          returnStatus != 'Requested Return') {
        canReturn = true;
        returnRequestId = int.parse(
          _activeStatusItem!['request_id'].toString(),
        );
        returnAssetName = _activeStatusItem!['asset_name'] ?? 'Item';
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Sport Equipment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchAssets,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Can Borrow Today
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            if (canBorrowToday > 0)
                              const Icon(Icons.book, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              "Can borrow today: $canBorrowToday",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Search Bar
                      Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(30),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "search",
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.blue,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              // ล้าง badge เฉพาะเมื่อกดปุ่ม Status
                              await clearNotifications(); // ฟังก์ชัน DELETE
                              if (!mounted) return;
                              await navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => const StudentStatus(),
                                ),
                              );

                              // รีเฟรช asset + badge หลังกลับจาก status
                              await fetchAssets();
                              await fetchNotificationCount();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade200,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Text(
                                  'Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                                // Badge
                                if (_notificationCount > 0)
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Text(
                                        '$_notificationCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StudentHistory(),
                              ),
                            ).then((_) => fetchAssets()),
                            icon: const Icon(
                              Icons.history_rounded,
                              color: Colors.black,
                            ),
                            label: const Text('History'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade200,
                              foregroundColor: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: ElevatedButton.icon(
                              onPressed: canReturn
                                  ? () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text("Confirm Return"),
                                          content: Text(
                                            "Are you sure you want to return $returnAssetName?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text("Cancel"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                requestReturn(
                                                  returnRequestId,
                                                  returnAssetName,
                                                );
                                              },
                                              child: const Text("Yes, Return"),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  : null,
                              icon: Icon(
                                Icons.assignment_return_outlined,
                                color: canReturn
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                              label: Text(
                                'Return',
                                style: TextStyle(
                                  color: canReturn
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canReturn
                                    ? Colors.purple.shade400
                                    : Colors.grey.shade300,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Equipment List
                      if (_filteredList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _searchQuery.isEmpty
                                ? "No equipment"
                                : "No equipment found for \"$_searchQuery\"",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ..._filteredList.map((item) {
                          final String assetStatus =
                              (item['asset_status'] ?? 'Available').toString();
                          final String returnStatus =
                              (item['return_status'] ?? '').toString();

                          late final String displayStatus;
                          late final Color statusColor;
                          bool enableBorrow = false;

                          if (returnStatus == 'Requested Return') {
                            // ถ้า return_status เป็น Request Return
                            displayStatus = 'Request Return';
                            statusColor = Colors.purple;
                            enableBorrow = false;
                          } else if (assetStatus == 'Available') {
                            displayStatus = 'Available';
                            statusColor = Colors.green;
                            enableBorrow = true;
                          } else if (assetStatus == 'Pending') {
                            displayStatus = 'Pending';
                            statusColor = Colors.orange;
                            enableBorrow = false;
                          } else if (assetStatus == 'Borrowed') {
                            displayStatus = 'Borrowed';
                            statusColor = Colors.blue;
                            enableBorrow = false;
                          } else if (assetStatus == 'Disabled') {
                            displayStatus = 'Disabled';
                            statusColor = Colors.red;
                            enableBorrow = false;
                          } else if (assetStatus == 'Rejected') {
                            displayStatus = 'Rejected';
                            statusColor = Colors.red;
                            enableBorrow = false;
                          } else {
                            displayStatus = 'Unknown';
                            statusColor = Colors.grey;
                            enableBorrow = false;
                          }
                          //final bool enableBorrow = isAvailable;
                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['asset_name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          displayStatus,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: enableBorrow
                                              ? () => confirmBorrow(
                                                  item['asset_id'],
                                                  item['asset_name'],
                                                )
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: enableBorrow
                                                ? Colors.blue
                                                : Colors.grey,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                          child: const Text("Borrow"),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      buildImageUrl(item['image']?.toString()),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        size: 60,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
