import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'input.dart';

List<String> keypointLabels = [
  "Nose",
  "Left eye",
  "Right eye",
  "Left ear",
  "Right ear",
  "Left shoulder",
  "Right shoulder",
  "Left elbow",
  "Right elbow",
  "Left wrist",
  "Right wrist",
  "Left hip",
  "Right hip",
  "Left knee",
  "Right knee",
  "Left ankle",
  "Right ankle"
];

// List<Map<String, dynamic>> parseKeypoints(List<double> output) {
//   List<Map<String, dynamic>> keypoints = [];

//   for (int i = 0; i < keypointLabels.length; i++) {
//     int startIndex = i * 3; // Each keypoint has 3 values
//     keypoints.add({
//       "label": keypointLabels[i],
//       "x": output[startIndex], // x-coordinate
//       "y": output[startIndex + 1], // y-coordinate
//       "confidence": output[startIndex + 2], // confidence score
//     });
//   }

//   return keypoints;
// }

// import 'package:image/image.dart' as img;
// Future<Uint8List> _imageToByteListFloat32(
//     Image image, int inputSize, double mean, double std) async {
//   var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
//   var buffer = Float32List.view(convertedBytes.buffer);
//   int pixelIndex = 0;

//   for (var i = 0; i < inputSize; i++) {
//     for (var j = 0; j < inputSize; j++) {
//       var pixel = image.getPixel(j, i);

//       // Extract ARGB components
//       var r = (pixel >> 16) & 0xFF; // Red component
//       var g = (pixel >> 8) & 0xFF;  // Green component
//       var b = pixel & 0xFF;         // Blue component

//       // Normalize and store values
//       buffer[pixelIndex++] = (r - mean) / std;
//       buffer[pixelIndex++] = (g - mean) / std;
//       buffer[pixelIndex++] = (b - mean) / std;
//     }
//   }

//   return convertedBytes.buffer.asUint8List();
// }


// import 'package:flutter/material.dart';


class MoveNetClassifier {
  late Interpreter interpreter;
  late InterpreterOptions _interpreterOptions;

  var logger = Logger();

  late List<int> _inputShape;
  late List<int> _outputShape;

  late ImageProcessor imageProcessor;
  late TensorImage inputImage;

  late TensorBuffer _outputBuffer;
  late List<Object> inputs;
  Map<int, Object> outputs = {};

  TensorBuffer outputLocations = TensorBufferFloat([]);

  late TensorType _inputType;
  late TensorType _outputType;

  late var _probabilityProcessor;
  

  // List<List<Map<String, dynamic>>> keypoints = [];

  

  MoveNetClassifier({int? numThreads}) {
    _interpreterOptions = InterpreterOptions();

    if (numThreads != null) {
      _interpreterOptions.threads = numThreads;
    }

    loadModel();
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset(
        'assets/movenetflt32.tflite',
        options: _interpreterOptions,
      );
      print('Interpreter Created Successfully');

      // List<int> inputShape = interpreter.getInputTensor(0).shape;
      // print('Input shape: $inputShape'); // This will print the shape of the input tensor

      _inputShape = interpreter.getInputTensor(0).shape;
      _outputShape = interpreter.getOutputTensor(0).shape;
      _inputType = interpreter.getInputTensor(0).type;
      _outputType = interpreter.getOutputTensor(0).type;

      debugPrint('Input Shape: $_inputShape');
      debugPrint('Input Type: $_inputType');
      debugPrint('Output Shape: $_outputShape');
      debugPrint('Output Type: $_outputType');

      // _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);
    } catch (e) {
      print('Unable to create interpreter, Caught Exception: ${e.toString()}');
    }
  }

Future<Uint8List> _imageToByteListFloat32(
    Image image, int inputSize, double mean, double std) async {
  // Step 1: Calculate padding to make the image square
  final int originalWidth = image.width;
  final int originalHeight = image.height;
  final int padSize = max(originalWidth, originalHeight);

  // Create a blank square canvas
  Image squareCanvas = Image(padSize, padSize);
  squareCanvas = fill(squareCanvas, getColor(0, 0, 0, 255)); // Fill with black or desired padding color

  // Draw the original image centered on the square canvas
  drawImage(
    squareCanvas,
    image,
    dstX: (padSize - originalWidth) ~/ 2,
    dstY: (padSize - originalHeight) ~/ 2,
  );

  // Step 2: Resize the padded square image to the input size (256x256)
  final resizedImage = copyResize(squareCanvas, width: inputSize, height: inputSize);

  // Step 3: Convert resized image into Float32 buffer
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;

  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = resizedImage.getPixel(j, i);

      // Extract ARGB components
      var r = (pixel >> 16) & 0xFF; // Red component
      var g = (pixel >> 8) & 0xFF;  // Green component
      var b = pixel & 0xFF;         // Blue component

      // Normalize and store values
      buffer[pixelIndex++] = (r - mean) / std;
      buffer[pixelIndex++] = (g - mean) / std;
      buffer[pixelIndex++] = (b - mean) / std;
    }
  }

  // Step 4: Return the normalized buffer as Uint8List
  return convertedBytes.buffer.asUint8List();
}
Future<List<Keypoint>> processAndRunModel(Image imageFile) async {
  if (interpreter == null) {
    print("Model is not loaded.");
    return [];  // Return an empty list if the model is not loaded
  }

  try {
    print("Processing image...");
    // Preprocess the input image
    final inputBuffer =
        await _imageToByteListFloat32(imageFile, 256, 127.5, 127.5);

    // Initialize the output buffer
    _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);
    // Map<int, Object> outputs = {0: outputLocations.buffer};
    // // Run inference
    interpreter.run(inputBuffer, _outputBuffer.buffer);

    // Get and print the results
    final outputData = _outputBuffer.getDoubleList();
    debugPrint('Output Raw : $_outputBuffer');
    // debugPrint('Model Output: $outputData');

    // Parse the output into keypoints
    List<Keypoint> keypoints = parseKeypoints(outputData, imageFile.width.toDouble(), imageFile.height.toDouble());

    // Return the parsed keypoints
    return keypoints;

  } catch (e) {
    print("Error running model: $e");
    return [];  // Return an empty list in case of error
  }
}


List<Keypoint> parseKeypoints(List<double> modelOutput, double imageWidth, double imageHeight) {
  List<Keypoint> keypoints = [];
  for (int i = 0; i < modelOutput.length; i += 3) {
    keypoints.add(Keypoint(
      modelOutput[i] * imageWidth,   // Scale x-coordinate
      modelOutput[i + 1] * imageHeight, // Scale y-coordinate
      modelOutput[i + 2],           // Confidence
    ));
    for (var keypoint in keypoints) {
  print('Keypoint: (${keypoint.x}, ${keypoint.y}) with confidence: ${keypoint.confidence}');
}
print(keypoints.length);
    // print(keypoints[i]);
  }
  
  return keypoints;
}

  void close() {
    interpreter.close();
  }


}