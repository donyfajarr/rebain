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
import 'package:camera/camera.dart';

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
  late List<Object> inputa = [];
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
        // 'assets/movenetflt32.tflite',
        'assets/movenetfix.tflite',
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

      outputLocations = TensorBufferFloat([1, 1, 17, 3]);

      // _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);
    } catch (e) {
      print('Unable to create interpreter, Caught Exception: ${e.toString()}');
    }
  }


Future<List<List<List<List<double>>>>> _imageToByteListFloat32(
  Image image,
  int inputSize,
  double mean,
  double std,
) async {
  // Step 1: Create a blank square canvas
  final int originalWidth = image.width;
  final int originalHeight = image.height;

  // Maintain aspect ratio and calculate scale
  final int padSize = max(originalWidth, originalHeight);
  final double scale = inputSize / padSize;
  final int newWidth = (originalWidth * scale).round();
  final int newHeight = (originalHeight * scale).round();

  // Calculate padding
  final int paddingX = inputSize - newWidth;
  final int paddingY = inputSize - newHeight;

  // Create and fill a square canvas
  Image squareCanvas = Image(inputSize, inputSize);
  squareCanvas = fill(squareCanvas, getColor(0, 0, 0)); // Fill with black

  // Resize the original image
  final Image resizedImage = copyResize(
    image,
    width: newWidth,
    height: newHeight,
    interpolation: Interpolation.linear,
  );

  // Draw the resized image onto the canvas
  drawImage(
    squareCanvas,
    resizedImage,
    dstX: paddingX ~/ 2,
    dstY: paddingY ~/ 2,
  );

  // Step 2: Convert to Float32 Tensor with normalization
  var tensor = List.generate(
    1,
    (_) => List.generate(
      inputSize,
      (_) => List.generate(
        inputSize,
        (_) => List.generate(3, (_) => 0.0),
      ),
    ),
  );

  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final int pixel = squareCanvas.getPixel(x, y);

      // Extract RGB channels
      final int r = (pixel >> 16) & 0xFF;
      final int g = (pixel >> 8) & 0xFF;
      final int b = pixel & 0xFF;

      // Normalize and store in tensor
      tensor[0][y][x][0] = (r - mean) / std; // R
      tensor[0][y][x][1] = (g - mean) / std; // G
      tensor[0][y][x][2] = (b - mean) / std; // B
    }
  }

  return tensor;
}

Future<Uint8List> _imageToByteListUint8(
    Image image, int inputSize) async {
  // Step 1: Calculate resizing dimensions while maintaining aspect ratio
  final int originalWidth = image.width;
  final int originalHeight = image.height;

  // Scale the image to fit within the input size
  double scale = inputSize / max(originalWidth, originalHeight);
  print('scale $scale');
  int newWidth = (originalWidth * scale).round();
  int newHeight = (originalHeight * scale).round();

  print('new width $newWidth');
  print('new Height $newHeight');

  // Calculate padding
  int paddingX = inputSize - newWidth;
  int paddingY = inputSize - newHeight;
  
  print('padding x $paddingX');
  print('padding y $paddingY');

  // Create a blank square canvas
  Image squareCanvas = Image(inputSize, inputSize);
  squareCanvas = fill(squareCanvas, getColor(0, 0, 0)); // Fill with black

  // Resize and draw the original image on the canvas
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

  // Step 2: Create a Uint8List for the input tensor
  Uint8List inputBuffer = Uint8List(inputSize * inputSize * 3);
  int pixelIndex = 0;

  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final int pixel = squareCanvas.getPixel(x, y);

      // Extract RGB channels
      inputBuffer[pixelIndex++] = (pixel >> 16) & 0xFF; // R
      inputBuffer[pixelIndex++] = (pixel >> 8) & 0xFF;  // G
      inputBuffer[pixelIndex++] = pixel & 0xFF;         // B
    }
  }

  return inputBuffer;
}

