import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My WE Studio',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.dark,
        ),
      ),
      home: const WEAuthScreen(),
    );
  }
}

class WEAuthScreen extends StatefulWidget {
  const WEAuthScreen({super.key});

  @override
  State<WEAuthScreen> createState() => _WEAuthScreenState();
}

class _WEAuthScreenState extends State<WEAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;

  Map<String, String> _analyzeNationalId(String nid) {
    if (nid.length != 14) return {};
    try {
      String centuryCode = nid[0];
      int year2 = int.parse(nid.substring(1, 3));
      int month = int.parse(nid.substring(3, 5));
      int day = int.parse(nid.substring(5, 7));
      String govCode = nid.substring(7, 9);
      int genderDigit = int.parse(nid[12]);

      int year = (centuryCode == "2" ? 1900 : centuryCode == "3" ? 2000 : 1800) + year2;

      Map<String, String> governorates = {
        "01": "القاهرة", "02": "الإسكندرية", "03": "بورسعيد", "04": "السويس", "11": "دمياط",
        "12": "الدقهلية", "13": "الشرقية", "14": "القليوبية", "15": "كفر الشيخ", "16": "الغربية",
        "17": "المنوفية", "18": "البحيرة", "19": "الإسماعيلية", "21": "الجيزة", "22": "بني سويف",
        "23": "الفيوم", "24": "المنيا", "25": "أسيوط", "26": "سوهاج", "27": "قنا", "28": "أسوان",
        "29": "الأقصر", "31": "البحر الأحمر", "32": "الوادي الجديد", "33": "مطروح",
        "34": "شمال سيناء", "35": "جنوب سيناء", "88": "خارج الجمهورية"
      };

      return {
        "birthday": "$year-$month-$day",
        "governorate": governorates[govCode] ?? "غير معروف",
        "gender": genderDigit % 2 == 1 ? "ذكر" : "أنثى",
      };
    } catch (_) {
      return {};
    }
  }

  String _randomHex(int length) {
    final random = Random();
    const chars = 'abcdef0123456789';
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _loginAndFetchData() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "⚠️ يرجى إدخال رقم الخط وكلمة المرور بدقة");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _profileData = null;
    });

    try {
      final client = http.Client();
      
      // 1. طلب الكابتشا بنفس طريقة السكريبت الناجحة
      final captchaRes = await client.post(
        Uri.parse("https://captcha.te.eg/api/Captcha/GenerateCaptcha"),
        headers: {
          "User-Agent": "okhttp/5.0.0-alpha.2",
          "Accept": "application/json, text/plain, */*",
          "Content-Type": "application/json; charset=utf-8",
        },
        body: jsonEncode({"merchantName": "E-Care", "serviceName": "Login", "identifier": phone}),
      );

      final captchaData = jsonDecode(captchaRes.body);
      final imgCacheKey = captchaData["token"] ?? "";

      if (imgCacheKey.isEmpty) {
        throw "❌ فشل إنشاء رمز التحقق (الكابتشا) من السيرفر.";
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final deviceId = _randomHex(16);
      
      // 2. إرسال طلب تسجيل الدخول بالهيدرات الكاملة تماماً مثل السكريبت
      final authRes = await client.post(
        Uri.parse("https://app-my.te.eg/echannel/service/besapp/base/rest/busiservice/v1/auth/userAuthenticate"),
        headers: {
          "User-Agent": "okhttp/5.0.0-alpha.2",
          "Connection": "Keep-Alive",
          "Accept": "application/json, text/plain, */*",
          "Accept-Encoding": "gzip",
          "Content-Type": "application/json",
          "csrftoken": "",
          "languagecode": "ar-EG",
          "ismobile": "true",
          "iscoporate": "false",
          "isselfcare": "true",
          "channelid": "704",
          "delegatorsubsid": "",
          "systemtype": "android",
          "deviceid": deviceId,
          "appversionno": "122",
          "clienttype": "google",
          "x-client-time": now.toString(),
          "x-init-time": (now - 2000).toString(),
          "whitereqheadersign": _randomHex(32),
          "whitereqbodysign": _randomHex(32),
          "reqheadersign": _randomHex(32),
          "reqbodysign": _randomHex(32),
        },
        body: jsonEncode({
          "acctId": phone.replaceFirst(RegExp(r'^0'), ''),
          "password": password,
          "appLocale": "ar-EG",
          "isSelfcare": "Y",
          "isMobile": "Y",
          "imgCacheKey": imgCacheKey,
          "isConvergent": "0"
        }),
      );

      final result = jsonDecode(authRes.body);
      final header = result["header"] ?? {};
      
      if (header["retCode"] != "0") {
        String errorMsg = header["errorMsg"] ?? "فشل تسجيل الدخول";
        throw "❌ خطأ من السيرفر: $errorMsg";
      }

      final body = result["body"] ?? {};
      final customer = body["customer"] ?? {};
      final account = body["account"] ?? {};
      final subscriber = body["subscriber"] ?? {};
      final individual = customer["individualInfo"] ?? {};
      final uToken = body["utoken"] ?? "";
      final loginToken = body["token"] ?? "";
      final refreshToken = body["refresh_token"] ?? "";
      final custId = customer["custId"] ?? "";

      final Map<String, String> commonHeaders = {
        "User-Agent": "okhttp/5.0.0-alpha.2",
        "Connection": "Keep-Alive",
        "Accept": "application/json, text/plain, */*",
        "Accept-Encoding": "gzip",
        "Content-Type": "application/json",
        "csrftoken": loginToken.isNotEmpty ? loginToken : _randomHex(32).toUpperCase(),
        "languagecode": "ar-EG",
        "ismobile": "true",
        "iscoporate": "false",
        "isselfcare": "true",
        "channelid": "704",
        "delegatorsubsid": "",
        "systemtype": "android",
        "indiv_login_token": uToken,
        "refresh_token": refreshToken,
        "mrefresh_token": refreshToken,
        "deviceid": deviceId,
        "appversionno": "123",
        "clienttype": "google",
        "x-client-time": DateTime.now().millisecondsSinceEpoch.toString(),
        "x-init-time": (now - 2000).toString(),
        "whitereqheadersign": _randomHex(32),
        "whitereqbodysign": _randomHex(32),
        "reqheadersign": _randomHex(32),
        "reqbodysign": _randomHex(32),
      };

      // تهيئة الـ Session بنفس المسارات الموجودة في السكريبت
      final BASE = "https://app-my.te.eg/echannel/service/besapp/base/rest/busiservice";
      for (var endpoint in [
        "$BASE/cz/v1/auth/validateAuthenticateForBio",
        "$BASE/cz/v1/user/getUserRoleCz",
        "$BASE/cz/v1/auth/queryPermissions",
      ]) {
        try {
          await client.post(Uri.parse(endpoint), headers: commonHeaders);
        } catch (_) {}
      }

      // 3. جلب الرقم القومي والبيانات بالتفصيل مثل السكريبت تماماً
      String fullNationalId = "";
      try {
        final nidRes = await client.post(
          Uri.parse("$BASE/cz/v1/customer/validateNationalIDType"),
          headers: commonHeaders,
          body: jsonEncode({"nationalId": ""}),
        );
        fullNationalId = jsonDecode(nidRes.body)["body"]?["nationalId"] ?? "";
      } catch (_) {}

      setState(() {
        _profileData = {
          "custName": customer["custName"] ?? "غير معروف",
          "gender": individual["gender"] == "1" ? "ذكر" : "أنثى",
          "custType": customer["custType"] == "1" ? "فردي" : "شركة",
          "servNumber": subscriber["servNumber"] ?? phone,
          "state": subscriber["state"] == "2" ? "✅ نشط" : "⏸️ موقوف",
          "paymentType": subscriber["paymentType"] == "1" ? "فاتورة" : "مدفوع مسبقاً",
          "acctId": account["acctId"] ?? "-",
          "nationalId": fullNationalId,
          "nidAnalysis": _analyzeNationalId(fullNationalId),
        };
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 8),
            Text('My WE Studio', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تسجيل الدخول للخدمة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'رقم الخط (WE / اتصالات)',
                        labelStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF10B981)),
                        filled: true,
                        fillColor: const Color(0xFF0B0F19),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        labelStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981)),
                        filled: true,
                        fillColor: const Color(0xFF0B0F19),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginAndFetchData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'اتصال وجلب البيانات',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_profileData != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(22.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 24),
                          SizedBox(width: 8),
                          Text('بيانات العميل المستخرجة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Color(0xFF1E293B)),
                      ),
                      _buildInfoRow('اسم العميل', _profileData!['custName']),
                      _buildInfoRow('رقم الخط', _profileData!['servNumber']),
                      _buildInfoRow('نوع الدفع', _profileData!['paymentType']),
                      _buildInfoRow('حالة الخط', _profileData!['state']),
                      _buildInfoRow('الرقم القومي', _profileData!['nationalId'].isEmpty ? 'غير متوفر' : _profileData!['nationalId']),
                      
                      if (_profileData!['nidAnalysis'].isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Color(0xFF1E293B)),
                        ),
                        _buildInfoRow('تاريخ الميلاد', _profileData!['nidAnalysis']['birthday']),
                        _buildInfoRow('المحافظة', _profileData!['nidAnalysis']['governorate']),
                        _buildInfoRow('الجنس', _profileData!['nidAnalysis']['gender']),
                      ],
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
