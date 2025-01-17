import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'fast_cached_image_config.dart';
import 'image_response.dart';
import 'models/fast_cache_progress_data.dart';

class FastCachedImage extends StatefulWidget {
  ///Provide the [url] for the image to display.
  final String url;

  ///[errorBuilder] must return a widget. This widget will be displayed if there is any error in downloading or displaying
  ///the downloaded image
  final ImageErrorWidgetBuilder? errorBuilder;

  ///[loadingBuilder] is the builder which can show the download progress of an image.

  ///Usage: loadingBuilder(context, FastCachedProgressData progressData){return  Text('${progress.downloadedBytes ~/ 1024} / ${progress.totalBytes! ~/ 1024} kb')}
  final Widget Function(BuildContext, FastCachedProgressData)? loadingBuilder;

  ///[fadeInDuration] can be adjusted to change the duration of the fade transition between the [loadingBuilder]
  ///and the actual image. Default value is 500 ms.
  final Duration fadeInDuration;

  /// If [cacheWidth] or [cacheHeight] are provided, it indicates to the
  /// engine that the image must be decoded at the specified size. The image
  /// will be rendered to the constraints of the layout or [width] and [height]
  /// regardless of these parameters. These parameters are primarily intended
  /// to reduce the memory usage of [ImageCache].
  /// If non-null, this color is blended with each image pixel using [colorBlendMode].
  /// If the image is of a high quality and its pixels are perfectly aligned
  /// with the physical screen pixels, extra quality enhancement may not be
  /// necessary. If so, then [FilterQuality.none] would be the most efficient.
  ///[width] width of the image
  final double? width;

  ///[height] of the image
  final double? height;

  ///[scale] property in Flutter memory image.
  final double scale;

  ///[color] property in Flutter memory image.
  final Color? color;

  ///[opacity] property in Flutter memory image.
  final Animation<double>? opacity;

  /// If the pixels are not perfectly aligned with the screen pixels, or if the
  /// image itself is of a low quality, [FilterQuality.none] may produce
  /// undesirable artifacts. Consider using other [FilterQuality] values to
  /// improve the rendered image quality in this case. Pixels may be misaligned
  /// with the screen pixels as a result of transforms or scaling.
  /// [opacity] can be used to adjust the opacity of the image.
  /// Used to combine [color] with this image.
  final FilterQuality filterQuality;

  ///[colorBlendMode] property in Flutter memory image
  final BlendMode? colorBlendMode;

  ///[fit] How a box should be inscribed into another box
  final BoxFit? fit;

  /// The alignment aligns the given position in the image to the given position
  /// in the layout bounds. For example, an [Alignment] alignment of (-1.0,
  /// -1.0) aligns the image to the top-left corner of its layout bounds, while an
  /// [Alignment] alignment of (1.0, 1.0) aligns the bottom right of the
  /// image with the bottom right corner of its layout bounds. Similarly, an
  /// alignment of (0.0, 1.0) aligns the bottom middle of the image with the
  /// middle of the bottom edge of its layout bounds.
  final AlignmentGeometry alignment;

  ///[repeat] property in Flutter memory image.
  final ImageRepeat repeat;

  ///[centerSlice] property in Flutter memory image.
  final Rect? centerSlice;

  ///[matchTextDirection] property in Flutter memory image.
  final bool matchTextDirection;

  /// Whether to continue showing the old image (true), or briefly show nothing
  /// (false), when the image provider changes. The default value is false.
  ///
  /// ## Design discussion
  ///
  /// ### Why is the default value of [gaplessPlayback] false?
  ///
  /// Having the default value of [gaplessPlayback] be false helps prevent
  /// situations where stale or misleading information might be presented.
  /// Consider the following case:
  final bool gaplessPlayback;

  ///[semanticLabel] property in Flutter memory image.
  final String? semanticLabel;

  ///[excludeFromSemantics] property in Flutter memory image.
  final bool excludeFromSemantics;

  ///[isAntiAlias] property in Flutter memory image.
  final bool isAntiAlias;

  ///[disableErrorLogs] can be set to true if you want to ignore error logs from the widget
  final bool disableErrorLogs;

  final Map<String, String>? httpHeaders;

  ///[FastCachedImage] creates a widget to display network images. This widget downloads the network image
  ///when this widget is build for the first time. Later whenever this widget is called the image will be displayed from
  ///the downloaded database instead of the network. This can avoid unnecessary downloads and load images much faster.
  const FastCachedImage({
    required this.url,
    this.scale = 1.0,
    this.errorBuilder,
    this.semanticLabel,
    this.loadingBuilder,
    this.excludeFromSemantics = false,
    this.disableErrorLogs = false,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.httpHeaders,
    int? cacheWidth,
    int? cacheHeight,
    super.key,
  });

  @override
  State<FastCachedImage> createState() => _FastCachedImageState();
}