TensorImage getProcessedImage() {
  int padSize = max(inputImage.height, inputImage.width);
  imageProcessor = ImageProcessorBuilder()
    .add(ResizeWithCropOrPadOp(padSize, padSize))
    .add(ResizeOp(256, 256, ResizeMethod.BILINEAR))
    .build();
  print('ea');
  inputImage = imageProcessor.process(inputImage);
  print('aih');
  return inputImage;
}
Future<List<Keypoint>> processAndRunModel(Image imageFile) async {
  if (interpreter == null) {
    print("Model is not loaded.");
    return [];  // Return an empty list if the model is not loaded
  }

  try {
    print("Processing image...");

    var width = imageFile.width;
    var height = imageFile.height;
    debugPrint('Width : $width x Height : $height');
    print(_inputType);
    final inputBuffer =
        await _imageToByteListUint8(imageFile, 256);
    // debugPrint('Width : $width x Height : $height');
    // final InputBuffer.round
    _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);

    // interpreter.runForMultipleInputs(inputBuffer, ou)
    interpreter.run(inputBuffer, _outputBuffer.buffer);

//     try {
//   var outputs = List<double>.filled(1 * 17 * 3, 0);  // Adjust size based on your model's output
//   interpreter.run(inputBuffer, outputs);
  
//   // Process outputs...
// } catch (e) {
//   print('Error running model: $e');
// }

    // Get and print the results
    final outputData = _outputBuffer.getDoubleList();
    debugPrint('Output Raw : $outputData');
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
      modelOutput[i+1],   // Scale x-coordinate
      modelOutput[i], // Scale y-coordinate
      modelOutput[i + 2],           // Confidence
    ));
    
    // print(keypoints[i]);
  }
  debugPrint('Image Width: $imageWidth, Image Height: $imageHeight');
  
  for (var keypoint in keypoints) {
  print('Keypoint: (${keypoint.x}, ${keypoint.y}) with confidence: ${keypoint.confidence}');
}
print(keypoints.length);

  return keypoints;
}

static Image convertGalleryImageToRGB(Image galleryImage) {
  final int width = galleryImage.width;
  final int height = galleryImage.height;

  // Create a new image to hold the RGB values
  Image rgbImage = Image(width, height);

  for (int w = 0; w < width; w++) {
    for (int h = 0; h < height; h++) {
      final pixel = galleryImage.getPixel(w, h);

      // Extract ARGB components (Android uses ARGB format for images)
      final a = (pixel >> 24) & 0xFF;  // Alpha
      final r = (pixel >> 16) & 0xFF;  // Red
      final g = (pixel >> 8) & 0xFF;   // Green
      final b = pixel & 0xFF;          // Blue

      // Since the image is already in RGB, we can store the values directly in the new image
      rgbImage.setPixel(w, h, getColor(r, g, b));
    }
  }

  return rgbImage;  // Return the RGB image
}

  static Image convertCameraImageAndroid(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int? uvPixelStride = cameraImage.planes[1].bytesPerPixel;

    final image = Image(width, height);

    for (int w = 0; w < width; w++) {
      for (int h = 0; h < height; h++) {
        final int uvIndex =
            uvPixelStride! * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final int index = h * width + w;

        final y = cameraImage.planes[0].bytes[index];
        final u = cameraImage.planes[1].bytes[uvIndex];
        final v = cameraImage.planes[2].bytes[uvIndex];

        image.data[index] = yuv2rgb(y, u, v);
      }
    }
    return image;
  }

  static int yuv2rgb(int y, int u, int v) {
    // Convert yuv pixel to rgb
    int r = (y + v * 1436 / 1024 - 179).round();
    int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
    int b = (y + u * 1814 / 1024 - 227).round();

    // Clipping RGB values to be inside boundaries [ 0 , 255 ]
    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);

    return 0xff000000 |
        ((b << 16) & 0xff0000) |
        ((g << 8) & 0xff00) |
        (r & 0xff);
  }
  

  void close() {
    interpreter.close();
  }


}