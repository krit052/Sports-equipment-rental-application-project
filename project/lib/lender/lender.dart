import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'lender_history.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/login/login.dart';
import 'menu_lender.dart';
import 'package:flutter_application_1/config/config.dart';

final String baseIp = "$defaultIp:$defaultPort";
final String baseUrl = "http://$baseIp";

class PendingRequest {
  final int requestId;
  final String assetName;
  final String assetImage;
  final String borrowerName;
  final String borrowDate;
  String loanStatus;

  PendingRequest({
    required this.requestId,
    required this.assetName,
    required this.assetImage,
    required this.borrowerName,
    required this.borrowDate,
    this.loanStatus = "Pending",
  });

  factory PendingRequest.fromJson(Map<String, dynamic> json) {
    return PendingRequest(
      requestId: json['request_id'],
      assetName: json['asset_name'],
      assetImage: "$baseUrl${json['asset_image']}",
      borrowerName: json['borrower_name'],
      borrowDate: json['borrow_date'],
    );
  }
}

class Lender extends StatefulWidget {
  const Lender({super.key});

  @override
  State<Lender> createState() => _LenderState();
}

class _LenderState extends State<Lender> {
  List<PendingRequest> _pendingRequests = [];
  List<PendingRequest> _filteredRequests = [];
  bool _isLoading = true;
  String _errorMessage = '';

  int? _lenderId;
  String? _lenderName;

  //State Variables สำหรับ dashbroad
  int _totalAssets = 0;
  int _availableAssets = 0;
  int _pendingAssets = 0;
  int _borrowedAssets = 0;
  int _disabledAssets = 0;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchRequests();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
        _filterRequests();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterRequests() {
    if (_searchQuery.isEmpty) {
      _filteredRequests = _pendingRequests;
    } else {
      _filteredRequests = _pendingRequests
          .where((req) => req.assetName.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  //ฟังก์ชัน Logout (เหมือนเดิม)
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

  //อัปเดตฟังก์ชันนี้ให้ดึง Stats ด้วย
  Future<void> _loadUserDataAndFetchRequests() async {
    final storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'token');

    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Please login again.";
      });
      return;
    }

    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final jwt = JWT.decode(token);
      Map payload = jwt.payload;
      setState(() {
        _lenderId = payload['user_id'] as int;
        _lenderName = payload['username'] as String;
      });

