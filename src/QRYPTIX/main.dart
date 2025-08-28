import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QRYPTIX – Scan Smart, Stay Safe', // CAPS
      theme: ThemeData(
        fontFamily: 'Montserrat',
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, String> upiMap = {};
  String status = "";
  String? verifiedUpiUri;

  @override
  void initState() {
    super.initState();
    loadCsv();
  }

  Future<void> loadCsv() async {
    final rawData = await rootBundle.loadString("assets/verified_upi_list.csv");
    List<List<dynamic>> csvTable = const CsvToListConverter().convert(rawData);

    for (int i = 1; i < csvTable.length; i++) {
      String id = csvTable[i][0].toString().trim().toLowerCase();
      String name = csvTable[i][1].toString().trim().toLowerCase();
      upiMap[id] = name;
    }

    setState(() {
      status = "";
    });
  }

  void verifyQr(String qrText) {
    verifiedUpiUri = null;

    if (qrText.isEmpty) {
      setState(() => status = "No QR found");
      return;
    }
    if (!qrText.contains("upi://pay")) {
      setState(() => status = "Not a UPI QR");
      return;
    }

    String pa = extractParam(qrText, "pa").toLowerCase();
    String pn = extractParam(qrText, "pn").toLowerCase();

    if (pa.isEmpty) {
      setState(() => status = "Invalid UPI QR (no pa)");
      return;
    }

    if (!upiMap.containsKey(pa)) {
      setState(() => status = "⚠️ Not Verified User");
      Future.delayed(const Duration(milliseconds: 300), () {
        askProceedPayment(pa, pn);
      });
      return;
    }

    String expectedName = upiMap[pa] ?? "";

    if (pn.isEmpty) {
      setState(() => status = "✅ Verified: $expectedName (Name missing in QR)");
    } else if (pn != expectedName) {
      setState(() =>
          status = "⚠️ Name Mismatch! Expected: $expectedName, Found: $pn");
      Future.delayed(const Duration(milliseconds: 300), () {
        askProceedPayment(pa, pn);
      });
      return;
    } else {
      setState(() => status = "✅ Verified: $pn");
    }

    verifiedUpiUri =
        "upi://pay?pa=$pa&pn=${Uri.encodeComponent(pn.isNotEmpty ? pn : expectedName)}&tn=Verified%20user&cu=INR";
  }

  String extractParam(String text, String key) {
    if (!text.contains("?")) return "";
    String query = text.split("?").last;
    List<String> parts = query.split("&");
    for (var p in parts) {
      if (p.startsWith("$key=")) {
        return Uri.decodeComponent(p.split("=").last);
      }
    }
    return "";
  }

  Future<void> launchUPI(String uri) async {
    final upiUri = Uri.parse(uri);
    if (!await launchUrl(
      upiUri,
      mode: LaunchMode.externalApplication,
    )) {
      setState(() => status = "No UPI app found");
    }
  }

  void askProceedPayment(String pa, String pn) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text(
                "Not Verified User",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "This UPI ID is not verified. Do you still want to proceed with the payment?",
                style: TextStyle(fontSize: 15, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        String upiUri =
                            "upi://pay?pa=$pa&pn=${Uri.encodeComponent(pn.isNotEmpty ? pn : "Unknown")}&tn=Unverified%20user&cu=INR";
                        launchUPI(upiUri);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Proceed Anyway"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void startScan(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QRViewExample(onScan: verifyQr)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0f2027), Color(0xFF2c5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.cyanAccent, Colors.blueAccent],
                  ).createShader(bounds),
                  child: const Text(
                    "QRYPTIX", // CAPS
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Scan Smart, Stay Safe", // slogan
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                if (status.isNotEmpty)
                  Card(
                    elevation: 8,
                    color: Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
                if (verifiedUpiUri != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.verified, color: Colors.white),
                      label: const Text("Proceed to Pay"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        launchUPI(verifiedUpiUri!);
                      },
                    ),
                  ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: const Text("Scan QR to Verify UPI"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.tealAccent.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => startScan(context),
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

class QRViewExample extends StatefulWidget {
  final Function(String) onScan;
  const QRViewExample({super.key, required this.onScan});

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Container(
              height: 320,
              width: 320,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyanAccent, width: 3),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.blueAccent,
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    if (isScanned) return;
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      final String? code = barcode.rawValue;
                      if (code != null) {
                        isScanned = true;
                        controller.stop();
                        widget.onScan(code);
                        Navigator.pop(context);
                        break;
                      }
                    }
                  },
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