class _FastCachedImageState extends State<FastCachedImage>
    with TickerProviderStateMixin {
  ///[_imageResponse] not public API.
  ImageResponse? _imageResponse;

  ///[_animation] not public API.
  late Animation<double> _animation;

  ///[_animationController] not public API.
  late AnimationController _animationController;

  ///[_progressData] holds the data indicating the progress of download.
  late FastCachedProgressData _progressData;

  @override
  void initState() {
    _animationController =
        AnimationController(vsync: this, duration: widget.fadeInDuration);
    _animation = Tween<double>(
        begin: widget.fadeInDuration == Duration.zero ? 1 : 0, end: 1)
        .animate(_animationController);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _loadAsync(widget.url);
      _animationController
          .addStatusListener((status) => _animationListener(status));
    });

    _progressData = FastCachedProgressData(
        progressPercentage: ValueNotifier(0),
        totalBytes: null,
        downloadedBytes: 0,
        isDownloading: false);
    super.initState();
  }

  void _animationListener(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        mounted &&
        widget.fadeInDuration != Duration.zero) setState(() => {});
  }

  @override
  void dispose() {
    _animationController.removeListener(() => {});
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_imageResponse?.error != null && widget.errorBuilder != null) {
      _logErrors(_imageResponse?.error);
      return widget.errorBuilder!(
          context, Object, StackTrace.fromString(_imageResponse!.error!));
    }

    return SizedBox(
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.passthrough,
        children: [
          if (_animationController.status != AnimationStatus.completed)
          // (widget.loadingBuilder != null)
          // ? widget.loadingBuilder!(context)
          // :
            (widget.loadingBuilder != null)
                ? ValueListenableBuilder(
                valueListenable: _progressData.progressPercentage,
                builder: (context, p, c) {
                  return widget.loadingBuilder!(context, _progressData);
                })
                : const SizedBox(),
          if (_imageResponse != null)
            FadeTransition(
              opacity: _animation,
              child: Image.memory(
                _imageResponse!.imageData,
                color: widget.color,
                width: widget.width,
                height: widget.height,
                alignment: widget.alignment,
                key: widget.key,
                fit: widget.fit,
                errorBuilder: (a, c, v) {
                  if (_animationController.status !=
                      AnimationStatus.completed) {
                    _animationController.forward();
                    _logErrors(c);
                    FastCachedImageConfig.deleteCachedImage(
                        imageUrl: widget.url);
                  }
                  return widget.errorBuilder != null
                      ? widget.errorBuilder!(a, c, v)
                      : const SizedBox();
                },
                centerSlice: widget.centerSlice,
                colorBlendMode: widget.colorBlendMode,
                excludeFromSemantics: widget.excludeFromSemantics,
                filterQuality: widget.filterQuality,
                gaplessPlayback: widget.gaplessPlayback,
                isAntiAlias: widget.isAntiAlias,
                matchTextDirection: widget.matchTextDirection,
                opacity: widget.opacity,
                repeat: widget.repeat,
                scale: widget.scale,
                semanticLabel: widget.semanticLabel,
                frameBuilder: (widget.loadingBuilder != null)
                    ? (context, a, b, c) {
                  if (b == null) {
                    return widget.loadingBuilder!(
                        context,
                        FastCachedProgressData(
                            progressPercentage:
                            _progressData.progressPercentage,
                            totalBytes: _progressData.totalBytes,
                            downloadedBytes:
                            _progressData.downloadedBytes,
                            isDownloading: false));
                  }

                  if (_animationController.status !=
                      AnimationStatus.completed) {
                    _animationController.forward();
                  }
                  return a;
                }
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  ///[_loadAsync] Not public API.
  Future<void> _loadAsync(url) async {
    FastCachedImageConfig.checkInit();
    Uint8List? image = await FastCachedImageConfig.getImage(url);

    if (!mounted) return;

    if (image != null) {
      setState(
              () => _imageResponse = ImageResponse(imageData: image, error: null));
      if (widget.loadingBuilder == null) _animationController.forward();

      return;
    }

    StreamController chunkEvents = StreamController();

    try {
      final Uri resolved = Uri.base.resolve(url);
      Dio dio = Dio();

      if (!mounted) return;

      //set is downloading flag to true
      _progressData.isDownloading = true;
      if (widget.loadingBuilder != null) {
        widget.loadingBuilder!(context, _progressData);
      }
      Response response = await dio.get(url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: widget.httpHeaders
              ?..remove(HttpHeaders.contentTypeHeader)
              ..remove(HttpHeaders.acceptHeader),
          ), onReceiveProgress: (int received, int total) {
            if (received < 0 || total < 0) return;
            if (widget.loadingBuilder != null) {
              _progressData.downloadedBytes = received;
              _progressData.totalBytes = total;
              double.parse((received / total).toStringAsFixed(2));
              // _progress.value = tot != null ? _downloaded / _total! : 0;
              _progressData.progressPercentage.value =
                  double.parse((received / total).toStringAsFixed(2));
              widget.loadingBuilder!(context, _progressData);
            }

            chunkEvents.add(ImageChunkEvent(
              cumulativeBytesLoaded: received,
              expectedTotalBytes: total,
            ));
          });

      final Uint8List bytes = response.data;

      if (response.statusCode != 200) {
        String error = NetworkImageLoadException(
            statusCode: response.statusCode ?? 0, uri: resolved)
            .toString();
        if (mounted) {
          setState(() => _imageResponse =
              ImageResponse(imageData: Uint8List.fromList([]), error: error));
        }
        return;
      }

      //set is downloading flag to false
      _progressData.isDownloading = false;

      if (bytes.isEmpty && mounted) {
        setState(() => _imageResponse =
            ImageResponse(imageData: bytes, error: 'Image is empty.'));
        return;
      }
      if (mounted) {
        setState(() =>
        _imageResponse = ImageResponse(imageData: bytes, error: null));
        if (widget.loadingBuilder == null) _animationController.forward();
      }

      await FastCachedImageConfig.saveImage(url, bytes);
    } catch (e) {
      if (mounted) {
        setState(() => _imageResponse = ImageResponse(
            imageData: Uint8List.fromList([]), error: e.toString()));
      }
    } finally {
      if (!chunkEvents.isClosed) await chunkEvents.close();
    }
  }

  void _logErrors(dynamic object) {
    if (!widget.disableErrorLogs) {
      debugPrint('$object - Image url : ${widget.url}');
    }
  }
}