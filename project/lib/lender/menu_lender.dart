import 'package:flutter/material.dart';
//Import โมเดล PendingRequest (จากไฟล์ lender.dart)
import 'lender.dart';

class MenuLenderPage extends StatefulWidget {
  final PendingRequest request;

  const MenuLenderPage({super.key, required this.request});

  @override
  State<MenuLenderPage> createState() => _MenuLenderPageState();
}

class _MenuLenderPageState extends State<MenuLenderPage> {

  Future<void> _showDisapproveDialog() async {
    TextEditingController reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Disapprove Confirmation"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please provide a reason for disapproval:"),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Need to fill the Reason...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                Navigator.pop(dialogContext, reason);
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      if (mounted) {
        Navigator.pop(context, {'action': 'reject', 'reason': reason});
      }
    }
  }

  // ฟังก์ชัน format วันที่ (borrow Date)
  String _formatDate(String? dateString) {
    if (dateString == null) return "N/A";
    try {
      //แปลง String (ISO/UTC) เป็น DateTime
      final DateTime utcDateTime = DateTime.parse(dateString);
      //แปลงเป็นเวลาท้องถิ่น (Local Time)
      final DateTime localDateTime = utcDateTime.toLocal();
      //ดึงค่าจาก Local Time
      final String day = localDateTime.day.toString().padLeft(2, '0');
      final String month = localDateTime.month.toString().padLeft(2, '0');
      final String year = localDateTime.year.toString();
      return "$day/$month/$year";
    } catch (e) {
      return dateString;
    }
  }

  // ฟังก์ชันคำนวณวันคืน (Return Date)
  String _getReturnDate(String? dateString) {
    if (dateString == null) return "N/A";
    try {
      // 1. แปลง String (ISO/UTC) เป็น DateTime
      final DateTime utcDateTime = DateTime.parse(dateString);
      // แปลงเป็นเวลาท้องถิ่น (Local Time)
      final DateTime localDateTime = utcDateTime.toLocal();
      // 3. บวกไปอีก 7 วัน
      final DateTime returnDate = localDateTime.add(const Duration(days: 7));
      // 4. จัดรูปแบบ
      final String day = returnDate.day.toString().padLeft(2, '0');
      final String month = returnDate.month.toString().padLeft(2, '0');
      final String year = returnDate.year.toString();
      return "$day/$month/$year";
    } catch (e) {
      return "N/A";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE3F2FD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Review Request',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.request.assetImage,
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 150,
                          width: 150,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  //ส่วนแสดงรายละเอียด
                  _DetailRow(
                    label: "Asset Name:",
                    value: widget.request.assetName,
                  ),
                  _DetailRow(
                    label: "Request ID:",
                    value: widget.request.requestId.toString(),
                  ),
                  _DetailRow(
                    label: "Borrower:",
                    value: widget.request.borrowerName,
                  ),
                  _DetailRow(
                    label: "Borrow Date:",
                    value: _formatDate(widget.request.borrowDate),
                  ),
                  _DetailRow(
                    label: "Return Date:",
                    value: _getReturnDate(widget.request.borrowDate),
                  ),

                  const Divider(height: 30),

                  // (ปุ่ม Actions... เหมือนเดิม)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context, 'approve');
                          },
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Approve',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showDisapproveDialog();
                          },
                          icon: const Icon(Icons.cancel, color: Colors.white),
                          label: const Text(
                            'Disapprove',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
