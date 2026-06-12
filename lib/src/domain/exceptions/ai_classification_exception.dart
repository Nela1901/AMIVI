class AiClassificationException implements Exception {
  final String userMessage;
  final dynamic originalError;
  final bool recoverable;

  AiClassificationException(
    this.userMessage, {
    this.originalError,
    this.recoverable = true,
  });

  @override
  String toString() => userMessage;
}