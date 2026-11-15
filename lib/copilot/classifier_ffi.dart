import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

// Mobile copy of backend/models/experiment_classifier.onnx re-stamped to opset 19 / IR 9:
// the bundled ORT 1.15 rejects opset 21. Same graph, identical probabilities (checked in Python).
const _asset = 'assets/models/experiment_classifier.onnx';

Future<OrtSession?>? _session;

Future<OrtSession?> _load() async {
  try {
    OrtEnv.instance.init();
    final bytes = (await rootBundle.load(_asset)).buffer.asUint8List();
    return OrtSession.fromBuffer(bytes, OrtSessionOptions());
  } catch (e) {
    debugPrint('ONNX classifier unavailable: $e');
    return null;
  }
}

/// Class probabilities (order = model.json experiment_classifier.classes); null if ONNX
/// can't load on this device.
Future<List<double>?> classifyText(String text) async {
  final s = await (_session ??= _load());
  if (s == null) return null;
  final input = OrtValueTensor.createTensorWithDataList([text], [1, 1]);
  final runOptions = OrtRunOptions();
  try {
    final out = s.run(runOptions, {s.inputNames.first: input});
    final probs = (out[1]!.value as List).first as List;
    for (final o in out) {
      o?.release();
    }
    return [for (final p in probs) (p as num).toDouble()];
  } catch (e) {
    debugPrint('ONNX classify failed: $e');
    return null;
  } finally {
    input.release();
    runOptions.release();
  }
}
