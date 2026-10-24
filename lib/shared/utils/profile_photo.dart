import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

ImageProvider<Object>? profileImageProvider(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('data:image/')) {
    final comma = photoUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(photoUrl.substring(comma + 1)));
    } on FormatException {
      return null;
    }
  }
  return NetworkImage(photoUrl);
}

ImageProvider<Object> profileImageFromBytes(Uint8List bytes) =>
    MemoryImage(bytes);
