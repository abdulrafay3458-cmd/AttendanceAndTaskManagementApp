import 'package:flutter/widgets.dart';

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;
  }

  static double w(double percentage) {
    return screenWidth * (percentage / 100);
  }

  static double h(double percentage) {
    return screenHeight * (percentage / 100);
  }

  static double f(double size) {
    double scaleFactor = screenWidth / 360;
    return size * scaleFactor;
  }
}