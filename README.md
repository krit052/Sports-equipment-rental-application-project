# AssetProject

ระบบยืม-คืนครุภัณฑ์ (Asset Borrowing System) ประกอบด้วย 2 ส่วน:

| โฟลเดอร์ | เทคโนโลยี | หน้าที่ |
|---|---|---|
| [`BackendProject/`](BackendProject) | Node.js + Express + MongoDB (Mongoose) | REST API |
| [`project/`](project) | Flutter (Dart) | แอปมือถือฝั่งผู้ใช้ (นักเรียน/ผู้ยืม/เจ้าหน้าที่) |

> **หมายเหตุ:** `project/` มี `.git` ของตัวเอง เชื่อมกับ remote จริงที่ `github.com/6631501036-dev/project.git` (มีหลาย branch/ประวัติ commit อยู่แล้ว) จึงตั้งใจ**ไม่ลบทิ้ง** — มันไม่ใช่บั๊ก แต่เป็น repo แยกที่ถูกย้ายมาไว้ในโฟลเดอร์เดียวกันเฉยๆ ผลคือ repo หลัก (root) จะไม่ track ไฟล์ข้างใน `project/` เป็นไฟล์ปกติ (`git status` ที่ root เห็นแค่ `project/` เป็นโฟลเดอร์เดียว) ถ้าต้องการ commit งานใน `project/` ให้ทำจากภายในโฟลเดอร์นั้น (`cd project && git status`) แยกจาก repo หลัก

---

## สิ่งที่ต้องติดตั้งก่อน (Prerequisites)

- [Node.js](https://nodejs.org/) (LTS) + npm
- [MongoDB](https://www.mongodb.com/try/download/community) รันอยู่ที่ local (`mongodb://127.0.0.1:27017`)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.8.1` ตามที่ระบุใน `pubspec.yaml`)
- Android Studio / Xcode หรืออุปกรณ์จริงสำหรับรัน Flutter app
- คอมพิวเตอร์ที่รัน backend และมือถือ/emulator ที่รัน Flutter app ต้องอยู่ **วง LAN/Wi-Fi เดียวกัน** เพราะแอปเรียก API ผ่าน IP โดยตรง (ไม่ใช่ `localhost`)

---

## 1. ตั้งค่าและรัน Backend (`BackendProject/`)

```bash
cd BackendProject
npm install
```

1. เปิด MongoDB ให้รันอยู่ที่ local (`mongodb://127.0.0.1:27017`) — database ชื่อ `project` จะถูกสร้างอัตโนมัติ
2. ตรวจสอบไฟล์ [`BackendProject/.env`](BackendProject/.env) (สร้างไว้ให้แล้ว) และแก้ `JWT_SECRET` เป็นค่าสุ่มของตัวเองก่อนใช้งานจริง:

   ```env
   MONGO_URI=mongodb://127.0.0.1:27017/project
   PORT=3000
   JWT_SECRET=change-this-to-a-long-random-secret-in-production
   JWT_EXPIRES_IN=7d
   ```

3. สร้างบัญชี `staff`/`lender` เริ่มต้น และข้อมูลครุภัณฑ์ตัวอย่าง (สมัครผ่านหน้า Register ของแอปจะได้แค่ role `student` เท่านั้น):

   ```bash
   npm run seed
   ```

   จะได้บัญชี `staff1` / `staff123` (role staff) และ `lender1` / `lender123` (role lender) พร้อมครุภัณฑ์ตัวอย่าง 3 ชิ้น รันซ้ำได้ปลอดภัย (ข้ามรายการที่มีอยู่แล้ว)

4. รันเซิร์ฟเวอร์:

   ```bash
   npm start
   ```

   จะเห็น log `server is running on port 3000` และ `Status: connected to local database successfully`

5. ทดสอบว่าใช้งานได้:

   ```bash
   curl -X POST http://localhost:3000/login -H "Content-Type: application/json" -d "{\"username\":\"staff1\",\"password\":\"staff123\"}"
   ```

   ควรได้ JWT token กลับมาเป็น plain text

### โครงสร้าง backend

```
BackendProject/
  index.js              # ผูก route ทั้งหมด + เปิด static /public
  config/db.js           # เชื่อมต่อ MongoDB
  middleware/auth.js      # ตรวจ Authorization: Bearer <JWT>
  middleware/upload.js    # multer (อัปโหลดรูปครุภัณฑ์ ไปที่ public/image/)
  models/                 # User, Asset, BorrowRequest, Counter (สร้าง id เป็นเลขจำนวนเต็ม)
  routes/
    auth.js               # POST /login, POST /register
    api.js                # /api/... (student + history/notification ที่ /api ใช้ร่วมกัน)
    assets.js             # GET /assets
    staff.js               # /staff/... (จัดการครุภัณฑ์, คืนของ, dashboard)
    lender.js               # /lender/... (อนุมัติ/ปฏิเสธคำขอยืม)
    borrower.js             # /borrower/... (endpoint สำรอง ไม่ถูกเรียกใช้จริงจาก UI ปัจจุบัน)
  scripts/seed.js          # สร้างบัญชี staff/lender + ครุภัณฑ์ตัวอย่าง
  public/image/            # ไฟล์รูปครุภัณฑ์ที่อัปโหลด (เสิร์ฟที่ /public/image/...)
```

Route ทั้งหมดตรงกับที่ฝั่ง Flutter (`project/lib/**`) เรียกใช้จริงแล้ว (login/register, ยืม-คืน, อนุมัติของ lender, จัดการครุภัณฑ์และแจ้งเตือนของ staff) — id ของ user/asset/request เป็นเลขจำนวนเต็มธรรมดา (ไม่ใช่ MongoDB ObjectId) เพราะฝั่งแอป decode ค่าพวกนี้เป็น `int` โดยตรง (เช่นจาก JWT payload)

---

## 2. ตั้งค่าและรัน Frontend (`project/`)

```bash
cd project
flutter pub get
```

### ตั้งค่าไฟล์ `.env`

ไฟล์ [`project/.env`](project/.env) ถูกอ่านผ่าน [`lib/config/config.dart`](project/lib/config/config.dart) เพื่อประกอบ base URL ของ API (`SCHEME://DEFAULT_IP:PORT`):

```env
DEFAULT_IP=<IP เครื่องที่รัน backend>
PORT=3000
SCHEME=http
```

หา IP เครื่องที่รัน backend ด้วย:

```powershell
ipconfig
```

แล้วดูค่า `IPv4 Address` ของวง Wi-Fi/LAN ที่ใช้อยู่ (เช่น `192.168.x.x`) — ใส่ค่านี้แทน `DEFAULT_IP`

> ถ้ารันบน Android Emulator บนเครื่องเดียวกับ backend อาจใช้ `10.0.2.2` แทนได้เช่นกัน แต่ถ้าทดสอบบนมือถือจริงต้องใช้ IP จริงของเครื่อง backend เท่านั้น

### รันแอป

```bash
flutter run
```

เลือก device/emulator ที่ต้องการ (`flutter devices` เพื่อดูรายการที่เชื่อมต่ออยู่)

---

## โครงสร้างแอป (`project/lib/`)

- `welcome/`, `login/`, `register/` — เข้าสู่ระบบ/สมัครสมาชิก
- `student/` — มุมมองนักเรียน (สถานะการยืม, ประวัติ, การคืน)
- `lender/` — มุมมองผู้ยืม
- `staff/` — มุมมองเจ้าหน้าที่ (จัดการครุภัณฑ์, คำขอยืม-คืน)
- `config/config.dart` — อ่านค่า `.env` เพื่อคำนวณ base URL ของ API
