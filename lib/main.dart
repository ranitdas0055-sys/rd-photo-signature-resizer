import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:gal/gal.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';

const blue = Color(0xFF2188DF);
const testBanner = 'ca-app-pub-3940256099942544/6300978111';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const RDApp());
}

class RDApp extends StatelessWidget {
  const RDApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'RD Photo & Signature Resizer',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: blue), useMaterial3: true),
    home: const ResizerHome(),
  );
}

class ResizerHome extends StatefulWidget {
  const ResizerHome({super.key});
  @override
  State<ResizerHome> createState() => _ResizerHomeState();
}

class _ResizerHomeState extends State<ResizerHome> {
  final picker = ImagePicker();
  final widthController = TextEditingController(text: '600');
  final heightController = TextEditingController(text: '800');
  File? source;
  Uint8List? result;
  String filename = '';
  int originalBytes = 0;
  int targetKb = 100;
  bool keepRatio = true, bengali = false, busy = false;
  BannerAd? banner;
  bool bannerReady = false;

  String t(String en, String bn) => bengali ? bn : en;

  @override
  void initState() {
    super.initState();
    banner = BannerAd(
      adUnitId: testBanner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) { if (mounted) setState(() => bannerReady = true); },
        onAdFailedToLoad: (ad, error) { ad.dispose(); },
      ),
    )..load();
  }

  @override
  void dispose() {
    banner?.dispose();
    widthController.dispose();
    heightController.dispose();
    super.dispose();
  }

  void msg(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> pick(ImageSource sourceType) async {
    try {
      final file = await picker.pickImage(source: sourceType, imageQuality: 100);
      if (file == null) return;
      final f = File(file.path);
      setState(() { source = f; filename = p.basename(file.path); originalBytes = f.lengthSync(); result = null; });
    } catch (e) { msg('${t('Unable to open image', 'ছবি খোলা যায়নি')}: $e'); }
  }

  Future<void> crop() async {
    if (source == null) return;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: source!.path,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: t('Crop image', 'ছবি ক্রপ করুন'), toolbarColor: blue, toolbarWidgetColor: Colors.white),
          IOSUiSettings(title: 'Crop image'),
        ],
      );
      if (cropped != null) setState(() { source = File(cropped.path); filename = p.basename(cropped.path); originalBytes = source!.lengthSync(); result = null; });
    } catch (e) { msg('${t('Crop failed', 'ক্রপ করা যায়নি')}: $e'); }
  }

  Future<void> resize() async {
    if (source == null || busy) return;
    setState(() => busy = true);
    try {
      final decoded = img.decodeImage(await source!.readAsBytes());
      if (decoded == null) throw Exception('Unsupported image');
      final oriented = img.bakeOrientation(decoded);
      int w = int.tryParse(widthController.text) ?? 600;
      int h = int.tryParse(heightController.text) ?? 800;
      w = w.clamp(1, 6000); h = h.clamp(1, 6000);
      if (keepRatio) {
        final ratio = oriented.width / oriented.height;
        if (w / h > ratio) { w = (h * ratio).round(); } else { h = (w / ratio).round(); }
      }
      var working = img.copyResize(oriented, width: w, height: h, interpolation: img.Interpolation.average);
      var quality = 90;
      final limit = targetKb * 1024;
      Uint8List bytes = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      int attempts = 0;
      while (bytes.length > limit && attempts < 30) {
        attempts++;
        if (quality > 35) {
          quality -= 5;
        } else {
          quality = 75;
          final nw = (working.width * .9).round().clamp(1, 6000);
          final nh = (working.height * .9).round().clamp(1, 6000);
          if (nw == working.width && nh == working.height) break;
          working = img.copyResize(working, width: nw, height: nh);
        }
        bytes = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      }
      if (!mounted) return;
      setState(() => result = bytes);
      msg(bytes.length <= limit
        ? t('Done: ${(bytes.length / 1024).toStringAsFixed(1)} KB', 'সম্পন্ন: ${(bytes.length / 1024).toStringAsFixed(1)} KB')
        : t('Could not reach target; best result is ${(bytes.length / 1024).toStringAsFixed(1)} KB.', 'লক্ষ্য সাইজ পাওয়া যায়নি; সবচেয়ে কম সাইজ ${(bytes.length / 1024).toStringAsFixed(1)} KB।'));
    } catch (e) { msg('${t('Resize failed', 'রিসাইজ করা যায়নি')}: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<File> outputFile() async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, 'RD_Resized_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await f.writeAsBytes(result!);
    return f;
  }

  Future<void> save() async {
    if (result == null) return;
    try { await Gal.putImage((await outputFile()).path); msg(t('Saved to Gallery', 'গ্যালারিতে সেভ হয়েছে')); }
    catch (e) { msg('${t('Save failed', 'সেভ করা যায়নি')}: $e'); }
  }

  Future<void> share() async {
    if (result == null) return;
    await Share.shareXFiles([XFile((await outputFile()).path)], text: 'Made with RD Photo & Signature Resizer');
  }

  Widget action(IconData icon, String label, Color color, VoidCallback onTap) => Card(
    child: ListTile(
      leading: CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Icon(icon)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: blue, foregroundColor: Colors.white,
      title: Text(t('RD Photo Resizer', 'RD ফটো রিসাইজার')),
      actions: [TextButton(onPressed: () => setState(() => bengali = !bengali), child: Text(bengali ? 'EN' : 'বাংলা', style: const TextStyle(color: Colors.white)))],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.photo_size_select_large, color: Colors.white, size: 42),
            const SizedBox(height: 8),
            const Text('RD Photo & Signature Resizer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(t('Resize photos and signatures offline', 'ইন্টারনেট ছাড়াই ছবি ও সিগনেচার রিসাইজ করুন'), style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 14),
        action(Icons.photo_library, t('Select Photo / Signature', 'ছবি / সিগনেচার নির্বাচন করুন'), Colors.green, () => pick(ImageSource.gallery)),
        action(Icons.camera_alt, t('Take a Photo', 'নতুন ছবি তুলুন'), Colors.deepOrange, () => pick(ImageSource.camera)),
        if (source != null) ...[
          Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(filename, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${(originalBytes / 1024).toStringAsFixed(1)} KB'),
              const SizedBox(height: 8),
              Image.file(source!, height: 220, width: double.infinity, fit: BoxFit.contain),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(onPressed: crop, icon: const Icon(Icons.crop), label: Text(t('Crop', 'ক্রপ'))),
                OutlinedButton.icon(onPressed: () async {
                  final decoded = img.decodeImage(await source!.readAsBytes());
                  if (decoded == null) return;
                  final rotated = img.copyRotate(decoded, angle: 90);
                  await source!.writeAsBytes(img.encodeJpg(rotated));
                  setState(() { originalBytes = source!.lengthSync(); result = null; });
                }, icon: const Icon(Icons.rotate_right), label: Text(t('Rotate', 'ঘোরান'))),
              ]),
            ]),
          )),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Target file size: $targetKb KB', 'লক্ষ্য ফাইল সাইজ: $targetKb KB')),
              Slider(min: 20, max: 2048, divisions: 99, value: targetKb.toDouble(), onChanged: (v) => setState(() => targetKb = v.round())),
              Wrap(spacing: 6, children: [20, 50, 100, 200, 500, 1024, 2048].map((v) => ChoiceChip(
                label: Text(v >= 1024 ? '${v ~/ 1024} MB' : '$v KB'),
                selected: targetKb == v,
                onSelected: (_) => setState(() => targetKb = v),
              )).toList()),
              const Divider(height: 24),
              Text(t('Dimensions (pixels)', 'ছবির মাপ (পিক্সেল)')),
              Row(children: [
                Expanded(child: TextField(controller: widthController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Width'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: heightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height'))),
              ]),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('Keep aspect ratio', 'ছবির অনুপাত ঠিক রাখুন')), value: keepRatio, onChanged: (v) => setState(() => keepRatio = v)),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: busy ? null : resize,
                icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_size_select_large),
                label: Text(busy ? t('Processing...', 'কাজ চলছে...') : t('Resize Image', 'ছবি রিসাইজ করুন')),
              )),
            ]),
          )),
        ],
        if (result != null) Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Resized output', 'রিসাইজ করা ছবি'), style: Theme.of(context).textTheme.titleLarge),
            Image.memory(result!, height: 220, fit: BoxFit.contain, width: double.infinity),
            Text('${(result!.length / 1024).toStringAsFixed(1)} KB • JPG'),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.download), label: Text(t('Save', 'সেভ')))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: share, icon: const Icon(Icons.share), label: Text(t('Share', 'শেয়ার')))),
            ]),
          ]),
        )),
        const SizedBox(height: 16),
        Center(child: TextButton.icon(
          onPressed: () => Share.share('Govt Job with RD - https://youtube.com/@govtjobwithrd'),
          icon: const Icon(Icons.play_circle_fill, color: Colors.red),
          label: const Text('YouTube: Govt Job with RD'),
        )),
        Text(t('Always check the official notice for required photo and signature specifications.', 'ছবি ও সিগনেচারের সঠিক মাপের জন্য অফিসিয়াল বিজ্ঞপ্তি দেখুন।'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    ),
    bottomNavigationBar: bannerReady && banner != null
      ? SizedBox(height: banner!.size.height.toDouble(), child: AdWidget(ad: banner!))
      : null,
  );
}
