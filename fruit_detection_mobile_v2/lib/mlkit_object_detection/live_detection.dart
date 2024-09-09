import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LiveDetection extends StatefulWidget {
  final List<CameraDescription> cameras;
  const LiveDetection({super.key, required this.cameras});

  @override
  State<LiveDetection> createState() => _LiveDetectionState();
}

class _LiveDetectionState extends State<LiveDetection> {
  CameraController? controller;
  bool _isBusy = false;
  dynamic _objectDetector;
  String result = '';
  List<DetectedObject>? _scanResults;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _initializeCamera();
  }

  void _initializeCamera() {
    controller = CameraController(widget.cameras[0], ResolutionPreset.max,
        imageFormatGroup: ImageFormatGroup.nv21);

    controller!.initialize().then((_) {
      if (!mounted) return;

      controller!.startImageStream((image) {
        if (!_isBusy) {
          _isBusy = true;
          _processImage(image);
        }
      });

      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    });
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas
    final camera = widget.cameras[0];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  Future<void> _processImage(CameraImage img) async {
    InputImage? frameImg = _inputImageFromCameraImage(img);
    List<DetectedObject> objects =
        await _objectDetector.processImage(frameImg!);
    print("len= ${objects.length}");

    setState(() {
      _scanResults = objects;
      _isBusy = false;
    });
  }

  Future<String> _getModelPath(String asset) async {
    final path = '${(await getApplicationSupportDirectory()).path}/$asset';
    await Directory(dirname(path)).create(recursive: true);
    final file = File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(asset);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }

  Future<void> _loadModel() async {
    final modelPath = await _getModelPath('assets/ml/model.tflite');
    final options = LocalObjectDetectorOptions(
        mode: DetectionMode.stream,
        modelPath: modelPath,
        confidenceThreshold: 0.8,
        multipleObjects: true,
        classifyObjects: true);

    _objectDetector = ObjectDetector(options: options);
  }

  @override
  void dispose() {
    controller!.dispose();
    _objectDetector.close();
    super.dispose();
  }

  //Show rectangles around detected objects
  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller!.value.isInitialized) {
      return const Text('');
    }

    final Size imageSize = Size(controller!.value.previewSize!.height,
        controller!.value.previewSize!.width);
    CustomPainter painter = ObjectDetectorPainter(imageSize, _scanResults!);
    return CustomPaint(painter: painter);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    var size = MediaQuery.of(context).size;

    stackChildren.add(Positioned(
        top: 0.0,
        left: 0.0,
        width: size.width,
        height: size.height,
        child: Container(
            child: (controller!.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: CameraPreview(controller!),
                  )
                : Container())));

    stackChildren.add(
      Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: buildResult()),
    );

    return Scaffold(
        appBar: AppBar(
          title: const Text("Object detector"),
          backgroundColor: Colors.pinkAccent,
        ),
        backgroundColor: Colors.black,
        body: Container(
            margin: const EdgeInsets.only(top: 0),
            color: Colors.black,
            child: Stack(children: stackChildren)));
  }
}

class ObjectDetectorPainter extends CustomPainter {
  ObjectDetectorPainter(this.absoluteImageSize, this.objects);

  final Size absoluteImageSize;
  final List<DetectedObject> objects;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.pinkAccent;

    for (DetectedObject detectedObject in objects) {
      canvas.drawRect(
          Rect.fromLTRB(
              detectedObject.boundingBox.left * scaleX,
              detectedObject.boundingBox.top * scaleY,
              detectedObject.boundingBox.right * scaleX,
              detectedObject.boundingBox.bottom * scaleY),
          paint);

      var list = detectedObject.labels;

      for (Label label in list) {
        print(
            "${label.text}   ${label.confidence.toStringAsFixed(2)}=====================++========================+++=====================++++=======");
        TextSpan span = TextSpan(
            text: "${label.text} ${label.confidence.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 25, color: Colors.blue));
        TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(
            canvas,
            Offset(detectedObject.boundingBox.left * scaleX,
                detectedObject.boundingBox.top * scaleY));
        break;
      }
    }
  }

  @override
  bool shouldRepaint(ObjectDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.objects != objects;
  }
}
