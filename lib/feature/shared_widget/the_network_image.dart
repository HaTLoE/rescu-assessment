import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shape (width / height) of the images the API serves. Every image URL asks
/// for 1600x1200 (see the picsum URLs in `fake_api_service.dart`), i.e. 4:3.
const double apiImageAspectRatio = 4 / 3;

/// The size to decode an image at, in real screen pixels. Only one of the two
/// is ever set, so the decoded image keeps its own shape.
typedef DecodeSize = ({int? width, int? height});

/// Works out how big an image needs to be decoded to fill a box of
/// [boxWidth] x [boxHeight] logical points with `BoxFit.cover`, without being
/// stretched.
///
/// - A box at least as wide as the image shape is limited by its width.
/// - A narrower box (square, tall) is limited by its height.
/// - A side that is not known (infinite) cannot be used; if neither is known
///   the image is decoded at its full size, as before.
DecodeSize decodeSizeForBox({
  required double boxWidth,
  required double boxHeight,
  required double devicePixelRatio,
}) {
  final hasWidth = boxWidth.isFinite && boxWidth > 0;
  final hasHeight = boxHeight.isFinite && boxHeight > 0;
  if (!hasWidth && !hasHeight) return (width: null, height: null);

  final useWidth =
      !hasHeight || (hasWidth && boxWidth / boxHeight >= apiImageAspectRatio);
  if (useWidth) {
    return (width: (boxWidth * devicePixelRatio).ceil(), height: null);
  }
  return (width: null, height: (boxHeight * devicePixelRatio).ceil());
}

/// Standard network image with a shimmer placeholder.
class TheNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const TheNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      // LayoutBuilder tells us how much room the image really has, so it can
      // be decoded at that size instead of the full 1600x1200.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth =
              width != null && width!.isFinite ? width! : constraints.maxWidth;
          final decodeSize = decodeSizeForBox(
            boxWidth: boxWidth,
            boxHeight: height ?? constraints.maxHeight,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          );
          return CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: decodeSize.width,
            memCacheHeight: decodeSize.height,
            placeholder: (context, _) => Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child:
                  Container(width: width, height: height, color: Colors.white),
            ),
            errorWidget: (context, _, __) => Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          );
        },
      ),
    );
  }
}
