import 'package:flutter/widgets.dart';

/// 寬螢幕（電腦瀏覽器、平板橫放）用左右分欄的版面，窄螢幕（手機）用單欄。
bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= 960;
