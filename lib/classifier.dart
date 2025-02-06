import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
// import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'input.dart';
// import 'calculate.dart';
// import 'package:camera/camera.dart';

// List<String> keypointLabels = [
//   "Nose",
//   "Left eye",
//   "Right eye",
//   "Left ear",
//   "Right ear",
//   "Left shoulder",
//   "Right shoulder",
//   "Left elbow",
//   "Right elbow",
//   "Left wrist",
//   "Right wrist",
//   "Left hip",
//   "Right hip",
//   "Left knee",
//   "Right knee",
//   "Left ankle",
//   "Right ankle"
// ];

class MoveNetClassifier {
  late Interpreter interpreter;
  late InterpreterOptions _interpreterOptions;

  // var logger = Logger();

  late List<int> _inputShape;
  late List<int> _outputShape;

  late ImageProcessor imageProcessor;
  late TensorImage inputImage;

  late TensorBuffer _outputBuffer;
  // late List<Object> inputa = [];
  // Map<int, Object> outputs = {};

  TensorBuffer outputLocations = TensorBufferFloat([]);

  late TensorType _inputType;
  late TensorType _outputType;

  MoveNetClassifier({int? numThreads}) {
    _interpreterOptions = InterpreterOptions();

    if (numThreads != null) {
      _interpreterOptions.threads = numThreads;
    }

    // loadModel();
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset(
        // 'assets/movenetflt32.tflite', //SinglePoseThunderInputFloat32OutputFloat32
        'assets/movenetfix.tflite', //SinglePoseThunderInputUint8OutputFloat32
        options: _interpreterOptions,
      );
      print('Interpreter Created Successfully');

      _inputShape = interpreter.getInputTensor(0).shape;
      _outputShape = interpreter.getOutputTensor(0).shape;
      _inputType = interpreter.getInputTensor(0).type;
      _outputType = interpreter.getOutputTensor(0).type;

      debugPrint('Input Shape: $_inputShape');
      debugPrint('Input Type: $_inputType');
      debugPrint('Output Shape: $_outputShape');
      debugPrint('Output Type: $_outputType');

      outputLocations = TensorBufferFloat([1, 1, 17, 3]);

    } catch (e) {
      print('Unable to create interpreter, Caught Exception: ${e.toString()}');
    }
  }

Future<Uint8List> _imageToByteListUint8(
    Image image, int inputSize) async {
  // Step 1: Calculate resizing dimensions while maintaining aspect ratio
  final int originalWidth = image.width;
  final int originalHeight = image.height;

  // Scale the image to fit within the input size
  double scale = inputSize / max(originalWidth, originalHeight);
  print('Preprocessing');
  print('scale : $scale');
  int newWidth = (originalWidth * scale).round();
  int newHeight = (originalHeight * scale).round();

  print('new width : $newWidth x new Height : $newHeight');
  // Calculate padding
  int paddingX = inputSize - newWidth;
  int paddingY = inputSize - newHeight;
  
  print('Adding some padding');
  print('padding x $paddingX x padding y $paddingY');

  // Create a blank square canvas
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

  Uint8List inputBuffer = Uint8List(inputSize * inputSize * 3);
  int pixelIndex = 0;

  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final int pixel = squareCanvas.getPixel(x, y);

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
  try {
    print("Processing image...");

    final inputBuffer =
        await _imageToByteListUint8(imageFile, 256);
    _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);
    print(inputBuffer);
    interpreter.run(inputBuffer, _outputBuffer.buffer);

    final outputData = _outputBuffer.getDoubleList();
    debugPrint('Output Raw : $outputData');
 
    List<Keypoint> keypoints = parseKeypoints(outputData, imageFile.width.toDouble(), imageFile.height.toDouble());

    return keypoints;

  } catch (e) {
    print("Error running model: $e");
    return [];
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
  }
  debugPrint('Image Width: $imageWidth, Image Height: $imageHeight');
  
  for (var keypoint in keypoints) {
  print('Keypoint: (${keypoint.x}, ${keypoint.y}) with confidence: ${keypoint.confidence}');
}
print(keypoints.length);

  return keypoints;
}

// static Image convertGalleryImageToRGB(Image galleryImage) {
//   final int width = galleryImage.width;
//   final int height = galleryImage.height;

//   // Create a new image to hold the RGB values
//   Image rgbImage = Image(width, height);

//   for (int w = 0; w < width; w++) {
//     for (int h = 0; h < height; h++) {
//       final pixel = galleryImage.getPixel(w, h);

//       // Extract ARGB components (Android uses ARGB format for images)
//       final r = (pixel >> 16) & 0xFF;  // Red
//       final g = (pixel >> 8) & 0xFF;   // Green
//       final b = pixel & 0xFF;          // Blue

//       // Since the image is already in RGB, we can store the values directly in the new image
//       rgbImage.setPixel(w, h, getColor(r, g, b));
//     }
//   }

//   return rgbImage;  // Return the RGB image
// }

//   static Image convertCameraImageAndroid(CameraImage cameraImage) {
//     final int width = cameraImage.width;
//     final int height = cameraImage.height;

//     final int uvRowStride = cameraImage.planes[1].bytesPerRow;
//     final int? uvPixelStride = cameraImage.planes[1].bytesPerPixel;

//     final image = Image(width, height);

//     for (int w = 0; w < width; w++) {
//       for (int h = 0; h < height; h++) {
//         final int uvIndex =
//             uvPixelStride! * (w / 2).floor() + uvRowStride * (h / 2).floor();
//         final int index = h * width + w;

//         final y = cameraImage.planes[0].bytes[index];
//         final u = cameraImage.planes[1].bytes[uvIndex];
//         final v = cameraImage.planes[2].bytes[uvIndex];

//         image.data[index] = yuv2rgb(y, u, v);
//       }
//     }
//     return image;
//   }

//   static int yuv2rgb(int y, int u, int v) {
//     // Convert yuv pixel to rgb
//     int r = (y + v * 1436 / 1024 - 179).round();
//     int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
//     int b = (y + u * 1814 / 1024 - 227).round();

//     // Clipping RGB values to be inside boundaries [ 0 , 255 ]
//     r = r.clamp(0, 255);
//     g = g.clamp(0, 255);
//     b = b.clamp(0, 255);

//     return 0xff000000 |
//         ((b << 16) & 0xff0000) |
//         ((g << 8) & 0xff00) |
//         (r & 0xff);
//   }
  

  void close() {
    interpreter.close();
  }
}