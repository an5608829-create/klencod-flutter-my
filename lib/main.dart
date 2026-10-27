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
      title: 'My WE Studio Pro',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00FF88),
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
  bool _obscurePassword = true;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Map<String, String> _analyzeNationalId(String nid, {int? apiBirthdayTimestamp}) {
    String birthdayStr = "-";
    String ageStr = "-";
    String genderStr = "غير معروف";
    String govStr = "غير معروف";

    if (apiBirthdayTimestamp != null && apiBirthdayTimestamp > 0) {
      try {
        DateTime bDate = DateTime.fromMillisecondsSinceEpoch(apiBirthdayTimestamp);
        birthdayStr = "${bDate.year}-${bDate.month.toString().padLeft(2, '0')}-${bDate.day.toString().padLeft(2, '0')}";
        int age = _calculateAge(bDate);
        ageStr = "$age سنة";
      } catch (_) {}
    }

    if (nid.isNotEmpty && nid.length == 14) {
      try {
        String centuryCode = nid[0];
        int year2 = int.parse(nid.substring(1, 3));
        int month = int.parse(nid.substring(3, 5));
        int day = int.parse(nid.substring(5, 7));
        String govCode = nid.substring(7, 9);
        int genderDigit = int.parse(nid[12]);

        int year = (centuryCode == "2" ? 1900 : centuryCode == "3" ? 2000 : 1800) + year2;
        
        if (birthdayStr == "-") {
          DateTime birthDate = DateTime(year, month, day);
          birthdayStr = "$year-$month-$day";
          int age = _calculateAge(birthDate);
          ageStr = "$age سنة";
        }

        genderStr = genderDigit % 2 == 1 ? "ذكر" : "أنثى";

        Map<String, String> governorates = {
          "01": "القاهرة", "02": "الإسكندرية", "03": "بورسعيد", "04": "السويس", "11": "دمياط",
          "12": "الدقهلية", "13": "الشرقية", "14": "القليوبية", "15": "كفر الشيخ", "16": "الغربية",
          "17": "المنوفية", "18": "البحيرة", "19": "الإسماعيلية", "21": "الجيزة", "22": "بني سويف",
          "23": "الفيوم", "24": "المنيا", "25": "أسيوط", "26": "سوهاج", "27": "قنا", "28": "أسوان",
          "29": "الأقصر", "31": "البحر الأحمر", "32": "الوادي الجديد", "33": "مطروح",
          "34": "شمال سيناء", "35": "جنوب سيناء", "88": "خارج الجمهورية"
        };
        govStr = governorates[govCode] ?? "غير معروف";
      } catch (_) {}
    }

    return {
      "birthday": birthdayStr,
      "governorate": govStr,
      "gender": genderStr,
      "age": ageStr,
    };
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
        throw "❌ $errorMsg";
      }

      final body = result["body"] ?? {};
      final customer = body["customer"] ?? {};
      final account = body["account"] ?? {};
      final subscriber = body["subscriber"] ?? {};
      final individual = customer["individualInfo"] ?? {};
      final uToken = body["utoken"] ?? "";
      final loginToken = body["token"] ?? "";
      final refreshToken = body["refresh_token"] ?? "";

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

      String fullNationalId = "";
      try {
        final nidRes = await client.post(
          Uri.parse("$BASE/cz/v1/customer/validateNationalIDType"),
          headers: commonHeaders,
          body: jsonEncode({"nationalId": ""}),
        );
        fullNationalId = jsonDecode(nidRes.body)["body"]?["nationalId"] ?? "";
      } catch (_) {}

      int? apiBirthday = individual["birthday"];
      String genderDisplay = individual["gender"] == "1" ? "ذكر" : "أنثى";

      setState(() {
        _profileData = {
          "custName": customer["custName"] ?? "غير معروف",
          "gender": genderDisplay,
          "custType": customer["custType"] == "1" ? "فردي" : "شركة",
          "servNumber": subscriber["servNumber"] ?? phone,
          "state": subscriber["state"] == "2" ? "✅ نشط" : "⏸️ موقوف",
          "paymentType": subscriber["paymentType"] == "1" ? "فاتورة" : "مدفوع مسبقاً",
          "acctId": account["acctId"] ?? "-",
          "nationalId": fullNationalId.isNotEmpty ? fullNationalId : "غير متوفر",
          "nidAnalysis": _analyzeNationalId(fullNationalId, apiBirthdayTimestamp: apiBirthday),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF070B14), Color(0xFF020617)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Color(0xFF00FF88), size: 26),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'My WE Studio Pro',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تسجيل الدخول للخدمة',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أدخل بيانات خط WE الخاص بك للمتابعة',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 18),

                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'رقم الخط (WE / اتصالات)',
                          labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF00FF88)),
                          filled: true,
                          fillColor: const Color(0xFF030712),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF00FF88)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: Color(0xFF00FF88),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFF030712),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF00FF88)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00FF88).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginAndFetchData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'اتصال وجلب البيانات',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
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
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
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
                const SizedBox(height: 20),

                if (_profileData != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF88).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.verified_rounded, color: Color(0xFF00FF88), size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'بيانات العميل المستخرجة',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Divider(color: Color(0xFF1F2937), height: 1),
                        ),
                        _buildInfoRow('اسم العميل', _profileData!['custName']),
                        _buildInfoRow('رقم الخط', _profileData!['servNumber']),
                        _buildInfoRow('نوع الدفع', _profileData!['paymentType']),
                        _buildInfoRow('حالة الخط', _profileData!['state']),
                        _buildInfoRow('الرقم القومي', _profileData!['nationalId']),
                        
                        if (_profileData!['nidAnalysis'] != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(color: Color(0xFF1F2937), height: 1),
                          ),
                          _buildInfoRow('تاريخ الميلاد', _profileData!['nidAnalysis']['birthday'] ?? '-'),
                          _buildInfoRow('المحافظة', _profileData!['nidAnalysis']['governorate'] ?? '-'),
                          _buildInfoRow('الجنس', _profileData!['nidAnalysis']['gender'] ?? '-'),
                          _buildInfoRow('السن', _profileData!['nidAnalysis']['age'] ?? '-'),
                        ],
                      ],
                    ),
                  ),
                ]
              ],
            ),
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
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
