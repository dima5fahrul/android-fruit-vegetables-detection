import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fruit_detection_mobile_v2/live_detection/camera_preview.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'dart:math' as math;

import 'bndbox.dart';
import 'models.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage(this.cameras, {super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> _recognitions = [];
  int _imageHeight = 0;
  int _imageWidth = 0;
  String _model = "";

  @override
  void initState() {
    super.initState();
  }

  loadModel() async {
    String? res;
    switch (_model) {
      case yolo:
        res = await Tflite.loadModel(
          model: "assets/ml/yolov2_tiny.tflite",
          labels: "assets/ml/yolov2_tiny.txt",
        );
        break;

      case mobilenet:
        res = await Tflite.loadModel(
            model: "assets/ml/mobilenet_v1_1.0_224.tflite",
            labels: "assets/ml/mobilenet_v1_1.0_224.txt");
        break;

      case posenet:
        res = await Tflite.loadModel(
            model: "assets/ml/posenet_mv1_075_float_from_checkpoints.tflite");
        break;

      default:
        res = await Tflite.loadModel(
            model: "assets/ml/ssd_mobilenet.tflite",
            labels: "assets/ml/ssd_mobilenet.txt");
    }
    print('res: $res');
  }

  onSelect(model) {
    setState(() {
      _model = model;
    });
    loadModel();
  }

  setRecognitions(recognitions, imageHeight, imageWidth) {
    debugPrint('call it');
    setState(() {
      _recognitions = recognitions;
      _imageHeight = imageHeight;
      _imageWidth = imageWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    return Scaffold(
      body: _model == ""
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    child: const Text(ssd),
                    onPressed: () => onSelect(ssd),
                  ),
                  ElevatedButton(
                    child: const Text(yolo),
                    onPressed: () => onSelect(yolo),
                  ),
                  ElevatedButton(
                    child: const Text(mobilenet),
                    onPressed: () => onSelect(mobilenet),
                  ),
                  ElevatedButton(
                    child: const Text(posenet),
                    onPressed: () => onSelect(posenet),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Camera(
                  widget.cameras,
                  _model,
                  setRecognitions(_recognitions, 320, 320),
                ),
                BndBox(
                    _recognitions,
                    math.max(_imageHeight, _imageWidth),
                    math.min(_imageHeight, _imageWidth),
                    screen.height,
                    screen.width,
                    _model),
              ],
            ),
    );
  }
}
