import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:simple_coverflow/simple_coverflow.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:sensors/sensors.dart';

import 'utils.dart';

FirebaseUser user;
const backgroundAudio = 'background.mp3';
const removedAudio = 'removed.mp3';
var audioTools = LocalAudioTools();

void main() async {
  user = await FirebaseAuth.instance.signInAnonymously();
  audioTools
      .loadFile(backgroundAudio)
      .then((_) => audioTools.playAudioLoop(backgroundAudio));
  audioTools.loadFile(removedAudio);
  runApp(MaterialApp(
    title: 'Flutter Demo',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: MyApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<GalaxyData> defaultGalaxy = [GalaxyData.data(null)];
    return StreamBuilder(
      stream: Firestore.instance.collection('galaxydb').snapshots(),
      builder: (_, AsyncSnapshot<QuerySnapshot> snapshot) {
        var documents = snapshot.data?.documents ?? [];
        var galaxies =
            documents.map((snapshot) => GalaxyData.from(snapshot)).toList();
        if (galaxies.length == 0) galaxies = defaultGalaxy;
        return GalaxyPage(galaxies);
      },
    );
  }
}

enum ViewType { available, reserved }

class GalaxyPage extends StatefulWidget {
  final List<GalaxyData> galaxies;
  GalaxyPage(this.galaxies);
  @override
  _GalaxyPageState createState() => _GalaxyPageState();
}

class _GalaxyPageState extends State<GalaxyPage> {
  GalaxyData _undoData;
  ViewType _viewType = ViewType.available;
  @override
  initState() {
    super.initState();
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (event.x.abs() >= 2 &&
          _undoData != null &&
          _viewType == ViewType.reserved) {
        _reserveGalaxy(_undoData);
        _undoData = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var filteredGalaxies = widget.galaxies.where((GalaxyData data) {
      if (_viewType == ViewType.available) {
        return data.reservedBy == null || data.reservedBy == user.uid;
      } else {
        return data.reservedBy == user.uid;
      }
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_viewType == ViewType.available
            ? 'Galaxy Invader'
            : 'Your Reserved Galaxy'),
      ),
      body: Container(
        color: Colors.indigo[900],
        child: GalaxyOptions(
            filteredGalaxies, _viewType, _reserveGalaxy, _removeGalaxy),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _viewType == ViewType.available ? 0 : 1,
        onTap: (int index) {
          setState(() {
            _viewType = index == 0 ? ViewType.available : ViewType.reserved;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
              title: Text('Available'), icon: Icon(Icons.home)),
          BottomNavigationBarItem(
              title: Text('Reserved'), icon: Icon(Icons.shopping_basket)),
        ],
      ),
    );
  }

  void _reserveGalaxy(GalaxyData galaxyOfInterest) {
    galaxyOfInterest.reservedBy = user.uid;
    setState(() => galaxyOfInterest.save());
  }

  void _removeGalaxy(GalaxyData galaxyOfInterest) {
    audioTools.playAudio(removedAudio);
    galaxyOfInterest.reservedBy = null;
    setState(() {
      _undoData = galaxyOfInterest;
      galaxyOfInterest.save();
    });
  }
}

class GalaxyOptions extends StatelessWidget {
  final List<GalaxyData> galaxies;
  final Function onAddedCallback;
  final Function onRemovedCallback;
  final ViewType viewType;

  GalaxyOptions(this.galaxies, this.viewType, this.onAddedCallback,
      this.onRemovedCallback);

  @override
  Widget build(BuildContext context) {
    return CoverFlow(
      dismissibleItems: viewType == ViewType.reserved,
      dismissedCallback: (int index, _) => onRemovedCallback(galaxies[index]),
      itemBuilder: (_, int index) {
        var galaxyOfInterest =
            galaxies.isEmpty ? GalaxyData.data(null) : galaxies[index];
        var isReserved = galaxyOfInterest.reservedBy == user.uid;
        return ProfileCard(
          galaxyOfInterest,
          viewType,
          () => onAddedCallback(galaxyOfInterest),
          () => onRemovedCallback(galaxyOfInterest),
          isReserved,
        );
      },
      itemCount: galaxies.length,
    );
  }
}

class ProfileCard extends StatelessWidget {
  final GalaxyData data;
  final ViewType viewType;
  final Function onAddedCallback;
  final Function onRemovedCallback;
  final bool isReserved;

  ProfileCard(this.data, this.viewType, this.onAddedCallback,
      this.onRemovedCallback, this.isReserved);

  @override
  Widget build(BuildContext context) {
    return Card(child: _getCardContents());
  }

  Widget _getCardContents() {
    var contents = [
      Expanded(child: _showProfilePicture(data)),
      _showData(data.title, data.nasaId, data.center),
    ];
    var children = _wrapInScrimAndExpand(Column(children: contents));
    if (viewType == ViewType.available) {
      children.add(_showButton());
    }
    return Column(children: children);
  }

  Widget _showProfilePicture(GalaxyData galaxyData) {
    return FadeInImage.memoryNetwork(
      placeholder: kTransparentImage,
      image: galaxyData.profilePicture,
      fit: BoxFit.cover,
    );
  }

  Widget _showData(String title, String nasaId, String center) {
    var subHeadingStyle =
        TextStyle(fontStyle: FontStyle.italic, fontSize: 16.0);
    var titleWidget = Padding(
      padding: EdgeInsets.all(8.0),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32.0),
        textAlign: TextAlign.center,
      ),
    );
    var nasaIdWidget =
        Text(nasaId == null ? '' : 'ID: $nasaId', style: subHeadingStyle);
    var centerWidget = Padding(
        child: Text(center == null ? '' : 'Center: $center',
            style: subHeadingStyle),
        padding: EdgeInsets.only(bottom: 16.0));
    return Column(children: [titleWidget, nasaIdWidget, centerWidget]);
  }

  Widget _showButton() {
    return Row(children: [
      Expanded(
        child: FlatButton(
          padding: EdgeInsets.symmetric(vertical: 15.0),
          color: isReserved ? Colors.red : Colors.green,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(isReserved ? Icons.not_interested : Icons.check),
            Text(isReserved ? 'Release' : 'Catch',
                style: TextStyle(fontSize: 16.0))
          ]),
          onPressed: () {
            isReserved ? onRemovedCallback() : onAddedCallback();
          },
        ),
      )
    ]);
  }

  List<Widget> _wrapInScrimAndExpand(Widget child) {
    if (isReserved && viewType == ViewType.available) {
      child = Container(
          foregroundDecoration:
              BoxDecoration(color: Color.fromARGB(150, 30, 30, 30)),
          child: child);
    }
    child = Expanded(child: Row(children: [Expanded(child: child)]));
    return [child];
  }
}
