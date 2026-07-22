# 🥥 Coconut Acoustic (Coconut Maturity Detection System)

> โครงการระบบตรวจสอบระดับความสุกแก่ของมะพร้าวน้ำหอมไทยด้วยการวิเคราะห์สัญญาณเสียง

ระบบนี้ถูกพัฒนาขึ้นเพื่อช่วยให้เกษตรกรและผู้บริโภคสามารถตรวจสอบระดับความสุกแก่ของมะพร้าวน้ำหอมไทย (**อ่อน, สุกพอดี, แก่**) ได้อย่างแม่นยำผ่านการเคาะและบันทึกเสียงด้วยสมาร์ตโฟน โดยใช้เทคโนโลยี **Flutter**, **Native Android (Kotlin)** และ **TensorFlow Lite** สำหรับการประมวลผลปัญญาประดิษฐ์ (AI)

---

# 📂 โครงสร้างสถาปัตยกรรมระบบ (Architecture)

โปรเจกต์แบ่งออกเป็น **2 ส่วนหลัก** ดังนี้

## 1. Frontend (Flutter / Dart)

ทำหน้าที่

- จัดการส่วนติดต่อผู้ใช้งาน (UI)
- บันทึกเสียงเป็นไฟล์ `.wav`
- จัดการ Service ภายในแอป
- ติดต่อสื่อสารกับ Native Android ผ่าน `MethodChannel`

---

## 2. Backend / AI Inference (Native Android / Kotlin)

ทำหน้าที่

- ประมวลผลสัญญาณเสียง
- กรองสัญญาณด้วย **Bandpass Filter**
- แปลงข้อมูลเป็น **Mel-Spectrogram** ด้วย `JLibrosa`
- รันโมเดล AI ด้วย **TensorFlow Lite**
- ติดต่อกับ Flutter ผ่าน `MethodChannel`

---

# ⚙️ Installation Guide

## 1. Prerequisites

ติดตั้งเครื่องมือดังต่อไปนี้

- Flutter SDK
- Android Studio
- Android SDK
- JDK 17 หรือใหม่กว่า

---

## 2. Clone Project

```bash
git clone <repository-url>
cd coconut_maturity_app
```

---

## 3. ติดตั้ง Dependencies

```bash
flutter pub get
```

---

## 4. เตรียมไฟล์โมเดล

นำไฟล์

```text
coconut_maturity_model.tflite
```

ไปไว้ที่

```text
assets/models/
```

โครงสร้างโฟลเดอร์

```text
coconut_maturity_app
└── assets
    └── models
        └── coconut_maturity_model.tflite
```

---

## 5. ตรวจสอบ Library

ตรวจสอบว่ามีไฟล์ต่อไปนี้ภายใน

```text
android/app/libs/
```

ได้แก่

```text
jlibrosa-1.1.8.jar
commons-math3-3.6.1.jar
```

ใช้สำหรับการประมวลผลเสียงแบบออฟไลน์

---

## 6. Run Application

```bash
flutter clean
flutter pub get
flutter run
```

---

# 🛠️ Functions & Workflow

## Flutter Frontend

ไฟล์หลัก

```text
lib/services/TFLiteService.dart
```

### `loadModel()`

หน้าที่

- ส่งคำสั่งไปยัง Native Android
- โหลดโมเดล TensorFlow Lite
- เตรียม Interpreter ก่อนเริ่มใช้งาน

---

### `predictMaturity(List<String> audioPaths)`

หน้าที่

- รับไฟล์เสียง `.wav` จำนวน 3 ครั้ง
- ส่งไฟล์แต่ละไฟล์ไปยัง Native
- รับค่าความน่าจะเป็น (Probability)
- รวมคะแนนทั้งหมด
- คำนวณค่าเฉลี่ย
- Normalize ด้วย Softmax / Sum Normalization
- ส่งกลับผลลัพธ์พร้อมระดับความสุกแก่

---

### `_processWavToFlatList(String filePath)`

หน้าที่

