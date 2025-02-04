import 'dart:math';
// import 'dart:typed_data';


import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
// import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'input.dart';
// import 'package:camera/camera.dart';


class HandClassifier {
  late Interpreter interpreter;
  late InterpreterOptions _interpreterOptions;

  // var logger = Logger();

  late List<int> _inputShape;
  late List<int> _outputShape;

  // late ImageProcessor imageProcessor;
  // late TensorImage inputImage;

  late TensorBuffer _outputBuffer;
  // late List<Object> inputa = [];
  // Map<int, Object> outputs = {};

  // TensorBuffer outputLocations = TensorBufferFloat([]);
  final int inputSize = 224; // Input size for the MediaPipe Hands model
  final double scoreThreshold = 0.3; // Confidence threshold for hand detection
  final double existThreshold = 0.1;



  late TensorType _inputType;
  late TensorType _outputType;

  HandClassifier({int? numThreads}) {
    _interpreterOptions = InterpreterOptions();

    if (numThreads != null) {
      _interpreterOptions.threads = numThreads;
    }

    loadModel();
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset(
        // 'assets/movenetflt32.tflite', //SinglePoseThunderInputFloat32OutputFloat32
        'assets/hand_landmark.tflite',
        // 'assets/MediaPipeHandLandmarkDetector.tflite', //SinglePoseThunderInputUint8OutputFloat32
        options: _interpreterOptions,
      );
      print('Interpreter Created Successfully $interpreter');

      _inputShape = interpreter.getInputTensor(0).shape;
      _outputShape = interpreter.getOutputTensor(0).shape;
      _inputType = interpreter.getInputTensor(0).type;
      _outputType = interpreter.getOutputTensor(0).type;
      
      print("Hand Landmark");
      debugPrint('Input Shape: $_inputShape');
      debugPrint('Input Type: $_inputType');
      debugPrint('Output Shape: $_outputShape');
      debugPrint('Output Type: $_outputType');

      _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);

    } catch (e) {
      print('Unable to create interpreter, Caught Exception: ${e.toString()}');
    }
  }

Future<Float32List> _imageToByteListFloat32(Image image, int inputSize) async {
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

    // Create a Float32List for the input buffer
    Float32List inputBuffer = Float32List(inputSize * inputSize * 3);
    int pixelIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final int pixel = squareCanvas.getPixel(x, y);

        // Normalize pixel values to [0, 1] and convert to float32
        inputBuffer[pixelIndex++] = ((pixel >> 16) & 0xFF) / 255.0; // R
        inputBuffer[pixelIndex++] = ((pixel >> 8) & 0xFF) / 255.0;  // G
        inputBuffer[pixelIndex++] = (pixel & 0xFF) / 255.0;         // B
      }
    }

    return inputBuffer;
  }

Future<List<Handkeypoint>> processAndRunModel(Image imageFile) async {
  try {

    if (interpreter == null) {
  print('Interpreter is null.');
  return [];
}
    print("Processing image...");

    final inputBuffer =
        await _imageToByteListFloat32(imageFile, inputSize);
      // Prepare output buffer
      _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);
      print(inputBuffer);
      print(inputBuffer.length);
      final outputtest = _outputBuffer.getShape();
      print('output shape $outputtest');
      List<List<List<List<double>>>> reshapedInput = [
  List.generate(inputSize, (y) =>
    List.generate(inputSize, (x) =>
      List.generate(3, (c) =>
        inputBuffer[(y * inputSize + x) * 3 + c].toDouble()
      )
    )
  )
]; 
      print('Reshaped Input: $reshapedInput');
      print(reshapedInput.shape);
      // Run inference
      try {
  print('Checking interpreter: $interpreter');
  // if (interpreter == null) {
  //   print('Interpreter is null before inference.');
  //   return[];
  // }

  print('Running inference...');

  interpreter.run(reshapedInput, _outputBuffer.buffer); 

  print('Inference completed successfully.');
} catch (e, stacktrace) {
  print('Error during image processing or model inference: $e');
  print('Stacktrace: $stacktrace');
}
      // Get output data
      // final outputTest = _outputBuffer;
      // print(outputTest.);
      final outputData = _outputBuffer.getDoubleList();
      // print(outputData.length);
      // print (outputData.length);


      debugPrint('Output Raw : $outputData');
      print(outputData.length);
  print(imageFile.width);

 
    List<Handkeypoint> handkeypoints = parseKeypoints(outputData, imageFile.width.toDouble(), imageFile.height.toDouble());

    return handkeypoints;

  } catch (e) {
    print('Error during image processing or model inference: ${e.toString()}');
    return [];
  }
}

List<Handkeypoint> parseKeypoints(List<double> modelOutput, double imageWidth, double imageHeight) {
  List<Handkeypoint> handkeypoints = [];

  for (int i = 0; i < modelOutput.length; i += 3) {
    // Normalize coordinates from the model output (range 0-1) to the image dimensions
    double normalizedX = (modelOutput[i] / inputSize) ;  // Scale x-coordinate
    double normalizedY = (modelOutput[i + 1] / inputSize);     // Scale y-coordinate
    double confidence = modelOutput[i + 2];  // Confidence


    handkeypoints.add(Handkeypoint(normalizedX, normalizedY, confidence));

    // if (confidence >= scoreThreshold){
    //   handkeypoints.add(Handkeypoint(normalizedX, normalizedY, confidence));
    // }

    
  } 

  debugPrint('Image Width: $imageWidth, Image Height: $imageHeight');
  
  // Log each keypoint for debugging purposes
  for (var keypoint in handkeypoints) {
    print('Keypoint: (${keypoint.x}, ${keypoint.y}) with confidence: ${keypoint.confidence}');
  }

  print('Number of keypoints: ${handkeypoints.length}');
  
  return handkeypoints;
}

  void close() {
    interpreter.close();
  }
}