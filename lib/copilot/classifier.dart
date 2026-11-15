/// On-device experiment classifier (assets/models/experiment_classifier.onnx).
/// Native platforms run ONNX Runtime over FFI; web has no FFI, so it returns null and
/// the offline copilot falls back to keyword retrieval.
library;

export 'classifier_stub.dart' if (dart.library.ffi) 'classifier_ffi.dart';
