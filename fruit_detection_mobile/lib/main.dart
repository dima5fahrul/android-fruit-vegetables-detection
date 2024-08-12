import 'dart:io';

import 'package:flutter/material.dart';
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

  @override
  void initState() {
    imagePicker = ImagePicker();
    super.initState();
  }

  void chooseImage() async {
    XFile? selectedImage =
        await imagePicker.pickImage(source: ImageSource.gallery);
    if (selectedImage != null) {
      setState(() => image = File(selectedImage.path));
    }
  }

  void captureImage() async {
    XFile? capturedImage =
        await imagePicker.pickImage(source: ImageSource.camera);
    if (capturedImage != null) {
      setState(() => image = File(capturedImage.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fruit Detection'),
      ),
      body: Center(
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
          ],
        ),
      ),
    );
  }
}
