import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 0 = الرئيسية، 1 = التحميلات
final tabProvider = StateProvider<int>((ref) => 0);
