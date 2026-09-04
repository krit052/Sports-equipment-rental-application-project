import 'package:flutter/material.dart';
import 'package:flutter_application_1/login/login.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD6EAF8), // ฟ้าอ่อน
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // รูปภาพวงกลม
              ClipOval(
                child: Image.asset(
                  'asset/image/landing.jpg', // ใช้รูปที่แนบไว้ เช่นเปลี่ยนชื่อไฟล์นี้
                  width: 450,
                  height: 450,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 50),

              // ปุ่ม Sign in
              ElevatedButton(
                onPressed: () {
                  // ไปหน้า sign in
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Login()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 149, 196, 230),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  "Sign in",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