      //เรียก API ทั้งสองตัว
      await Future.wait([_loadData(), _fetchAssetStats()]);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Invalid Token. Please login again. ($e)";
      });
    }
  }

  // สร้างฟังก์ชันดึงสถิติ
  Future<void> _fetchAssetStats() async {
    try {
      final storage = FlutterSecureStorage();
      String? token = await storage.read(key: 'token');
      final response = await http.get(
        Uri.parse('$baseUrl/lender/asset-stats'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['stats'] != null) {
          final stats = data['stats'];
          if (mounted) {
            setState(() {
              _totalAssets = int.tryParse(stats['total'].toString()) ?? 0;
              _availableAssets =
                  int.tryParse(stats['available'].toString()) ?? 0;
              _pendingAssets = int.tryParse(stats['pending'].toString()) ?? 0;
              _borrowedAssets = int.tryParse(stats['borrowed'].toString()) ?? 0;
              _disabledAssets = int.tryParse(stats['disabled'].toString()) ?? 0;
            });
          }
        }
      } else {
        debugPrint("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  // (ฟังก์ชัน _loadData)
  Future<void> _loadData() async {
    try {
      final storage = FlutterSecureStorage();
      String? token = await storage.read(key: 'token');
      final response = await http.get(
        Uri.parse('$baseUrl/lender/pending-requests'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<dynamic> requestsJson = data['pendingRequests'];
          if (mounted) {
            setState(() {
              _pendingRequests = requestsJson
                  .map((json) => PendingRequest.fromJson(json))
                  .toList();
              _filteredRequests = _pendingRequests;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Failed to load data (Code: ${response.statusCode})';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error connecting to server: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  //เพิ่มฟังก์ชันนี้: สำหรับการนำทาง
  Future<void> _navigateToDetail(PendingRequest request) async {
    if (_lenderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Lender ID not found")),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MenuLenderPage(request: request)),
    );

    //เมื่อหน้ารายละเอียด "pop" (ปิด) กลับมา
    if (result == 'approve') {
      await _callApiAction(request.requestId, 'approve', null);
      await _loadUserDataAndFetchRequests();
    } else if (result is Map && result['action'] == 'reject') {
      await _callApiAction(request.requestId, 'reject', result['reason']);
      await _loadUserDataAndFetchRequests();
    }
  }

  Future<void> _callApiAction(
    int requestId,
    String action,
    String? reason,
  ) async {
    if (_lenderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: Lender ID not found. Please re-login."),
        ),
      );
      return;
    }

    final url = '$baseUrl/lender/borrowingRequest/$requestId/$action';

    final body = {
      "lender_id": _lenderId.toString(),
      if (reason != null) 'reason': reason,
    };

    try {
      // อ่าน token จาก storage แล้วแนบเป็น Authorization header
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Action successful."),
            backgroundColor: Colors.green,
          ),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unauthorized. Token missing or expired."),
            backgroundColor: Colors.redAccent,
          ),
        );
        // optional: force logout / prompt re-login
      } else {
        final msg = (response.body.isNotEmpty)
            ? json.decode(response.body)['message'] ?? response.body
            : 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: $msg"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  //Build UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Lender Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.lightBlue[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUserDataAndFetchRequests,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Profile Header
                Container(
                  width: double.infinity,
                  color: Colors.lightBlue[100],
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.black12,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // เปลี่ยนจาก Nook → Sara
                      Text(
                        "${_lenderName ?? 'Lender'} (Lender)",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatBox(
                            color: Colors.purple,
                            label: "Total",
                            value: _totalAssets.toString(),
                          ),
                          _StatBox(
                            color: Colors.green,
                            label: "Available",
                            value: _availableAssets.toString(),
                          ),
                          _StatBox(
                            color: Colors.orange,
                            label: "Pending",
                            value: _pendingAssets.toString(),
                          ),
                          _StatBox(
                            color: Colors.blue,
                            label: "Borrowed",
                            value: _borrowedAssets.toString(),
                          ),
                          _StatBox(
                            color: Colors.red,
                            label: "Disable",
                            value: _disabledAssets.toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.history, color: Colors.white),
                          label: const Text(
                            "History",
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Lenderhistory(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

                const SizedBox(height: 12),

                // Product List
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 5,
                        spreadRadius: 5,
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
                        child: Row(
                          children: const [
                            Expanded(
                              flex: 1,
                              child: Text(
                                "ID",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "Product",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "Image",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "Status",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                "Actions",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),

                      // ใช้ _filteredRequests แทน
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        )
                      else if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      else if (_filteredRequests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _searchQuery.isEmpty
                                ? "No pending requests."
                                : "No assets found matching \"$_searchQuery\"",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ..._filteredRequests.map((request) {
                          return Column(
                            children: [
                              _ProductRow(
                                id: request.requestId.toString(),
                                name: request.assetName,
                                imagePath: request.assetImage,
                                loanStatus: request.loanStatus,

                                onPressed: () {
                                  _navigateToDetail(request);
                                },
                              ),
                              const Divider(),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _StatBox({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final String id;
  final String name;
  final String imagePath;
  final String loanStatus;
  final VoidCallback onPressed;

  const _ProductRow({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.loanStatus,
    required this.onPressed,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Borrowed':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      case 'Disapproved':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              id,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              name,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(imagePath),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) => const Icon(
                      Icons.broken_image,
                      size: 24,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              loanStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _getStatusColor(loanStatus),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Review",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
