# ضبط صلاحية الأدمن في Firestore (حل خطأ permission-denied)

عندما تضغطين "تشغيل إعداد قاعدة البيانات" وتظهر رسالة **permission-denied**، معناها أن حسابك مسجّل دخول لكن Firestore لا يعتبرك أدمن. يمكنك استخدام أحد الطريقتين:

---

## الطريقة 1: من Firebase Console (الأبسط — بدون سكربت)

1. في التطبيق، من **Admin Panel** → **Overview** انسخي **UID حسابك** (يظهر فوق زر إعداد قاعدة البيانات).
2. افتحي [Firebase Console](https://console.firebase.google.com) → مشروعك → **Firestore Database**.
3. اضغطي **Start collection** (أو أنشئي مجموعة جديدة).
4. **Collection ID:** اكتبي `admins` ثم **Next**.
5. **Document ID:** الصقي الـ **UID** اللي نسختيه (لا تتركي الحقل تلقائي).
6. يمكنك ترك الحقول فارغة أو إضافة حقل مثل `admin: true` (اختياري). اضغطي **Save**.
7. في التطبيق: **سجّلي خروج** ثم **سجّلي دخول** مرة ثانية، ثم اضغطي **تشغيل إعداد قاعدة البيانات**.

بهذا تصبحين أدمن بدون تشغيل أي سكربت.

**مهم:** إذا عدّلتِ ملف `firestore.rules` في المشروع، نفّذي من التيرمنال:  
`firebase deploy --only firestore:rules`  
حتى تُطبَّق القواعد الجديدة (بما فيها دعم مجموعة `admins`).

---

## الطريقة 2: باستخدام سكربت Node (Custom Claim)

### 1) تثبيت Node.js
تأكدي أن Node.js مثبت على جهازك. من التيرمنال:
```bash
node -v
```

### 2) تحميل مفتاح Service Account من Firebase
- افتحي [Firebase Console](https://console.firebase.google.com) → مشروعك.
- أيقونة الترس (Project Settings) → **Service accounts**.
- اضغطي **Generate new private key** ثم **Generate key**.
- سيُحمّل ملف JSON. انقليه داخل مجلد المشروع (مثلاً `scripts/` أو الجذر) ولا ترفعيه على Git.

### 3) معرفة الـ UID الخاص بحسابك
- في Firebase Console: **Authentication** → **Users**.
- دوري على المستخدم اللي بتسجلي دخول بيه (إيميلك).
- انسخي قيمة **User UID** (مثل: `fg5dfREO6odFYlXlVjB1LliJim82`).

### 4) تشغيل السكربت
من مجلد المشروع (الجذر `grad_ready`):

```bash
cd scripts
npm init -y
npm install firebase-admin
node set-admin-claim.js "مسار_ملف_الـ_JSON" "الـ_UID_اللي_نسختيه"
```

مثال إذا كان الملف اسمه `gradready-key.json` داخل `scripts` والـ UID هو `fg5dfREO6odFYlXlVjB1LliJim82`:

```bash
node set-admin-claim.js ./gradready-key.json fg5dfREO6odFYlXlVjB1LliJim82
```

إذا ظهرت رسالة **Admin claim set successfully** فتم الضبط.

### 5) في التطبيق
- **سجّلي خروج** من التطبيق ثم **سجّلي دخول** مرة ثانية بنفس الحساب.
- بعدها اضغطي مرة تانية على **"تشغيل إعداد قاعدة البيانات"** — المفروض تشتغل بدون permission-denied.

---

## ملاحظة أمان
- ملف الـ Service Account سري؛ لا ترفعيه على Git ولا تشاركيه.
- أضيفي في `.gitignore` سطراً مثل: `*-service-account*.json` أو اسم ملف المفتاح.
