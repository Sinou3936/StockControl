import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 화면을 한 번 떠서 만든 픽셀 묶음. 좌표는 논리 픽셀이고, 이미지를
/// `devicePixelRatio = 1.0`으로 떴을 때만 화면 좌표와 일치한다.
class CapturedPixels {
  CapturedPixels(this._data, this.width, this.height);

  final ByteData _data;
  final int width;
  final int height;

  Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      _data.getUint8(i + 3),
      _data.getUint8(i),
      _data.getUint8(i + 1),
      _data.getUint8(i + 2),
    );
  }
}

/// [boundaryKey]를 단 `RepaintBoundary`를 실제로 그려 픽셀을 읽는다.
/// 테스트 안에서 `toImage`는 `runAsync` 밖에서 기다리면 끝나지 않는다.
Future<CapturedPixels> capturePixels(
  WidgetTester tester,
  GlobalKey boundaryKey,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final pixels = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    try {
      // rawRgba는 알파가 미리 곱해진(premultiplied) 값이다. 우리가 읽는 점은
      // 모두 불투명한 카드 위라서 알파가 1이므로 색이 달라지지 않는다.
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return CapturedPixels(data!, image.width, image.height);
    } finally {
      image.dispose();
    }
  });
  return pixels!;
}

enum CardCorner { topLeft, topRight, bottomLeft, bottomRight }

/// [rect]를 반지름 [radius]로 둥글게 깎은 카드에서, 모서리 호 위의 한 점
/// (모서리 원의 중심에서 45도 방향, 중심에서 [arcDistance]만큼)을 덮는 픽셀.
///
/// 테두리 두께가 1이고 반지름이 12이면 테두리 띠는 중심에서 11~12 떨어진
/// 곳이므로 11.5는 띠의 한가운데다.
Color cornerArcColor(
  CapturedPixels pixels,
  Rect rect,
  CardCorner corner, {
  double radius = 12,
  double arcDistance = 11.5,
}) {
  final left = corner == CardCorner.topLeft || corner == CardCorner.bottomLeft;
  final top = corner == CardCorner.topLeft || corner == CardCorner.topRight;
  final center = Offset(
    left ? rect.left + radius : rect.right - radius,
    top ? rect.top + radius : rect.bottom - radius,
  );
  // 45도 방향 근처에서, 픽셀 중심이 모서리 원의 중심으로부터 arcDistance에
  // 가장 가까운 픽셀을 고른다. 대각선에서는 칸 눈금 때문에 단순 내림한
  // 픽셀이 호에서 반 칸 벗어날 수 있어, 이웃 칸까지 보고 고른다.
  final offset = arcDistance * math.sqrt1_2;
  final startX = (center.dx + (left ? -offset : offset)).floor();
  final startY = (center.dy + (top ? -offset : offset)).floor();
  var bestX = startX;
  var bestY = startY;
  var bestGap = double.infinity;
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      final px = startX + dx;
      final py = startY + dy;
      final gap = ((Offset(px + 0.5, py + 0.5) - center).distance - arcDistance)
          .abs();
      if (gap < bestGap) {
        bestGap = gap;
        bestX = px;
        bestY = py;
      }
    }
  }
  return pixels.at(bestX, bestY);
}

double _distance(Color a, Color b) {
  final dr = (a.r - b.r) * 255;
  final dg = (a.g - b.g) * 255;
  final db = (a.b - b.b) * 255;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

/// [actual]이 카드 안쪽 바탕색([fill])이 아니라 테두리 색([border])으로
/// 칠해졌는지 본다. 안티앨리어싱 때문에 같은 색이 나오지는 않으므로
/// "테두리 색에 [maxDistance] 안쪽으로 가깝고, 바탕색보다 테두리 색에 더
/// 가깝다"로 판정한다.
void expectBorderColor(
  Color actual, {
  required Color border,
  required Color fill,
  required String where,
  double maxDistance = 12,
}) {
  final toBorder = _distance(actual, border);
  final toFill = _distance(actual, fill);
  expect(
    toBorder <= maxDistance && toBorder < toFill,
    isTrue,
    reason:
        '$where: 모서리 호의 색이 테두리가 아니다 '
        '(실제 $actual, 테두리 $border까지 ${toBorder.toStringAsFixed(1)}, '
        '바탕 $fill까지 ${toFill.toStringAsFixed(1)})',
  );
}