- อ่านไฟล์ `.wav`
- ข้ามส่วน Header
- ดึงข้อมูล Raw Audio Samples
- แปลงเป็น List เพื่อนำส่งไปยัง Native

---

# Native Android Backend

ไฟล์หลัก

```text
android/app/src/main/kotlin/.../MainActivity.kt
```

---

## `configureFlutterEngine()`

หน้าที่

สร้างช่องทางสื่อสาร

```text
com.example.coconut_maturity_app/tflite
```

รองรับคำสั่ง

- `loadModel`
- `predict`

---

## TensorFlow Lite Interpreter

หน้าที่

- โหลดไฟล์ `.tflite`
- Map Model เข้าหน่วยความจำ
- เปิดใช้งาน Interpreter
- ติดตั้ง FlexDelegate สำหรับรองรับ TensorFlow Operators

---

## `processWavToMelSpectrogram(String filePath)`

### 1. Bandpass Filter

กรองช่วงความถี่

```text
20 Hz – 4000 Hz
```

เพื่อลดเสียงรบกวนจากสภาพแวดล้อม

---

### 2. Tap Detection

ใช้ฟังก์ชัน

```text
findTapStartIndex()
```

ค้นหาตำแหน่งเริ่มต้นของเสียงเคาะมะพร้าว

---

### 3. Feature Extraction

ใช้ไลบรารี

```text
JLibrosa
```

สร้าง

- Mel Spectrogram

จากสัญญาณเสียง

---

### 4. dB Conversion

แปลงค่าพลังงานเป็น

```text
Power → dB
```

โดยอ้างอิงจากค่าพลังงานสูงสุด

---

### 5. Normalization

Normalize ค่าให้อยู่ในช่วง

```text
0.0 - 1.0
```

ให้ตรงกับข้อมูลที่ใช้ฝึกโมเดลใน Python

---

### 6. TensorFlow Lite Inference

นำข้อมูลที่ผ่านการ Normalize แล้ว

- แปลงเป็น `ByteBuffer`
- ส่งเข้า TensorFlow Lite
- รับผลลัพธ์การทำนาย

---

# 🔄 Processing Pipeline

```text
เคาะมะพร้าว
      │
      ▼
บันทึกเสียง (.wav)
      │
      ▼
Flutter
      │
      ▼
MethodChannel
      │
      ▼
Native Android
      │
      ▼
Bandpass Filter
      │
      ▼
Tap Detection
      │
      ▼
Mel Spectrogram
      │
      ▼
Normalization
      │
      ▼
TensorFlow Lite
      │
      ▼
Prediction
      │
      ▼
Flutter UI
```

---

# 📊 Prediction Output

ระบบสามารถจำแนกระดับความสุกแก่ของมะพร้าวออกเป็น **3 คลาส**

| Class | Label |
|--------|-------|
| 🟢 | Premature (อ่อน) |
| 🟡 | Mature (สุกพอดี) |
| 🟤 | Overmature (แก่) |

---

# 🧰 Technology Stack

| Component | Technology |
|-----------|------------|
| Mobile Framework | Flutter |
| Language | Dart |
| Native Android | Kotlin |
| AI Runtime | TensorFlow Lite |
| Audio Processing | JLibrosa |
| DSP | Bandpass Filter |
| Communication | MethodChannel |
| Audio Format | WAV |
| Feature Extraction | Mel-Spectrogram |

---

# 📁 Project Structure

```text
coconut_maturity_app
│
├── android/
│   ├── app/
│   │   ├── libs/
│   │   │   ├── commons-math3-3.6.1.jar
│   │   │   └── jlibrosa-1.1.8.jar
│   │   └── src/
│   │       └── main/
│   │           └── kotlin/
│   │               └── MainActivity.kt
│
├── assets/
│   └── models/
│       └── coconut_maturity_model.tflite
│
├── lib/
│   ├── services/
│   │   └── TFLiteService.dart
│   └── ...
│
└── pubspec.yaml
```