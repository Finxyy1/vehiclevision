import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  runApp(const DetectionPage());
}

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  Interpreter? _interpreter;
  File? _image;
  List<Detection> detections = [];
  List<String> labels = [];

  final int inputSize = 640;
  final int numClasses = 4;
  final double confThreshold = 0.4;

  int originalWidth = 0;
  int originalHeight = 0;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  // WARNA PER CLASS YANG LEBIH TERANG DAN JELAS
  Color getColor(int classIndex) {
    switch (classIndex) {
      case 0: return const Color(0xFF2196F3); // Biru terang - Car
      case 1: return const Color(0xFFFF9800); // Orange - Truck
      case 2: return const Color(0xFF4CAF50); // Hijau - Bus
      case 3: return const Color(0xFF9C27B0); // Ungu - Motorbike
      default: return const Color(0xFFF44336); // Merah
    }
  }

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/best_int8Kendaraan.tflite');
  }

  Future<void> loadLabels() async {
    final data = await DefaultAssetBundle.of(context)
        .loadString("assets/labels.txt");
    labels = data.split('\n');
  }

  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: source);

    if (picked != null) {
      _image = File(picked.path);

      img.Image decoded = img.decodeImage(_image!.readAsBytesSync())!;
      originalWidth = decoded.width;
      originalHeight = decoded.height;

      await loadLabels();
      runModel(_image!);
    }
  }

  // Fungsi untuk memilih sumber gambar (Kamera atau Galeri)
  void showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.all(10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF2196F3)),
                title: const Text(
                  "Ambil Gambar",
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  "Buka kamera untuk foto langsung",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF4CAF50)),
                title: const Text(
                  "Pilih dari Galeri",
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  "Pilih gambar yang sudah ada di HP",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Float32List preprocess(File imageFile) {
    img.Image image = img.decodeImage(imageFile.readAsBytesSync())!;
    img.Image resized = img.copyResize(image, width: 640, height: 640);

    var input = Float32List(1 * 640 * 640 * 3);
    int index = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[index++] = pixel.r / 255.0;
        input[index++] = pixel.g / 255.0;
        input[index++] = pixel.b / 255.0;
      }
    }
    return input;
  }

  void runModel(File imageFile) {
    if (_interpreter == null) return;

    var input = preprocess(imageFile);

    var output = List.generate(
      1,
      (_) => List.generate(300, (_) => List.filled(6, 0.0)),
    );

    _interpreter!.run(input.reshape([1, 640, 640, 3]), output);

    List<Detection> results = [];

    for (int i = 0; i < 300; i++) {
      double confidence = output[0][i][4];
      int classIndex = output[0][i][5].toInt();

      if (confidence > confThreshold) {
        double x1 = output[0][i][0];
        double y1 = output[0][i][1];
        double x2 = output[0][i][2];
        double y2 = output[0][i][3];

        double finalX = x1 * originalWidth;
        double finalY = y1 * originalHeight;
        double finalW = (x2 - x1) * originalWidth;
        double finalH = (y2 - y1) * originalHeight;

        results.add(
          Detection(
            x: finalX,
            y: finalY,
            w: finalW,
            h: finalH,
            confidence: confidence,
            classIndex: classIndex,
          ),
        );
      }
    }

    setState(() {
      detections = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Deteksi Kendaraan"),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // Tombol Pilih Gambar (Kamera & Galeri)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => showImageSourceDialog(),
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text("Pilih Gambar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _image == null
                  ? const Center(
                      child: Text(
                        "Belum ada gambar\n\nKlik 'Pilih Gambar'\nuntuk memulai deteksi",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        double widgetWidth = constraints.maxWidth;
                        double widgetHeight = constraints.maxHeight;

                        double imageAspect = originalWidth / originalHeight;
                        double widgetAspect = widgetWidth / widgetHeight;

                        double displayWidth;
                        double displayHeight;
                        double offsetX = 0;
                        double offsetY = 0;

                        if (imageAspect > widgetAspect) {
                          displayWidth = widgetWidth;
                          displayHeight = widgetWidth / imageAspect;
                          offsetY = (widgetHeight - displayHeight) / 2;
                        } else {
                          displayHeight = widgetHeight;
                          displayWidth = widgetHeight * imageAspect;
                          offsetX = (widgetWidth - displayWidth) / 2;
                        }

                        double scaleX = displayWidth / originalWidth;
                        double scaleY = displayHeight / originalHeight;

                        return Stack(
                          children: [
                            Center(
                              child: Image.file(_image!, fit: BoxFit.contain),
                            ),
                            ...detections.map((d) {
                              Color color = getColor(d.classIndex);
                              String label = d.classIndex < labels.length 
                                  ? labels[d.classIndex] 
                                  : 'Kendaraan';

                              return Positioned(
                                left: d.x * scaleX + offsetX,
                                top: d.y * scaleY + offsetY,
                                width: d.w * scaleX,
                                height: d.h * scaleY,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: color, width: 3),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      child: Text(
                                        "$label ${(d.confidence * 100).toStringAsFixed(0)}%",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class Detection {
  final double x, y, w, h, confidence;
  final int classIndex;

  Detection({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.confidence,
    required this.classIndex,
  });
}