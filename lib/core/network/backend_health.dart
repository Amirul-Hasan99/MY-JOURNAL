import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

final backendHealthProvider = FutureProvider.autoDispose<bool>(
  (ref) => ApiClient().checkHealth(),
);
