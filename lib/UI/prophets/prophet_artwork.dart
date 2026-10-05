import 'package:flutter/material.dart';

class ProphetArtwork extends StatelessWidget {
  const ProphetArtwork({super.key, required this.asset, this.height = 140});
  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        asset,
        height: height,
        width: height,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => SizedBox(
          height: height,
          width: height,
          child: const Icon(Icons.menu_book_outlined, size: 64),
        ),
      ),
    ),
  );
}
