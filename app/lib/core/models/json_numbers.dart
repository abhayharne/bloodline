num? _jsonNumber(Object? value) {
  final number = switch (value) {
    num number => number,
    String text => num.tryParse(text.trim()),
    _ => null,
  };
  return number != null && number.isFinite ? number : null;
}

double? jsonDouble(Object? value) => _jsonNumber(value)?.toDouble();

int? jsonInt(Object? value) => _jsonNumber(value)?.toInt();
