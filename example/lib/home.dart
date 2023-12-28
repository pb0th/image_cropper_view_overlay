import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:image_cropper_view_overlay/image_cropper_view_overlay.dart';
import 'package:image_picker/image_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Uint8List?> results = [];
  // Initial position of the crop area
  final ImagePicker picker = ImagePicker();

  Future<void> selectAndCropImages() async {
    final List<XFile?> xImages = await picker.pickMultiImage();

    if (xImages.isNotEmpty) {
      for (var xImage in xImages) {
        File imageFile = File(xImage!.path);
        if (context.mounted) {
          Uint8List? result = await ImageCropperViewOverlay.cropImage(
              context: context,
              image: Image.file(imageFile),
              clipShape: ClipShape.circle,
              overlayImage: Image.asset(
                "assets/crop_avatar.png",
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width * 0.8,
              ));

          if (result != null) {
            setState(() {
              results = [...results, result];
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double imgHeight = MediaQuery.of(context).size.width / 3 - 20.0;
    return Scaffold(
        appBar: AppBar(
          title: const Text('Image Cropper'),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Column(
                children: [
                  ElevatedButton(
                      onPressed: () async {
                        await selectAndCropImages();
                      },
                      child: const Text("Select image")),
                  results.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: GridView.builder(
                              shrinkWrap: true,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10.0,
                                mainAxisSpacing: 10.0,
                              ),
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Image.memory(
                                    results[index]!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: imgHeight,
                                  ),
                                );
                              }),
                        )
                      : Container()
                ],
              )
            ],
          ),
        ));
  }
}
