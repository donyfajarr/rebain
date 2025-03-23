import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

// Class untuk menyimpan hasil keypoint
class Handkeypoint {
  final double x, y, confidence;
  Handkeypoint(this.x, this.y, this.confidence);
}

class HandClassifier {
  late Interpreter _interpreter;
  late InterpreterOptions _options;
  late List<int> _inputShape;
  late List<int> _outputShape;
  late TensorType _inputType;
  late TensorType _outputType;
  late TensorBuffer _outputBuffer;

  TensorBuffer outputLocations = TensorBufferFloat([]);
  HandClassifier({int? numThreads}) {
    _options = InterpreterOptions();
    if (numThreads != null) {
      _options.threads = numThreads;
    }
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/MediaPipeHandLandmarkDetector.tflite',
        options: InterpreterOptions(),
      );
      print('Model loaded successfully');

      print('Interpreter: $_interpreter');

      _inputShape = _interpreter.getInputTensor(0).shape;
      _outputShape = _interpreter.getOutputTensor(2).shape;
      _inputType = _interpreter.getInputTensor(0).type;
      _outputType = _interpreter.getOutputTensor(2).type;

      // outputLocations = TensorBufferFloat([1, 21, 3]);
      _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);

      debugPrint('Input Shape: $_inputShape, Type: $_inputType');
      debugPrint('Output Shape: $_outputShape, Type: $_outputType');
    } catch (e) {
      print('Failed to load model: ${e.toString()}');
    }
  }


  // Preprocessing image: resize, normalize, and convert to Float32List

Future<Float32List> _imageToByteListFloat32(Image image, int inputSize) async {
  final int originalWidth = image.width;
  final int originalHeight = image.height;

  double scale = inputSize / max(originalWidth, originalHeight);
  int newWidth = (originalWidth * scale).round();
  int newHeight = (originalHeight * scale).round();

  int paddingX = inputSize - newWidth;
  int paddingY = inputSize - newHeight;

  Image squareCanvas = Image(inputSize, inputSize);
  squareCanvas = fill(squareCanvas, getColor(0, 0, 0));

  final Image resizedImage = copyResize(
    image,
    width: newWidth,
    height: newHeight,
    interpolation: Interpolation.linear,
  );

  drawImage(
    squareCanvas,
    resizedImage,
    dstX: paddingX ~/ 2,
    dstY: paddingY ~/ 2,
  );

  Float32List inputBuffer = Float32List(inputSize * inputSize * 3);
  int pixelIndex = 0;

  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final int pixel = squareCanvas.getPixel(x, y);
      
      // ✅ Extract only RGB, ignore Alpha
      int r = (pixel >> 16) & 0xFF;
      int g = (pixel >> 8) & 0xFF;
      int b = (pixel) & 0xFF;

      inputBuffer[pixelIndex++] = r / 255.0; // Normalize R
      inputBuffer[pixelIndex++] = g / 255.0; // Normalize G
      inputBuffer[pixelIndex++] = b / 255.0; // Normalize B
    }
  }

  return inputBuffer;
}




Future<List<Handkeypoint>> processImage(Image image) async {
  if (_interpreter == null) {
    print("Error: Interpreter has not been initialized!");
    return [];
  }

  try {
    print("Processing Image: ${image.width}x${image.height}");
    

    // ✅ Preprocess Image - Pastikan dalam format `[1, 256, 256, 3]`
    var inputBuffer = await _imageToByteListFloat32(image, 256);
    var inputTensor = inputBuffer.reshape([1, 256, 256, 3]);
    // TensorBuffer outputLandmarks = TensorBufferFloat([1, 21, 3]);

    print("Running inference...");
    
    // ✅ Run inference with first output tensor only
     // ✅ Create a buffer specifically for the third output tensor
      // ✅ Use third output: [1, 21, 3]
    var outputScores = List<double>.filled(1, 0);
    var outputLr = List<double>.filled(1, 0);
    var outputLandmarks = List.generate(1, (_) => 
        List.generate(21, (_) => List.filled(3, 0.0))
    );

    // Define output mapping based on tensor indices
    var outputs = {
      0: outputScores,  // scores
      1: outputLr,      // lr
      2: outputLandmarks // landmarks
    };

    // Run inference
    _interpreter!.runForMultipleInputs([inputTensor], outputs);

    // Debugging: Print outputs
    print("✅ Scores: $outputScores");
    print("✅ LR: $outputLr");
    print("✅ Landmarks: $outputLandmarks");

    // Check if landmarks were detected
    if (outputLandmarks[0][0][0] == 0.0) {
      print("⚠️ No hand keypoints detected!");
    }

    return _parseKeypoints(outputLandmarks[0], image.width.toDouble(), image.height.toDouble());

  } catch (e) {
    print("Error during inference: ${e.toString()}");
    return [];
  }
}



  // Function to parse the model output into keypoints
List<Handkeypoint> _parseKeypoints(List<List<double>> outputData, double imageWidth, double imageHeight) {
  List<Handkeypoint> keypoints = [];

  if (outputData.length != 21) {
    print("❌ Error: Expected 21 keypoints, got ${outputData.length}");
    return [];
  }

  for (int i = 0; i < 21; i++) {
    double x = outputData[i][0];  // ✅ x-coordinate
    double y = outputData[i][1];  // ✅ y-coordinate
    double confidence = outputData[i][2];  // ❌ Might be depth, not confidence

    // ✅ Fix: Ignore z-depth or normalize it
    confidence = confidence.abs();  // Use absolute value (if needed)

    keypoints.add(Handkeypoint(x, y, confidence));
  }

  return keypoints;
}





  void close() {
    _interpreter.close();
  }
}
