# GradReady

تطبيق Flutter لمساعدة الخريجين على تحليل الفجوة بين مهاراتهم ومتطلبات الوظائف.

## إعداد حساب الأدمن

لتسجيل دخول لوحة الأدمن:

1. في Firebase Console → Authentication أنشئ مستخدماً بالإيميل `admin@gradready.com` (أو `admin@gradready`) وكلمة المرور `1111`.
2. عند أول تسجيل دخول بهذا الحساب سيتم إنشاء مستند في Firestore تلقائياً بحقل `role: 'admin'` وتوجيهك للوحة الأدمن.

### تفعيل صلاحيات الأدمن في Firestore (مهم)

قواعد Firestore تسمح بالكتابة على `jobs` و `skills` فقط إذا كان للمستخدم **custom claim** باسم `admin` وقيمته `true`. إنشاء المستند في Firestore بحقل `role: 'admin'` يفعّل واجهة الأدمن في التطبيق فقط، ولا يمنح صلاحيات الكتابة إلا بعد ضبط الـ claim.

**طريقة واحدة لضبط الـ claim (Node.js مع Firebase Admin SDK):**

1. إنشاء مشروع Node.js مؤقت وتثبيت الحزم:
   ```bash
   npm init -y
   npm install firebase-admin
   ```
2. تحميل **Service Account Key** من Firebase Console → Project Settings → Service accounts → Generate new private key.
3. تشغيل السكربت التالي (استبدل `PATH_TO_JSON` بمسار ملف الـ JSON، و`ADMIN_UID` بـ UID المستخدم من Authentication):
   ```js
   const admin = require('firebase-admin');
   const serviceAccount = require('PATH_TO_JSON');
   admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
   admin.auth().setCustomUserClaims('ADMIN_UID', { admin: true }).then(() => {
     console.log('Admin claim set successfully');
   });
   ```
4. بعد تنفيذ السكربت مرة واحدة، تسجيل الخروج ثم الدخول مرة أخرى بنفس حساب الأدمن حتى يقرأ التطبيق الـ token الجديد.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
