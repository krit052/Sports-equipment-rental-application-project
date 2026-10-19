import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/staff/request.dart';
import 'package:flutter_application_1/staff/staff_history.dart';
import 'package:flutter_application_1/login/login.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_application_1/config/config.dart';

// Class สำหรับข้อมูลสินทรัพย์
class Product {
  final String id;
  final String name;
  final String imagePath;
  final String status;
  final Color statusColor;
  bool isReturned;

  Product({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.status,
    required this.statusColor,
    this.isReturned = false,
  });
}

class Staff extends StatefulWidget {
  // final int staffId;
  // final String username;

  //const Staff({super.key, required this.staffId, required this.username});
  const Staff({super.key});

  @override
  State<Staff> createState() => _StaffState();
}

class _StaffState extends State<Staff> {
  int? staffId;
  String? username;
  int _selectedIndex = 1;
  int notificationCount = 0; // เพิ่มตัวแปรแจ้งเตือน
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  final String baseUrl = "http://$defaultIp:$defaultPort";

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  //ตัวแปร state เก็บสรุป
  int totalAssets = 0;
  int availableCount = 0;
  int pendingCount = 0;
  int borrowedCount = 0;
  int disabledCount = 0;

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
    _initStaffData();
    _fetchAssets();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
        _filterProducts();
      });
    });
    _fetchAssets(); // โหลดข้อมูล assets
    _fetchDashboardData(); //โหลดข้อมูล Dashboard
    _fetchNotifications(); //เรียกใช้ แจ้งเตือน
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = _products;
    } else {
      _filteredProducts = _products
          .where((p) => p.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  // โหลดข้อมูล staff JWT
  Future<void> _initStaffData() async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      if (token == null) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const Login()),
            (route) => false,
          );
        }
        return;
      }

      final jwt = JWT.decode(token);
      final payload = jwt.payload;

      setState(() {
        staffId = payload['user_id'];
        username = payload['username'];
      });

      await _fetchAssets();
      await _fetchDashboardData();
      await _fetchNotifications();
    } catch (e) {
      debugPrint("❌ Error decoding token: $e");
    }
  }

  // โหลดข้อมูลสินทรัพย์จากฐานข้อมูล
  Future<void> _fetchAssets() async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final url = Uri.parse('$baseUrl/assets');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final assets = data['assets'] as List;
        setState(() {
          _products = assets
              .map(
                (item) => Product(
                  id: item['asset_id'].toString(),
                  name: item['asset_name'],
                  imagePath:
                      "$baseUrl${item['image'] ?? '/public/image/default.jpg'}",
                  status: item['asset_status'],
                  statusColor: _getStatusColor(item['asset_status']),
                ),
              )
              .toList();

          // คำนวณสถิติจาก _products
          totalAssets = _products.length;
          availableCount = _products
              .where((p) => p.status == "Available")
              .length;
          pendingCount = _products.where((p) => p.status == "Pending").length;
          borrowedCount = _products.where((p) => p.status == "Borrowed").length;
          disabledCount = _products.where((p) => p.status == "Disabled").length;
          _filterProducts();
        });
        debugPrint("Assets loaded: ${_products.length}");
      } else {
        debugPrint("Failed to load assets: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching assets: $e");
    }
  }

  // กำหนดสีตามสถานะ
  Color _getStatusColor(String status) {
    switch (status) {
      case "Available":
        return Colors.green;
      case "Pending":
        return Colors.orange;
      case "Borrowed":
        return Colors.blue;
      case "Disabled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // เพิ่มสินทรัพย์ใหม่
  Future<void> addAsset(String name, String description, [XFile? image]) async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      final uri = Uri.parse('$baseUrl/staff/addAsset');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['name'] = name;
      request.fields['description'] = description;
      if (image != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            await image.readAsBytes(),
            filename: image.name,
          ),
        );
      }

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);

      if (response.statusCode == 200 && data['success'] == true) {
        _showPopup("Success", data['message'], true);
        _fetchAssets();
      } else {
        _showPopup("Error", data['message'] ?? 'Something went wrong', false);
      }
    } catch (e) {
      _showPopup("Error", e.toString(), false);
    }
  }

  // ✅ เพิ่มฟังก์ชันแก้ไขสินทรัพย์
  Future<void> _editAsset(String id, String name, [XFile? image]) async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final uri = Uri.parse('$baseUrl/staff/editAsset/$id');
      var request = http.MultipartRequest('PUT', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['name'] = name;
      request.fields['description'] = "Sport Equipment";

      if (image != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            await image.readAsBytes(),
            filename: image.name,
          ),
        );
      }

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);

      if (response.statusCode == 200 && data['success'] == true) {
        _showPopup("Success", data['message'], true, onApply: _fetchAssets);
      } else {
        _showPopup("Error", data['message'] ?? 'Failed to update asset', false);
      }
    } catch (e) {
      _showPopup("Error", "Error updating asset: $e", false);
    }
  }

  // แสดง Popup
  void _showPopup(
    String title,
    String message,
    bool success, {
    VoidCallback? onApply,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: success ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: success ? Colors.green : Colors.red,
                child: Icon(
                  success ? Icons.check : Icons.error_outline,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: success ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  // ปิดทุก dialog (popup) ที่ซ้อนอยู่ แล้วเรียก onApply
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).popUntil((route) => route is! PopupRoute);
                  onApply?.call();
                },
                child: const Text("Close"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // สลับสถานะ Enable/Disable
  Future<void> _toggleAssetStatus(String assetId, String currentStatus) async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      final endpoint = currentStatus == "Disabled" ? "enable" : "disable";
      final url = Uri.parse("$baseUrl/staff/editAsset/$assetId/$endpoint");

      final response = await http.put(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _fetchAssets();
          _showPopup("Success", data['message'] ?? "Status updated", true);
        } else {
          _showPopup(
            "Error",
            data['message'] ?? "Failed to change status",
            false,
          );
        }
      }
    } catch (e) {
      _showPopup("Error", "Error toggling status: $e", false);
    }
  }

  // ลบสินทรัพย์
  Future<void> _deleteAsset(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this asset?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final storage = FlutterSecureStorage();
        final token = await storage.read(key: 'token');
        final url = Uri.parse("$baseUrl/staff/deleteAsset/$id");
        final response = await http.delete(
          url,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          _fetchAssets();
          _showPopup("Success", "Asset deleted successfully", true);
        }
      } catch (e) {
        _showPopup("Error", "Error deleting asset: $e", false);
      }
    }
  }

  // Bottom Navigation
  void _onItemTapped(int i) {
    setState(() => _selectedIndex = i);
    switch (i) {
      case 0:
        _clearReturnNotifications(); // ล้างแจ้งเตือนก่อนเปิดหน้า
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Request()),
        );
        break;
      case 1:
        _fetchAssets();
        _fetchDashboardData();
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

  void _showEditDialog(Product product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: _ProductFormDialog(
          title: "Edit Asset",
          initialProductName: product.name,
          id: product.id,
          isEdit: true,
          onAddAsset: (name, _, image) => _editAsset(product.id, name, image),
        ),
      ),
    );
  }

  // Dashboard Data API
  Future<void> _fetchDashboardData() async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      // ✅ แก้ URL ให้ถูก
      final url = Uri.parse('$baseUrl/staff/dashboard/$staffId');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data["success"] == true && data["data"] != null) {
          setState(() {
            totalAssets = data["data"]["total_assets"] ?? 0;
            availableCount = data["data"]["available_assets"] ?? 0;
            borrowedCount = data["data"]["borrowed_assets"] ?? 0;
            pendingCount = data["data"]["pending_requests"] ?? 0;
            disabledCount = _products
                .where((p) => p.status == "Disabled")
                .length; // หรือเปลี่ยนชื่อ field ตามที่ backend ส่งมา
          });
        } else {
          debugPrint("⚠️ Dashboard API returned success=false or no data");
        }
      } else {
        debugPrint("❌ Dashboard API failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching dashboard data: $e");
    }
  }

  // ✅ ฟังก์ชันโหลดจำนวนแจ้งเตือน
  Future<void> _fetchNotifications() async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final url = Uri.parse("$baseUrl/api/returnCount");
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token', // ถ้า backend ต้องการ
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          notificationCount = data['count'] ?? 0;
        });
      } else {
        debugPrint("❌ Failed to fetch notifications: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching notifications: $e");
    }
  }

  // ✅ ล้างแจ้งเตือนแจ้งเตือน
  Future<void> _clearReturnNotifications() async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final url = Uri.parse("$baseUrl/api/clearReturnNotifications");
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          notificationCount = 0; // ล้าง badge ทันที
        });
        debugPrint("✅ Notifications cleared");
      } else {
        debugPrint("❌ Failed to clear notifications: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error clearing notifications: $e");
    }
  }

  // refresh กับ bottom nav bar
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              content: _ProductFormDialog(
                title: "Add Asset",
                initialProductName: "",
                id: "",
                onAddAsset: (name, _, image) =>
                    addAsset(name, "Sport Equipment", image),
              ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),

      bottomNavigationBar: _buildBottomNavBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchAssets,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Material(
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
                ),

                const SizedBox(height: 8),

                _buildTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Headder
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      //height: 200,
      color: Colors.lightBlue[100],
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.black12,
            child: Icon(Icons.person, size: 50, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text(
            "$username",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text(
            "(Staff)",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),

          // ✅ เพิ่ม Dashboard ที่นี่
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatCard("Total", totalAssets, Colors.purple),
                _buildStatCard("Available", availableCount, Colors.green),
                _buildStatCard("Pending", pendingCount, Colors.orange),
                _buildStatCard("Borrowed", borrowedCount, Colors.blue),
                _buildStatCard("Disable", disabledCount, Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 ย้ายฟังก์ชัน statCard มาแยกออกไว้ใช้ใน Header
  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // สร้าง table เอาไว้ดูข้อมูล ของ asset
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
                Expanded(child: Text("Image", textAlign: TextAlign.center)),
                Expanded(child: Text("Status", textAlign: TextAlign.center)),
                Expanded(child: Text("Actions", textAlign: TextAlign.center)),
              ],
            ),
          ),
          const Divider(),
          if (_filteredProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _searchQuery.isEmpty
                    ? "No assets"
                    : "No matching assets found for \"$_searchQuery\"",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ..._filteredProducts.map((p) {
              return Column(
                children: [
                  _ProductRow(
                    id: p.id,
                    name: p.name,
                    imagePath: p.imagePath,
                    status: p.status,
                    statusColor: p.statusColor,
                    isReturned: p.isReturned,
                    onEdit: () => _showEditDialog(p),
                    onToggleDisable: (id) => _toggleAssetStatus(id, p.status),
                    onDelete: _deleteAsset,
                  ),
                  const Divider(),
                ],
              );
            }),
        ],
      ),
    );
  }

  //สร้าง bottom nav bar
  Widget _buildBottomNavBar() {
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
          _buildNavItem(1, Icons.home, "Home"),
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

    // ตรวจสอบถ้าเป็นไอคอน Notifications (สมมติว่า index 1)
    bool showBadge = index == 0 && notificationCount > 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: largeIcon ? 42 : 28,
                  color: isSelected ? Colors.purple : Colors.black,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.purple : Colors.black,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (showBadge)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    notificationCount.toString(),
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
    );
  }
}

