import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomePageScreen(),
    );
  }
}

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  File? image;
  late ImagePicker imagePicker;
  late ImageLabeler labeler;
  String results = "";

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
    final ImageLabelerOptions options =
        ImageLabelerOptions(confidenceThreshold: 0.5);
    labeler = ImageLabeler(options: options);
  }

  void chooseImage() async {
    XFile? selectedImage =
        await imagePicker.pickImage(source: ImageSource.gallery);
    if (selectedImage != null) {
      setState(() => image = File(selectedImage.path));
      performImageLabeling();
    }
  }

  void captureImage() async {
    XFile? capturedImage =
        await imagePicker.pickImage(source: ImageSource.camera);
    if (capturedImage != null) {
      setState(() => image = File(capturedImage.path));
      performImageLabeling();
    }
  }

  Future<void> performImageLabeling() async {
    results = "";

    InputImage inputImage = InputImage.fromFile(image!);

    final List<ImageLabel> labels = await labeler.processImage(inputImage);

    for (ImageLabel label in labels) {
      final String text = label.label;
      final int index = label.index;
      final double confidence = label.confidence;

      debugPrint(text + "  " + confidence.toString());

      results += text + "     " + confidence.toStringAsFixed(2) + "\n";
    }

    setState(() => results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fruit Detection'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              image == null
                  ? const Icon(Icons.image_outlined, size: 54)
                  : Image.file(image!),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => chooseImage(),
                onLongPress: () => captureImage(),
                child: const Text('Choose/Capture Image'),
              ),
              Text(results),
            ],
          ),
        ),
      ),
    );
  }
}
