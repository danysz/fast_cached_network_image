import 'package:flutter/foundation.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:uuid/uuid.dart';

import 'box_names.dart';

class FastCachedImageConfig {
  static LazyBox? _imageKeyBox;
  static LazyBox? _imageBox;
  static bool _isInitialized = false;
  static const String _notInitMessage =
      'FastCachedImage is not initialized. Please use FastCachedImageConfig.init to initialize FastCachedImage';

  ///[init] function initializes the cache management system. Use this code only once in the app in main to avoid errors.
  /// You can provide a [subDir] where the boxes should be stored.
  ///[clearCacheAfter] property is used to set a  duration after which the cache will be cleared.
  ///Default value of [clearCacheAfter] is 7 days which means if [clearCacheAfter] is set to null,
  /// an image cached today will be cleared when you open the app after 7 days from now.
  static Future<void> init({String? subDir, Duration? clearCacheAfter}) async {
    if (_isInitialized) return;

    clearCacheAfter ??= const Duration(days: 7);

    await Hive.initFlutter(subDir);
    _isInitialized = true;

    _imageKeyBox = await Hive.openLazyBox(BoxNames.imagesKeyBox);
    _imageBox = await Hive.openLazyBox(BoxNames.imagesBox);
    await clearOldCache(clearCacheAfter);
  }

  static Future<Uint8List?> getImage(String url) async {
    final key = _keyFromUrl(url);
    if (_imageKeyBox!.keys.contains(url) && _imageBox!.containsKey(url)) {
      // Migrating old keys to new keys
      await replaceImageKey(oldKey: url, newKey: key);
      await replaceOldImage(oldKey: url, newKey: key, image: await _imageBox!.get(url));
    }

    if (_imageKeyBox!.keys.contains(key) && _imageBox!.keys.contains(key)) {
      Uint8List? data = await _imageBox!.get(key);
      if (data == null || data.isEmpty) return null;

      return data;
    }

    return null;
  }

  ///[_saveImage] is to save an image to cache. Not part of public API.
  static Future<void> saveImage(String url, Uint8List image) async {
    final key = _keyFromUrl(url);

    await _imageKeyBox!.put(key, DateTime.now());
    await _imageBox!.put(key, image);
  }

  ///[_clearOldCache] clears the old cache. Not part of public API.
  static Future<void> clearOldCache(Duration cleatCacheAfter) async {
    DateTime today = DateTime.now();

    for (final key in _imageKeyBox!.keys) {
      DateTime? dateCreated = await _imageKeyBox!.get(key);

      if (dateCreated == null) continue;

      if (today.difference(dateCreated) > cleatCacheAfter) {
        await _imageKeyBox!.delete(key);
        await _imageBox!.delete(key);
      }
    }
  }

  static Future<void> replaceImageKey(
      {required String oldKey, required String newKey}) async {
    checkInit();

    DateTime? dateCreated = await _imageKeyBox!.get(oldKey);

    if (dateCreated == null) return;

    _imageKeyBox!.delete(oldKey);
    _imageKeyBox!.put(newKey, dateCreated);
  }

  static Future<void> replaceOldImage({
    required String oldKey,
    required String newKey,
    required Uint8List image,
  }) async {
    await _imageBox!.delete(oldKey);
    await _imageBox!.put(newKey, image);
  }

  ///[deleteCachedImage] function takes in a image [imageUrl] and removes the image corresponding to the url
  /// from the cache if the image is present in the cache.
  static Future<void> deleteCachedImage(
      {required String imageUrl, bool showLog = true}) async {
    checkInit();

    final key = _keyFromUrl(imageUrl);
    if (_imageKeyBox!.keys.contains(key) && _imageBox!.keys.contains(key)) {
      await _imageKeyBox!.delete(key);
      await _imageBox!.delete(key);
      if (showLog) {
        debugPrint('FastCacheImage: Removed image $imageUrl from cache.');
      }
    }
  }

  ///[clearAllCachedImages] function clears all cached images. This can be used in scenarios such as
  ///logout functionality of your app, so that all cached images corresponding to the user's account is removed.
  static Future<void> clearAllCachedImages({bool showLog = true}) async {
    checkInit();
    await _imageKeyBox!.deleteFromDisk();
    await _imageBox!.deleteFromDisk();
    if (showLog) debugPrint('FastCacheImage: All cache cleared.');
    _imageKeyBox = await Hive.openLazyBox(BoxNames.imagesKeyBox);
    _imageBox = await Hive.openLazyBox(BoxNames.imagesBox);
  }

  ///[_checkInit] method ensures the hive db is initialized. Not part of public API
  static void checkInit() {
    if ((FastCachedImageConfig._imageKeyBox == null ||
        !FastCachedImageConfig._imageKeyBox!.isOpen) ||
        FastCachedImageConfig._imageBox == null ||
        !FastCachedImageConfig._imageBox!.isOpen) {
      throw Exception(_notInitMessage);
    }
  }

  ///[isCached] returns a boolean indicating whether the given image is cached or not.
  ///Returns true if cached, false if not.
  static bool isCached({required String imageUrl}) {
    checkInit();

    final key = _keyFromUrl(imageUrl);
    if (_imageKeyBox!.containsKey(key) && _imageBox!.keys.contains(key)) {
      return true;
    }
    return false;
  }

  static _keyFromUrl(String url) => const Uuid().v5(Uuid.NAMESPACE_URL, url);
}