// Widget แถวข้อมูล
class _ProductRow extends StatelessWidget {
  final String id, name, imagePath, status;
  final Color statusColor;
  final VoidCallback onEdit;
  final Function(String) onToggleDisable;
  final Function(String) onDelete;
  final bool isReturned;

  const _ProductRow({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.status,
    required this.statusColor,
    required this.onEdit,
    required this.onToggleDisable,
    required this.onDelete,
    required this.isReturned,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = status == "Disabled";
    final String toggleButtonText = isDisabled ? "Enable" : "Disable";
    final Color toggleButtonColor = isDisabled
        ? Colors.green.shade700
        : Colors.red.shade700;

    return Row(
      children: [
        Expanded(child: Text(id, textAlign: TextAlign.center)),
        Expanded(child: Text(name, textAlign: TextAlign.center)),
        Expanded(
          child: Center(
            child: CircleAvatar(
              backgroundImage: NetworkImage(imagePath),
              radius: 20,
            ),
          ),
        ),
        Expanded(
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 25),
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Edit", style: TextStyle(fontSize: 10)),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () async {
                  // ⚠️ ถ้าสถานะเป็น Borrowed → แสดง Warning สีเหลือง และยกเลิก
                  if (status == "Borrowed") {
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.yellow.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Row(
                          children: const [
                            Icon(Icons.warning, color: Colors.orange, size: 28),
                            SizedBox(width: 10),
                            Text(
                              "Warning",
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                        content: const Text(
                          "This asset is currently Borrowed.\nYou cannot disable it now.",
                          style: TextStyle(fontSize: 16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "OK",
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    );
                    return; // ❌ หยุด ไม่ให้ Disable
                  }

                  // 🟦 ถ้าไม่ใช่ Borrowed → ทำงานปกติ
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text("$toggleButtonText Asset"),
                      content: Text(
                        "Are you sure you want to ${toggleButtonText.toLowerCase()} this asset?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            toggleButtonText,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    onToggleDisable(id);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: toggleButtonColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 25),
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  toggleButtonText,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () => onDelete(id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 25),
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Delete", style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Dialog เพิ่ม/แก้ไข
class _ProductFormDialog extends StatefulWidget {
  final String title, initialProductName, id;
  final bool isEdit;
  final Future<void> Function(String, String, XFile?) onAddAsset;

  const _ProductFormDialog({
    required this.title,
    required this.initialProductName,
    required this.id,
    required this.onAddAsset,
    this.isEdit = false,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final TextEditingController controller = TextEditingController();
  XFile? image;
  Uint8List? _imageBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    controller.text = widget.initialProductName;
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      image = picked;
      _imageBytes = bytes;
    });
  }

  void _showPopup(String title, String message, bool success) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.onAddAsset(controller.text, "Sport Equipment", image);
      if (!mounted) return;
      _showPopup(
        "Success",
        widget.isEdit
            ? "Asset updated successfully"
            : "Asset added successfully",
        true,
      );
      Navigator.pop(context);
    } catch (e) {
      _showPopup("Error", e.toString(), false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Product name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.image),
              label: Text(widget.isEdit ? "Change Image" : "Choose Image"),
            ),
            if (image != null) ...[
              const SizedBox(height: 10),
              Image.memory(_imageBytes!, height: 100),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isEdit
                        ? Colors.lightGreen
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(widget.isEdit ? "Save Changes" : "Add Asset"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
