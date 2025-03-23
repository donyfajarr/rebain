import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'input.dart';

class MoveNetClassifier {
  late Interpreter interpreter;
  late InterpreterOptions _interpreterOptions;
  late List<int> _inputShape;
  late List<int> _outputShape;
  late ImageProcessor imageProcessor;
  late TensorImage inputImage;
  late TensorBuffer _outputBuffer;
  late TensorType _inputType;
  late TensorType _outputType;

  TensorBuffer outputLocations = TensorBufferFloat([]);
  MoveNetClassifier({int? numThreads}) {
    _interpreterOptions = InterpreterOptions();
    if (numThreads != null) {
      _interpreterOptions.threads = numThreads;
    }
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
  inputImage = imageProcessor.process(inputImage);
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
    
    List<Keypoint> keypoints = parseKeypoints(outputData, imageFile.width.toDouble(), imageFile.height.toDouble());
    // close();
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
  void close() {
    print('jalanclose');
    interpreter.close();
  }
}