import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';
import '../data/recipe_database.dart';

/// Hybrid recipe storage:
///
///   1. Firestore `recipes` collection is the remote source of truth.
///   2. Firestore's built-in offline persistence caches reads on-device,
///      so once recipes have been fetched once, they're available offline
///      automatically — no manual cache layer needed.
///   3. The bundled RecipeDatabase list is the last-resort fallback
///      (fresh install with no internet, or an empty collection).
///
/// The refresh button on the recipe screen calls [refreshFromServer],
/// which requires internet and force-fetches the latest data. On the very
/// first refresh, if the collection is empty, it is seeded from the
/// bundled list so there's always something remote to fetch.
class RecipeRepository {
  static final CollectionReference _col =
      FirebaseFirestore.instance.collection('recipes');

  /// Loads recipes for display. Order of preference:
  /// local Firestore cache -> server -> bundled list.
  static Future<List<Recipe>> loadRecipes() async {
    // 1. Try the local cache first — instant and works offline.
    try {
      final cached = await _col.get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty) return _fromDocs(cached.docs);
    } catch (_) {
      // Cache miss throws on some platforms — fall through.
    }

    // 2. Try the server (first run with internet).
    try {
      final server = await _col.get();
      if (server.docs.isNotEmpty) return _fromDocs(server.docs);
    } catch (_) {
      // Offline and no cache — fall through.
    }

    // 3. Bundled fallback — the app always has recipes to show.
    return RecipeDatabase.recipes;
  }

  /// Force-fetches the latest recipes from the server (requires internet).
  /// Seeds the collection from the bundled list if it's empty, so the
  /// remote source exists from the first refresh onward. Firestore's
  /// persistence caches the result automatically for offline use.
  static Future<List<Recipe>> refreshFromServer() async {
    var server = await _col.get(const GetOptions(source: Source.server));

    if (server.docs.isEmpty) {
      await _seedFromBundle();
      server = await _col.get(const GetOptions(source: Source.server));
    }

    return _fromDocs(server.docs);
  }

  /// One-time upload of the bundled recipes into Firestore.
  /// Firestore batches are limited to 500 writes, so chunk if needed.
  static Future<void> _seedFromBundle() async {
    const chunkSize = 400;
    final all = RecipeDatabase.recipes;

    for (var i = 0; i < all.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      for (final recipe
          in all.sublist(i, (i + chunkSize).clamp(0, all.length))) {
        batch.set(_col.doc(recipe.id), recipe.toMap());
      }
      await batch.commit();
    }
  }

  static List<Recipe> _fromDocs(List<QueryDocumentSnapshot> docs) {
    return docs
        .map((d) => Recipe.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }
}