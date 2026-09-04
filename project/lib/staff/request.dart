import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/staff/staff.dart';
import 'package:flutter_application_1/staff/staff_history.dart';
import 'package:flutter_application_1/login/login.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'package:flutter_application_1/config/config.dart';

class Request extends StatefulWidget {
  // final int staffId;
  // final String username;
  const Request({super.key});

  @override
  State<Request> createState() => _RequestState();
}

class _RequestState extends State<Request> {
  int? staffId;
  String? username;
  List requests = [];
  bool isLoading = true;
  bool isError = false;
  int _selectedIndex = 0;
  int _notificationCount = 0; // สำหรับนับจำนวนแจ้งเตือน return
  List<int> hiddenRequestIds = []; // เก็บ ID ของ request ที่ถูกซ่อน

  final String baseUrl = "http://$defaultIp:$defaultPort";

  // ========== ดึง user_id จาก token ==========
  Future<void> _loadUserAndFetch() async {
    final storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'token');
    int? userId;

    if (token != null) {
      try {
        final jwt = JWT.decode(token);
        Map payload = jwt.payload;
        userId = payload['user_id'] as int;
        String fetchedUsername = payload['username'] ?? 'Staff';

        if (mounted) {
          setState(() {
            staffId = userId;
            username = fetchedUsername; // ใช้ username จาก token เลย
          });
        }
      } catch (e) {
        debugPrint("Token decoding error: $e");
        userId = null;
      }
    }

    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login again.")));
      if (mounted) setState(() => isLoading = false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (route) => false,
      );
      return;
    }

    // โหลดข้อมูลหลัก
    try {
      await fetchRequests();
      await fetchNotificationCount();
    } catch (e) {
      debugPrint("Error fetching initial data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error during initial load.")),
        );
      }
      setState(() => isError = true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // โหลดข้อมูล request จาก server
  Future<void> fetchRequests() async {
    if (staffId == null) return;

    if (mounted) {
      // ตั้งค่า isLoading เป็น true เพื่อแสดงโหลดเฉพาะตอน fetchRequests
      setState(() {
        isLoading = true;
        requests = [];
      });
    }

    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final res = await http.get(
        Uri.parse('$baseUrl/staff/request/$staffId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            requests = (data['requests'] ?? [])
                .where((r) => !hiddenRequestIds.contains(r['id']))
                .toList();
          });
        }
      } else {
        throw Exception('Failed to load requests: ${res.statusCode}');
      }
    } catch (e) {
      // ... Error handling ...
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ✅ ฟังก์ชันคืนของ (PUT) คืนของ
  Future<void> returnAsset(int requestId) async {
    if (staffId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID not found. Please re-login.")),
      );
      return;
    }
    // แสดง loading
    setState(() => isLoading = true);

    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final res = await http.put(
        Uri.parse("$baseUrl/staff/returnAsset/$requestId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"staff_id": staffId}),
      );

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ คืนอุปกรณ์สำเร็จ")));

        // ✅ ลบแถวเฉพาะ UI
        setState(() {
          hiddenRequestIds.add(requestId);
          requests.removeWhere((r) => r['id'] == requestId);

          // ลด badge แจ้งเตือนถ้าจำนวนมากกว่า 0
          if (_notificationCount > 0) _notificationCount--;
        });

        // ไม่ต้อง fetchRequests() ใหม่ ไม่กระทบ database
      } else {
        String errorMessage = 'เกิดข้อผิดพลาดในการคืนอุปกรณ์';
        try {
          final errorBody = json.decode(res.body);
          errorMessage = errorBody['message'] ?? errorMessage;
        } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ คืนอุปกรณ์ไม่สำเร็จ: $errorMessage")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์"),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // แจ้งเตือน
  Future<void> fetchNotificationCount() async {
    final storage = FlutterSecureStorage();
    final token = await storage.read(key: 'token');

    final res = await http.get(
      Uri.parse("$baseUrl/api/returnCount"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        _notificationCount = data['count'] ?? 0;
      });
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
      final storage = FlutterSecureStorage();
      await storage.delete(key: 'token');
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (route) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchRequests(); // โหลด request return
    fetchNotificationCount(); // ✅ โหลดจำนวนแจ้งเตือนเมื่อเปิดหน้า
    _loadUserAndFetch();
  }

  // ✅ ฟังก์ชันเปลี่ยนหน้า
  void _onItemTapped(int i) {
    setState(() => _selectedIndex = i);
    switch (i) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Staff()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StaffHistory()),
        );
        break;
      case 3:
        _logout();
        break;
    }
  }

  // ฟังก์ชันแปลงวันที่ (ตัดเวลาออก)
  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';
    try {
      return DateTime.parse(dateString).toLocal().toString().split(' ')[0];
    } catch (_) {
      return dateString.split(' ')[0]; // fallback ถ้า format ไม่ตรง
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      bottomNavigationBar: _buildBottomBar(),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : isError
            ? _buildErrorView()
            : RefreshIndicator(
                // <-- เพิ่ม RefreshIndicator
                onRefresh: fetchRequests, // ฟังก์ชันรีโหลด
                child: SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(), // ทำให้สามารถ scroll เพื่อ refresh ได้แม้ content น้อย
                  child: Column(children: [_buildHeader(), _buildTable()]),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 175,
      color: Colors.lightBlue[100],
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.black12,
            child: Icon(Icons.person, size: 50, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text(
            '$username',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            "(Staff)",
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 10),
          const Text("ไม่สามารถโหลดข้อมูลได้", style: TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              setState(() {
                isLoading = true;
                isError = false;
              });
              fetchRequests();
            },
            child: const Text("ลองอีกครั้ง"),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Expanded(child: Text("ID", textAlign: TextAlign.center)),
                Expanded(child: Text("Product", textAlign: TextAlign.center)),
                Expanded(
                  child: Text("Borrow Date", textAlign: TextAlign.center),
                ),
                Expanded(
                  child: Text("Return Date", textAlign: TextAlign.center),
                ),
                Expanded(child: Text("Status", textAlign: TextAlign.center)),
                Expanded(child: Text("Action", textAlign: TextAlign.center)),
              ],
            ),
          ),
          const Divider(),
          if (requests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "No requests found",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...requests.map((r) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${r['id']}",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "${r['name']}",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatDate(r['borrowDate']),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatDate(r['returnDate']),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "${r['returnStatus'] ?? '-'}",
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: (r['returnStatus'] == 'Requested Return')
                            ? Center(
                                child: SizedBox(
                                  height: 34,
                                  width: 90,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurpleAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () async {
                                      // --- Show Confirmation Dialog ---
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text(
                                            "Confirm Return",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Text(
                                            "Are you sure you want to return '${r['name']}'?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: const Text("Cancel"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.deepPurpleAccent,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text("Confirm"),
                                            ),
                                          ],
                                        ),
                                      );

                                      // --- ถ้ากดยืนยัน ให้คืนของและลบแถว ---
                                      if (confirm == true) {
                                        returnAsset(
                                          r['id'],
                                        ); // คืนของและลบแถวใน UI
                                      }
                                    },
                                    child: const Text("Return"),
                                  ),
                                ),
                              )
                            : const Text(
                                "-",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
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
    );
  }

  // ส่วนของ Bottom Navigation Bar
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.lightBlue[100],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.refresh, "Return"),
          _buildNavItem(1, Icons.home, "Staff"),
          _buildNavItem(2, Icons.history, "History"),
          _buildNavItem(3, Icons.logout, "Logout"),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    bool largeIcon = false,
  }) {
    final bool isSelected = _selectedIndex == index;
    final bool hasNotification =
        index == 0 && _notificationCount > 0; // ปุ่ม Return เท่านั้น

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          _onItemTapped(index);
          if (index == 1) {
            final storage = FlutterSecureStorage();
            final token = await storage.read(key: 'token');
            await http.delete(
              Uri.parse("$baseUrl/api/clearReturnNotifications"),
              headers: {"Authorization": "Bearer $token"},
            );
            setState(() => _notificationCount = 0);
          }
        },

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: largeIcon ? 42 : 28,
                  color: isSelected ? Colors.purple : Colors.black,
                ),
                if (hasNotification)
                  Positioned(
                    top: -2,
                    right: -6,
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
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.purple : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
