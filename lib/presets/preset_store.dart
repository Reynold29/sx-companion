import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

class PresetStore extends ChangeNotifier {
  List<SongPreset> songs = [];
  bool loaded = false;
  bool _alive = true;

  @override
  void notifyListeners() {
    if (!_alive) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/song_presets.json');
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is List) {
          songs = [
            for (final item in json)
              if (item is Map<String, dynamic>) SongPreset.fromJson(item),
          ];
        }
      }
    } catch (_) {
      songs = [];
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> persist() async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode([for (final song in songs) song.toJson()]),
      flush: true,
    );
    notifyListeners();
  }

  Future<SongPreset> createSong(String name) async {
    final song = SongPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      parts: [
        SongPart(id: 'p1', name: 'Intro', role: 'intro', styleSection: 0x00),
        SongPart(id: 'p2', name: 'Main', role: 'main', styleSection: 0x08),
        SongPart(id: 'p3', name: 'Outro', role: 'outro', styleSection: 0x20),
      ],
    );
    songs.add(song);
    await persist();
    return song;
  }

  Future<void> deleteSong(String id) async {
    songs.removeWhere((song) => song.id == id);
    await persist();
  }

  Future<File> clipFile(String clipId) async {
    final dir = await getApplicationDocumentsDirectory();
    final clips = Directory('${dir.path}/clips');
    await clips.create(recursive: true);
    return File('${clips.path}/$clipId.mid');
  }

  Future<Uint8List?> loadClip(String? clipId) async {
    if (clipId == null || clipId.isEmpty) return null;
    final file = await clipFile(clipId);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> saveClip(String clipId, Uint8List bytes) async {
    final file = await clipFile(clipId);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> deleteClip(String? clipId) async {
    if (clipId == null) return;
    final file = await clipFile(clipId);
    if (await file.exists()) await file.delete();
  }

  Future<void> upsert(SongPreset song) async {
    final index = songs.indexWhere((item) => item.id == song.id);
    if (index >= 0) {
      songs[index] = song;
    } else {
      songs.add(song);
    }
    await persist();
  }
}
