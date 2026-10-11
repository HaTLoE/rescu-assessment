import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/shared_widget/the_network_image.dart';

void main() {
  group('decodeSizeForBox', () {
    test('a box wider than 4:3 is limited by its width', () {
      final size = decodeSizeForBox(
        boxWidth: 380,
        boxHeight: 160,
        devicePixelRatio: 2,
      );

      expect(size, (width: 760, height: null));
    });

    test('a square box is limited by its height', () {
      final size = decodeSizeForBox(
        boxWidth: 64,
        boxHeight: 64,
        devicePixelRatio: 2,
      );

      expect(size, (width: null, height: 128));
    });

    test('a box of exactly 4:3 is limited by its width', () {
      final size = decodeSizeForBox(
        boxWidth: 400,
        boxHeight: 300,
        devicePixelRatio: 1,
      );

      expect(size, (width: 400, height: null));
    });

    test('a box only slightly wider than tall is limited by its height', () {
      // The deal details header on a narrow phone: wider than tall, but not
      // as wide as the 4:3 image. Limiting by width would stretch it.
      final size = decodeSizeForBox(
        boxWidth: 320,
        boxHeight: 264,
        devicePixelRatio: 1,
      );

      expect(size, (width: null, height: 264));
    });

    test('a fraction of a pixel is rounded up, never down', () {
      final size = decodeSizeForBox(
        boxWidth: 100.4,
        boxHeight: 50,
        devicePixelRatio: 2.625,
      );

      expect(size, (width: 264, height: null));
    });

    test('an unknown side is ignored and the known one is used', () {
      expect(
        decodeSizeForBox(
            boxWidth: double.infinity, boxHeight: 90, devicePixelRatio: 2),
        (width: null, height: 180),
      );
      expect(
        decodeSizeForBox(
            boxWidth: 200, boxHeight: double.infinity, devicePixelRatio: 2),
        (width: 400, height: null),
      );
    });

    test('with no known side the image keeps its full size', () {
      final size = decodeSizeForBox(
        boxWidth: double.infinity,
        boxHeight: double.infinity,
        devicePixelRatio: 2,
      );

      expect(size, (width: null, height: null));
    });

    test('the decoded 4:3 image always covers the box, for every app usage',
        () {
      // (width, height) in logical points of every place TheNetworkImage is
      // used, on a narrow and a wide phone.
      const boxes = [
        (288.0, 160.0), // feed card, 320-wide phone
        (379.0, 160.0), // feed card, 411-wide phone
        (192.0, 90.0), // flash rail
        (320.0, 264.0), // details header, narrow phone
        (411.0, 288.0), // details header, wide phone
        (64.0, 64.0), // order and cart thumbnails
      ];
      const ratio = 2.625;

      for (final (boxWidth, boxHeight) in boxes) {
        final size = decodeSizeForBox(
          boxWidth: boxWidth,
          boxHeight: boxHeight,
          devicePixelRatio: ratio,
        );
        // Work out the other side from the 4:3 shape.
        final decodedWidth = size.width ?? size.height! * apiImageAspectRatio;
        final decodedHeight = size.height ?? size.width! / apiImageAspectRatio;

        expect(decodedWidth, greaterThanOrEqualTo(boxWidth * ratio),
            reason: '$boxWidth x $boxHeight would be stretched sideways');
        expect(decodedHeight, greaterThanOrEqualTo(boxHeight * ratio),
            reason: '$boxWidth x $boxHeight would be stretched vertically');
      }
    });
  });

  /// Pumps [image] inside a box of the given size, on a screen with a device
  /// pixel ratio of 2 (one logical point = 2 real pixels), and returns the
  /// CachedNetworkImage it built.
  Future<CachedNetworkImage> pumpInBox(
    WidgetTester tester, {
    required double boxWidth,
    required double boxHeight,
    required TheNetworkImage image,
  }) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(width: boxWidth, height: boxHeight, child: image),
      ),
    ));
    return tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
  }

  testWidgets('a wide box (like a feed card) is decoded at its width',
      (tester) async {
    final built = await pumpInBox(
      tester,
      boxWidth: 380,
      boxHeight: 160,
      image: const TheNetworkImage(
        url: 'https://example.com/a.jpg',
        width: double.infinity,
        height: 160,
      ),
    );

    expect(built.memCacheWidth, 760);
    expect(built.memCacheHeight, isNull);
  });

  testWidgets('a square thumbnail is decoded at its height', (tester) async {
    final built = await pumpInBox(
      tester,
      boxWidth: 64,
      boxHeight: 64,
      image: const TheNetworkImage(
        url: 'https://example.com/a.jpg',
        width: 64,
        height: 64,
      ),
    );

    expect(built.memCacheWidth, isNull);
    expect(built.memCacheHeight, 128);
  });

  testWidgets('an image with no size of its own uses the box it is given',
      (tester) async {
    final built = await pumpInBox(
      tester,
      boxWidth: 400,
      boxHeight: 250,
      image: const TheNetworkImage(url: 'https://example.com/a.jpg'),
    );

    expect(built.memCacheWidth, 800);
    expect(built.memCacheHeight, isNull);
  });
}
