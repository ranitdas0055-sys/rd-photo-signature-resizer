import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color brandBlue = Color(0xFF1769AA);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RDResizerApp());
}

class RDResizerApp extends StatelessWidget {
  const RDResizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RD Custom Photo Resizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brandBlue),
        scaffoldBackgroundColor: const Color(0xFFF5F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: const ResizerHomePage(),
    );
  }
}

class ResizerHomePage extends StatefulWidget {
  const ResizerHomePage({super.key});

  @override
  State<ResizerHomePage> createState() => _ResizerHomePageState();
}

class _ResizerHomePageState extends State<ResizerHomePage> {
  final _picker = ImagePicker();
  final _width = TextEditingController(text: '600');
  final _height = TextEditingController(text: '800');

  File? _source;
  Uint8List? _output;
  String _fileName = '';
  int _sourceBytes = 0;
  int _targetKb = 100;
  bool _keepRatio = true;
  bool _bengali = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _width.text = '${prefs.getInt('defaultWidth') ?? 600}';
        _height.text = '${prefs.getInt('defaultHeight') ?? 800}';
        _targetKb = (prefs.getInt('targetKb') ?? 100).clamp(10, 2048);
        _keepRatio = prefs.getBool('keepRatio') ?? true;
        _bengali = prefs.getBool('bengali') ?? false;
      });
    } catch (_) {
    }
  }

  String tr(String en, String bn) => _bengali ? bn : en;

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );
      if (picked == null) return;
      final file = File(picked.path);
      if (!await file.exists()) {
        _message(tr('Selected file was not found.', 'নির্বাচিত ফাইল পাওয়া যায়নি।'));
        return;
      }
      setState(() {
        _source = file;
        _fileName = path.basename(file.path);
        _sourceBytes = file.lengthSync();
        _output = null;
      });
    } catch (e) {
      _message('${tr('Could not open image', 'ছবি খোলা যায়নি')}: $e');
    }
  }

  Future<void> _crop() async {
    final file = _source;
    if (file == null) return;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: tr('Crop photo', 'ছবি ক্রপ করুন'),
            toolbarColor: brandBlue,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: brandBlue,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop photo'),
        ],
      );
      if (cropped == null) return;
      final newFile = File(cropped.path);
      setState(() {
        _source = newFile;
        _fileName = path.basename(newFile.path);
        _sourceBytes = newFile.lengthSync();
        _output = null;
      });
    } catch (e) {
      _message('${tr('Crop failed', 'ক্রপ করা যায়নি')}: $e');
    }
  }

  Future<void> _rotate() async {
    final file = _source;
    if (file == null || _busy) return;
    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) throw Exception('Unsupported image format');
      final rotated = img.copyRotate(img.bakeOrientation(decoded), angle: 90);
      final bytes = img.encodeJpg(rotated, quality: 95);
      final dir = await getTemporaryDirectory();
      final rotatedFile = File(path.join(
        dir.path,
        'RD_rotated_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      await rotatedFile.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _source = rotatedFile;
        _fileName = path.basename(rotatedFile.path);
        _sourceBytes = bytes.length;
        _output = null;
      });
    } catch (e) {
      _message('${tr('Rotate failed', 'ঘোরানো যায়নি')}: $e');
    }
  }


  Future<void> _openSettings() async {
    final widthController = TextEditingController(text: _width.text);
    final heightController = TextEditingController(text: _height.text);
    final sizeController = TextEditingController(text: '$_targetKb');
    var keepRatio = _keepRatio;
    var bengali = _bengali;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('Settings', 'সেটিংস')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: widthController, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Default Width (px)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: heightController, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Default Height (px)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: sizeController, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target size (KB)', helperText: '10–2048 KB (up to 2 MB)', border: OutlineInputBorder())),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('Keep aspect ratio', 'ছবির অনুপাত ঠিক রাখুন')),
                value: keepRatio, onChanged: (v) => setDialogState(() => keepRatio = v)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('বাংলা ভাষা / Bengali'),
                value: bengali, onChanged: (v) => setDialogState(() => bengali = v)),
              const Divider(),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.offline_bolt),
                title: Text(tr('Offline processing', 'অফলাইনে ছবি প্রসেস হয়')),
                subtitle: Text(tr('Core photo tools work without internet.', 'মূল ছবি সম্পাদনার কাজ ইন্টারনেট ছাড়াই চলে।'))),
              const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.info_outline),
                title: Text('RD Photo & Signature Resizer'), subtitle: Text('Version 1.0.8')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('Cancel', 'বাতিল'))),
            FilledButton(onPressed: () async {
              final w = int.tryParse(widthController.text.trim());
              final h = int.tryParse(heightController.text.trim());
              final kb = int.tryParse(sizeController.text.trim());
              if (w == null || h == null || kb == null || w < 1 || h < 1 || w > 6000 || h > 6000 || kb < 10 || kb > 2048) {
                _message('Enter valid dimensions (1–6000 px) and size (10–2048 KB).');
                return;
              }
              setState(() {
                _width.text = '$w'; _height.text = '$h'; _targetKb = kb;
                _keepRatio = keepRatio; _bengali = bengali; _output = null;
              });
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('defaultWidth', w);
                await prefs.setInt('defaultHeight', h);
                await prefs.setInt('targetKb', kb);
                await prefs.setBool('keepRatio', keepRatio);
                await prefs.setBool('bengali', bengali);
              } catch (_) {
                _message(tr('Settings applied for this session.', 'এই সেশনের জন্য সেটিংস প্রয়োগ হয়েছে।'));
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }, child: Text(tr('Save Settings', 'সেটিংস সেভ করুন'))),
          ],
        ),
      ),
    );
    widthController.dispose(); heightController.dispose(); sizeController.dispose();
  }

  Future<void> _openCustomResizeDialog() async {
    final widthController = TextEditingController(text: _width.text);
    final heightController = TextEditingController(text: _height.text);
    final sizeController = TextEditingController(text: '$_targetKb');
    var keepRatio = _keepRatio;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('Custom Resize', 'কাস্টম রিসাইজ')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: widthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Width (px)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (px)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sizeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('Target size (KB)', 'লক্ষ্য সাইজ (KB)'),
                    helperText: tr('10 to 2048 KB (up to 2 MB)', '১০ থেকে ২০৪৮ KB (সর্বোচ্চ ২ MB)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: keepRatio,
                  title: Text(tr('Keep aspect ratio', 'ছবির অনুপাত ঠিক রাখুন')),
                  onChanged: (value) => setDialogState(() => keepRatio = value ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('Cancel', 'বাতিল')),
            ),
            FilledButton(
              onPressed: () {
                final w = int.tryParse(widthController.text.trim());
                final h = int.tryParse(heightController.text.trim());
                final kb = int.tryParse(sizeController.text.trim());
                if (w == null || h == null || kb == null ||
                    w < 1 || h < 1 || w > 6000 || h > 6000 ||
                    kb < 10 || kb > 2048) {
                  _message(tr(
                    'Enter width and height from 1–6000 px and size from 10–2048 KB.',
                    'Width ও Height ১–৬০০০ px এবং সাইজ ২০–২০৪৮ KB দিন।',
                  ));
                  return;
                }
                setState(() {
                  _width.text = '$w';
                  _height.text = '$h';
                  _targetKb = kb;
                  _keepRatio = keepRatio;
                  _output = null;
                });
                Navigator.pop(dialogContext);
                _resize();
              },
              child: Text(tr('Apply & Resize', 'সেট করে রিসাইজ')),
            ),
          ],
        ),
      ),
    );
    widthController.dispose();
    heightController.dispose();
    sizeController.dispose();
  }

  Future<void> _resize() async {
    final file = _source;
    if (file == null || _busy) return;

    final requestedWidth = int.tryParse(_width.text.trim());
    final requestedHeight = int.tryParse(_height.text.trim());
    if (requestedWidth == null ||
        requestedHeight == null ||
        requestedWidth < 1 ||
        requestedHeight < 1 ||
        requestedWidth > 6000 ||
        requestedHeight > 6000) {
      _message(tr(
        'Enter width and height between 1 and 6000 pixels.',
        'Width ও Height ১ থেকে ৬০০০ পিক্সেলের মধ্যে দিন।',
      ));
      return;
    }

    setState(() => _busy = true);
    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) throw Exception('Unsupported image format');
      final oriented = img.bakeOrientation(decoded);

      var width = requestedWidth;
      var height = requestedHeight;
      if (_keepRatio) {
        final ratio = oriented.width / oriented.height;
        if (width / height > ratio) {
          width = (height * ratio).round().clamp(1, 6000);
        } else {
          height = (width / ratio).round().clamp(1, 6000);
        }
      }

      var working = img.copyResize(
        oriented,
        width: width,
        height: height,
        interpolation: img.Interpolation.average,
      );
      final maxBytes = _targetKb * 1024;
      var quality = 90;
      var bytes = Uint8List.fromList(img.encodeJpg(working, quality: quality));

      // Reduce JPEG quality first, then dimensions, until the requested
      // size is reached or the safe retry limit is met.
      for (var attempt = 0; bytes.length > maxBytes && attempt < 36; attempt++) {
        if (quality > 35) {
          quality = (quality - 5).clamp(35, 90);
        } else {
          quality = 75;
          final nextWidth = (working.width * 0.9).round().clamp(1, 6000);
          final nextHeight = (working.height * 0.9).round().clamp(1, 6000);
          if (nextWidth == working.width && nextHeight == working.height) break;
          working = img.copyResize(
            working,
            width: nextWidth,
            height: nextHeight,
            interpolation: img.Interpolation.average,
          );
        }
        bytes = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      }

      if (!mounted) return;
      setState(() => _output = bytes);
      final actualKb = (bytes.length / 1024).toStringAsFixed(1);
      _message(bytes.length <= maxBytes
          ? tr('Ready: $actualKb KB', 'তৈরি হয়েছে: $actualKb KB')
          : tr(
              'Best result: $actualKb KB. The target could not be reached.',
              'সেরা ফলাফল: $actualKb KB। নির্দিষ্ট সাইজে আনা যায়নি।',
            ));
    } catch (e) {
      _message('${tr('Resize failed', 'রিসাইজ করা যায়নি')}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _makeOutputFile() async {
    final bytes = _output;
    if (bytes == null) throw StateError('No resized image');
    final dir = await getTemporaryDirectory();
    final file = File(path.join(
      dir.path,
      'RD_Photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
    ));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _save() async {
    if (_output == null) return;
    try {
      await Gal.putImage((await _makeOutputFile()).path);
      _message(tr('Saved to Gallery.', 'গ্যালারিতে সেভ হয়েছে।'));
    } catch (e) {
      _message('${tr('Could not save image', 'ছবি সেভ করা যায়নি')}: $e');
    }
  }

  Future<void> _share() async {
    if (_output == null) return;
    try {
      final file = await _makeOutputFile();
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Made with RD Photo & Signature Resizer',
      );
    } catch (e) {
      _message('${tr('Share failed', 'শেয়ার করা যায়নি')}: $e');
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE3EAF2)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final output = _output;
    return Scaffold(
      drawer: Drawer(
        child: Container(
          color: brandBlue,
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 34, 18, 28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.photo_size_select_large, color: Colors.white, size: 62),
                    SizedBox(height: 14),
                    Text('RD CUSTOM PHOTO RESIZER', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text('VERSION 1.0.8', style: TextStyle(color: Colors.white70, letterSpacing: 3)),
                  ]),
                ),
                const Divider(color: Colors.white30),
                ListTile(leading: const Icon(Icons.tune, color: Colors.white), title: Text(tr('Custom Resize', 'কাস্টম রিসাইজ'), style: const TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context)),
                ListTile(leading: const Icon(Icons.settings, color: Colors.white), title: Text(tr('Settings', 'সেটিংস'), style: const TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _openSettings(); }),
                ListTile(leading: const Icon(Icons.help_outline, color: Colors.white), title: Text(tr('Help', 'সাহায্য'), style: const TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _message(tr('Choose a photo, enter your own width and height in pixels, then tap Custom Resize.', 'ছবি বেছে নিজের মতো Width ও Height দিন, তারপর Custom Resize চাপুন।')); }),
                ListTile(leading: const Icon(Icons.share, color: Colors.white), title: Text(tr('Share app', 'অ্যাপ শেয়ার'), style: const TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); Share.share('RD Photo & Signature Resizer v1.0.8\\nDownload APK: https://github.com/ranitdas0055-sys/rd-photo-signature-resizer/releases/latest'); }),
                ListTile(leading: const Icon(Icons.play_circle_fill, color: Colors.white), title: const Text('Govt Job with RD', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); Share.share('https://youtube.com/@govtjobwithrd'); }),
                const Padding(padding: EdgeInsets.fromLTRB(22, 24, 18, 10), child: Text('ABOUT', style: TextStyle(color: Colors.white70))),
                const ListTile(leading: Icon(Icons.verified_outlined, color: Colors.white), title: Text('Version 1.0.8', style: TextStyle(color: Colors.white))),
              ],
            ),
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(tr('RD Custom Resizer', 'RD কাস্টম রিসাইজার')),
        leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
        actions: [
          TextButton(
            onPressed: () => setState(() => _bengali = !_bengali),
            child: Text(
              _bengali ? 'English' : 'বাংলা',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1769AA), Color(0xFF2798D5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.photo_size_select_large, color: Colors.white, size: 42),
                  const SizedBox(height: 10),
                  const Text(
                    'RD Photo & Signature Resizer',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('Set your own photo width, height and file size. Photos stay on your device.',
                        'নিজের মতো ছবির Width, Height ও ফাইল সাইজ সেট করুন। ছবি ফোনেই থাকে।'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('1. Choose an image', '১. ছবি নির্বাচন করুন'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(tr('Select from Gallery', 'গ্যালারি থেকে ছবি নিন')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(tr('Take a Photo', 'ক্যামেরায় ছবি তুলুন')),
                  ),
                ],
              ),
            ),
            if (_source != null) ...[
              const SizedBox(height: 12),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Selected image', 'নির্বাচিত ছবি'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${(_sourceBytes / 1024).toStringAsFixed(1)} KB'),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_source!, height: 210, width: double.infinity, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _crop,
                          icon: const Icon(Icons.crop),
                          label: Text(tr('Crop', 'ক্রপ')),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _rotate,
                          icon: const Icon(Icons.rotate_right),
                          label: Text(tr('Rotate 90°', '৯০° ঘোরান')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('2. Resize settings', '২. রিসাইজ সেটিংস'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _width,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Width (px)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _height,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Height (px)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr('Keep aspect ratio', 'ছবির অনুপাত ঠিক রাখুন')),
                      value: _keepRatio,
                      onChanged: (value) => setState(() => _keepRatio = value),
                    ),
                    Text(
                      tr('Target file size: $_targetKb KB', 'লক্ষ্য ফাইল সাইজ: $_targetKb KB'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: _targetKb.toDouble(),
                      min: 10,
                      max: 2048,
                      divisions: 99,
                      label: _targetKb >= 1024
                          ? '${(_targetKb / 1024).toStringAsFixed(1)} MB'
                          : '$_targetKb KB',
                      onChanged: (value) => setState(() => _targetKb = value.round()),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [10, 20, 50, 100, 200, 500, 1024, 2048]
                          .map((size) => ChoiceChip(
                                label: Text(size >= 1024 ? '${size ~/ 1024} MB' : '$size KB'),
                                selected: _targetKb == size,
                                onSelected: (_) => setState(() => _targetKb = size),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _resize,
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.tune),
                        label: Text(_busy ? tr('Processing...', 'কাজ চলছে...') : tr('Resize Image', 'ছবি রিসাইজ করুন')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _openCustomResizeDialog,
                        icon: const Icon(Icons.tune),
                        label: Text(tr('Custom Resize', 'কাস্টম রিসাইজ')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (output != null) ...[
              const SizedBox(height: 12),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tr('3. Resized result', '৩. রিসাইজ করা ছবি'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(output, height: 210, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 8),
                    Text('${(output.length / 1024).toStringAsFixed(1)} KB • JPG'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.download),
                            label: Text(tr('Save', 'সেভ')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _share,
                            icon: const Icon(Icons.share),
                            label: Text(tr('Share', 'শেয়ার')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => Share.share('Govt Job with RD - https://youtube.com/@govtjobwithrd'),
                icon: const Icon(Icons.play_circle_fill, color: Colors.red),
                label: const Text('YouTube: Govt Job with RD'),
              ),
            ),
            Text(
              tr('Check the official application notice for the exact photo and signature size required.',
                  'ছবি ও সিগনেচারের সঠিক মাপের জন্য সংশ্লিষ্ট অফিসিয়াল বিজ্ঞপ্তি দেখুন।'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
