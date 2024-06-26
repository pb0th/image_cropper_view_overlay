import 'dart:async';

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'clipper.dart';
import 'dart:math' as math;

class Cropper extends StatefulWidget {
  const Cropper({
    Key? key,
    required this.image,
    this.overlayWidget,
    required this.fit,
    required this.exportSize,
    this.exportBackgroundColor,
    required this.clipShape,
    required this.clipImage,
    required this.clipRRectRadius,
  }) : super(key: key);
  final Widget? overlayWidget;
  final Image image;
  final Size exportSize;
  final BoxFit fit;
  final Color? exportBackgroundColor;
  final bool clipImage;
  final ClipShape clipShape;
  final Radius clipRRectRadius;

  @override
  State<Cropper> createState() => _CropperState();
}

class _CropperState extends State<Cropper> {
  Matrix4 sessionMatrix = Matrix4.identity();
  Matrix4 matrix = Matrix4.identity();
  ui.Image? bitImage;
  Size? clipSize;
  Matrix4? txMatrix;
  Offset initialFocalPoint = Offset.zero;

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      loadImage();
    });
  }

  loadImage() async {
    var img = await getImageData();
    setState(() {
      bitImage = img;
    });
  }

  // get image data from underlying image
  Future<ui.Image> getImageData() async {
    var completer = Completer<ui.Image>();
    widget.image.image.resolve(ImageConfiguration.empty).addListener(
          ImageStreamListener(
            (ImageInfo info, _) => completer.complete(info.image),
          ),
        );
    return completer.future;
  }

  Widget _buildImageView(
    BuildContext context,
    Size clipSize,
    Size viewSize,
    Matrix4 txMatrix,
  ) {
    // These two are used in image export
    this.clipSize = clipSize;
    this.txMatrix = txMatrix;

    var clipExportRatio = clipSize.width / widget.exportSize.width;
    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.topLeft,
        children: [
          Positioned(
            left: viewSize.width / 2,
            top: viewSize.height / 2,
            child: Transform(
              transform: txMatrix,
              alignment: Alignment.topLeft,
              child: widget.image,
            ),
          ),
          // Center(
          //   child: widget.overlayImage,
          // ),

          // black overlay on image
          ClipPath(
            clipper: InvertedClipper(
              clipSize: clipSize,
              shape: widget.clipShape,
              rrectRadius: widget.clipRRectRadius * clipExportRatio,
            ),
            child: Container(
              color: Colors.black54,
            ),
          ),

          Center(
            child: Container(
                  width: clipSize.width * 0.7,
                  child: widget.overlayWidget,
                ) ??
                SizedBox(),
          ),
        ],
      ),
    );
  }

  _cancelEdit() {
    Navigator.pop(context);
  }

  _vFlipImage() {
    setState(() {
      var xf = Matrix4.identity()..scale(1.0, -1.0);
      matrix = xf * matrix;
    });
  }

  _hFlipImage() {
    setState(() {
      var xf = Matrix4.identity()..scale(-1.0, 1.0);
      matrix = xf * matrix;
    });
  }

  _rotateImage(double angle) {
    setState(() {
      var xf = Matrix4.identity()..rotateZ(angle);
      matrix = xf * matrix;
    });
  }

  _saveEdit() async {
    var edited = await _exportImage();
    Navigator.pop(
      context,
      edited,
    );
  }

  _onScaleStart(ScaleStartDetails d) {
    initialFocalPoint = d.focalPoint;
  }

  _onScaleUpdate(ScaleUpdateDetails d) {
    try {
      var center = context.size!.center(Offset.zero);
      var focal = d.localFocalPoint.translate(-center.dx, -center.dy);
      var focalDelta = d.focalPoint - initialFocalPoint;

      Matrix4 tempSessionMatrix = Matrix4.identity()
        ..translate(focal.dx, focal.dy)
        ..scale(d.scale)
        // ..rotateZ(d.rotation)
        ..translate(focalDelta.dx, focalDelta.dy)
        ..translate(-focal.dx, -focal.dy);

      Matrix4 tempMatrix = matrix * tempSessionMatrix;
      double? newScale = tempMatrix.getMaxScaleOnAxis() >= 0.9 ? d.scale : null;
      // print(focal.dx);
      setState(() {
        sessionMatrix = Matrix4.identity()
          ..translate(focal.dx, focal.dy)
          ..scale(newScale)
          // ..rotateZ(d.rotation)
          ..translate(focalDelta.dx, focalDelta.dy)
          ..translate(-focal.dx, -focal.dy);
      });
    } catch (e) {}
  }

  _onScaleEnd(ScaleEndDetails d) {
    setState(() {
      // merge sessionMatrix into matrix
      matrix = sessionMatrix * matrix;
      sessionMatrix = Matrix4.identity();
    });
  }

  Future<Uint8List?> _exportImage() async {
    if (bitImage == null || clipSize == null || txMatrix == null) {
      throw 'Image cannot be loaded';
    }

    var exportSize = widget.exportSize;
    ui.PictureRecorder recorder = ui.PictureRecorder();

    Canvas canvas = Canvas(recorder);
    var exportRect = Rect.fromLTWH(
      0,
      0,
      exportSize.width.toDouble(),
      exportSize.height.toDouble(),
    );
    // draw background
    if (widget.exportBackgroundColor != null) {
      canvas.drawRect(
          exportRect, Paint()..color = widget.exportBackgroundColor!);
    }
    // clip export image
    if (widget.clipImage) {
      Path? path;
      if (widget.clipShape == ClipShape.circle) {
        path = Path()..addOval(exportRect);
      } else if (widget.clipShape == ClipShape.rrect) {
        path = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              exportRect,
              widget.clipRRectRadius,
            ),
          );
      }
      if (path != null) {
        canvas.clipPath(path);
      }
    }
    // exportSize may be quite bigger than clipSize, hence this final scale
    var exportScale = exportSize.width / clipSize!.width;
    // Scale clip box to the size of exportSize
    canvas.scale(exportScale);
    // Move origin to center of clip box
    canvas.translate(clipSize!.width / 2, clipSize!.height / 2);
    canvas.transform(txMatrix!.storage);
    canvas.drawImage(
      bitImage!,
      Offset.zero,
      Paint(),
    );

    // var exportSize = const Size(100, 100);
    var img = await recorder.endRecording().toImage(
          exportSize.width.floor(),
          exportSize.height.floor(),
        );
    ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    Uint8List? result = byteData?.buffer.asUint8List();
    return result;
  }

  Widget _buildClipper(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      var exportSize = widget.exportSize;
      var viewSize = constraints.biggest;
      var clipSize = constraints.deflate(const EdgeInsets.all(20)).biggest;
      // clipSize try to be as big as possible
      // while still keeps exportSize's ratio
      if (clipSize.aspectRatio > exportSize.aspectRatio) {
        clipSize = Size(
          clipSize.height * exportSize.aspectRatio,
          clipSize.height,
        );
      } else {
        clipSize = Size(
          clipSize.width,
          clipSize.width / exportSize.aspectRatio,
        );
      }
      // layoutMatrix ensure clipbox either cover or contain the image
      var layoutMatrix = _layoutImage(
        Size(
          bitImage!.width.toDouble(),
          bitImage!.height.toDouble(),
        ),
        clipSize,
        viewSize,
        widget.fit,
      );

      return GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: _buildImageView(
          context,
          clipSize,
          viewSize,
          sessionMatrix * matrix * layoutMatrix,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget imageView;
    if (bitImage != null) {
      imageView = _buildClipper(context);
    } else {
      imageView = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: imageView,
      bottomNavigationBar: Container(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: _cancelEdit,
              ),
              // IconButton(
              //   tooltip: 'Horizontal flip',
              //   onPressed: _hFlipImage,
              //   icon: const Icon(Icons.flip),
              // ),
              // IconButton(
              //   tooltip: 'Vertical flip',
              //   onPressed: _vFlipImage,
              //   icon: const RotatedBox(
              //     quarterTurns: 1,
              //     child: Icon(Icons.flip_rounded),
              //   ),
              // ),
              IconButton(
                tooltip: 'Rotate right',
                onPressed: () => _rotateImage(-math.pi / 2),
                icon: const Icon(
                  Icons.rotate_90_degrees_ccw,
                  color: Colors.white,
                ),
              ),
              IconButton(
                tooltip: 'Rotate left',
                onPressed: () => _rotateImage(math.pi / 2),
                icon: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..scale(-1.0, 1.0),
                  child: const Icon(
                    Icons.rotate_90_degrees_ccw,
                    color: Colors.white,
                  ),
                ),
              ),

              // IconButton(
              //   tooltip: 'Rotate',
              //   onPressed: () {},
              //   icon: const Icon(Icons.rotate_right),
              // ),
              // IconButton(
              //   tooltip: 'Zoom',
              //   onPressed: () {},
              //   icon: const Icon(Icons.zoom_in),
              // ),
              TextButton(
                  onPressed: _saveEdit,
                  child: const Text(
                    "Save",
                    style: TextStyle(color: Colors.amber, fontSize: 16),
                  ))
            ],
          ),
        ),
      ),
    );
  }
}

Matrix4 _layoutImage(
    Size imageSize, Size clipSize, Size viewSize, BoxFit layout) {
  Matrix4 mat = Matrix4.identity();
  var scale = 1.0;
  if (layout == BoxFit.contain) {
    if (imageSize.aspectRatio > clipSize.aspectRatio) {
      scale = clipSize.width / imageSize.width;
    } else {
      scale = clipSize.height / imageSize.height;
    }
  } else if (layout == BoxFit.cover) {
    if (imageSize.aspectRatio > clipSize.aspectRatio) {
      scale = clipSize.height / imageSize.height;
    } else {
      scale = clipSize.width / imageSize.width;
    }
  } else {
    throw 'Not supported BoxFit type';
  }
  mat.scale(scale);
  // Offset transform origin, so that origin is now at center of canvas
  mat.translate(
    -imageSize.width / 2,
    -imageSize.height / 2,
  );

  return mat;
}
