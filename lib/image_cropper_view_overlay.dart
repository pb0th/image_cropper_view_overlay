/// image_crop_view: A package that provides image cropping functionalities with added features.
///
/// This package is a modification of the `image_cropper_view_overlay` package
/// by [gliheng] (Original Package: https://pub.dev/packages/image_cropper_view, Original GitHub: https://github.com/gliheng).
///
/// Modifications:
/// - Added overlayImage feature to incorporate image overlays in the crop area.

library image_crop_view;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper_view_overlay/clipper.dart';
import 'package:image_cropper_view_overlay/cropper.dart';

export 'clipper.dart';
export 'cropper.dart';

class ImageCropperViewOverlay {
  static Future<Uint8List?> cropImage({
    required BuildContext context,
    required Image image,
    required ClipShape clipShape,
    Image? overlayImage,
    BoxFit fit = BoxFit.cover,
    Size exportSize = const Size(500, 500),
    Color? exportBackgroundColor,
    bool clipImage = false,
    Radius clipRRectRadius = const Radius.circular(10),
  }) async {
    Uint8List? result = await Navigator.of(context)
        .push<Uint8List>(MaterialPageRoute(builder: (contex) {
      return Cropper(
        image: image,
        exportSize: exportSize,
        clipShape: clipShape,
        overlayImage: overlayImage,
        fit: fit,
        clipImage: clipImage,
        clipRRectRadius: clipRRectRadius,
      );
    }));

    return result;
  }
}
