import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/lender/lender.dart';
import 'package:flutter_application_1/register/register.dart';
import 'package:flutter_application_1/staff/staff.dart';
import 'package:flutter_application_1/student/student.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_application_1/config/config.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  // ตัวควบคุมช่องกรอก
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // URL ของเซิร์ฟเวอร์ สามาเปลี่ยนได้***********************************************************อย่าลืมเปลี่ยนนะ************************************
  final url = '$defaultIp:$defaultPort';
  bool _isLoading = false; // เผื่อไว้แสดงสถานะโหลดตอนกด Log in

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      debugPrint('Server URL: $url');
    });

    try {
      Uri uri = Uri.http(url, '/login');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': _usernameController.text.trim(),
              'password': _passwordController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 5));
      // safety check ใน Flutter เพื่อป้องกันการเรียกใช้ setState หรือ widget methods หลังจากที่ widget ถูกทำลายไปแล้ว
      if (!mounted) return;

      if (response.statusCode == 200) {
        // เอา token สำหรับเก็บ response body ที่ส่งกลับมา
        String token = response.body;

        // เก็บ token ใน FlutterSecureStorage
        final storage = FlutterSecureStorage();
        await storage.write(key: 'token', value: token);
        if (!mounted) return;

        // Decode JWT token
        final jwt = JWT.decode(token);
        Map payload = jwt.payload;
        // แสดง Success message
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(payload['message'])));

        // นำทางไปยังหน้าต่างๆ ตาม role
        switch (payload['role']) {
          case 'student':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Student()),
            );
            break;
          case 'staff':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Staff()),
            );
            break;
          case 'lender':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Lender()),
            );
            break;
        }
      } else {
        // แสดง error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Error details: $e'); // เพิ่มการ print error เพื่อดูรายละเอียด
      if (!mounted) return;
      // แสดง error message กรณีมีปัญหาการเชื่อมต่อ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection error. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _register() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Navigate to Register Page')));

    // หน่วงเวลาเล็กน้อยให้เห็น SnackBar ก่อนเปลี่ยนหน้า
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Register()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9ECFF), // พื้นหลังฟ้าอ่อน
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Log in",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 40),

                // Username
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Username",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline),
                    hintText: 'Enter your username',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // Password
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Password",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    hintText: 'Enter your password',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ปุ่ม Log in และ Register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Log in
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 35,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.black26),
                        ),
                        elevation: 5,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              "Log in",
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                    const SizedBox(width: 20),

                    // Register
                    ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB3DEFF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 35,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Colors.black26),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        "Register",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
