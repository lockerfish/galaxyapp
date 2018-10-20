import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

class GalaxyData {
  final DocumentReference reference;
  String title;
  String nasaId;
  String center;
  String reservedBy;
  String profilePicture;
  final String defaultImage =
      "https://firebasestorage.googleapis.com/v0/b/gallaxyinvader.appspot.com/o/potw1827a.jpg?alt=media&token=10cabf12-6e8e-40ad-a34a-443ee3a95295";

  GalaxyData.data(this.reference,
      [this.title,
      this.nasaId,
      this.center,
      this.reservedBy,
      this.profilePicture]) {
    this.title ??= 'The Galaxies';
    // this.nasaId ??= '';
    // this.center ??= '';
    this.profilePicture ??= defaultImage;
  }

  factory GalaxyData.from(DocumentSnapshot document) => GalaxyData.data(
        document.reference,
        document.data['title'],
        document.data['nasaId'],
        document.data['center'],
        document.data['reservedBy'],
        document.data['profilePicture'],
      );

  void save() {
    reference.setData(toMap());
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'nasaId': nasaId,
      'center': center,
      'reservedBy': reservedBy,
      'profilePicture': profilePicture,
    };
  }
}

class LocalAudioTools {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, String> _nameToPath = {};

  Future loadFile(String name) async {
    final bytes = await rootBundle.load('assets/$name');
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');

    await file.writeAsBytes(new Uint8List.view(bytes.buffer));
    if (await file.exists()) _nameToPath[name] = file.path;
  }

  void playAudioLoop(String name) async {
    // restart audio if it has finished
    await _audioPlayer.setReleaseMode(ReleaseMode.STOP);
    // _audioPlayer.setCompletionHandler(() => playAudio(name));
    playAudio(name);
  }

  Future<Null> playAudio(String name) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(_nameToPath[name], isLocal: true);
  }
}
