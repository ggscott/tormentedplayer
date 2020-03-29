import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tormentedplayer/blocs/radio.dart';
import 'package:tormentedplayer/models/track.dart';
import 'package:tormentedplayer/resources/repository.dart';
import 'package:tormentedplayer/widgets/track_cover.dart';
import 'package:tormentedplayer/widgets/track_info.dart';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Repository _repository = Repository();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    RadioBloc.connect();
  }

  @override
  void dispose() {
    RadioBloc.disconnect();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        RadioBloc.disconnect();
        break;
      case AppLifecycleState.resumed:
        RadioBloc.connect();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        RadioBloc.disconnect();
        return Future.value(true);
      },
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: OrientationBuilder(
            builder: (BuildContext context, Orientation orientation) {
              if (orientation == Orientation.portrait) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    buildCover(),
                    buildInfo(),
                    buildControls(),
                  ],
                );
              } else {
                return Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    buildCover(),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          buildInfo(),
                          SizedBox(height: 32.0),
                          buildControls(),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget buildCover() {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.0),
        child: StreamBuilder<MediaItem>(
            stream: AudioService.currentMediaItemStream,
            builder: (context, snapshot) {
              final String title = snapshot.data?.title ?? '';
              final String artist = snapshot.data?.artist ?? '';

              if (title.isNotEmpty && artist.isNotEmpty) {
                return FutureBuilder<Track>(
                  future: _repository.fetchTrack(title, artist),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      print(snapshot.error);
                    }

                    return TrackCover(snapshot.data?.image);
                  },
                );
              } else {
                return TrackCover(null);
              }
            }),
      ),
    );
  }

  Widget buildInfo() {
    return StreamBuilder<MediaItem>(
        stream: AudioService.currentMediaItemStream,
        builder: (context, snapshot) {
          return TrackInfo(
            title: snapshot?.data?.title ?? '-',
            artist: snapshot?.data?.artist ?? '-',
          );
        });
  }

  Widget buildControls() {
    return StreamBuilder<RadioPlaybackState>(
        stream: RadioBloc.playbackStateStream,
        builder: (context, snapshot) {
          final RadioPlaybackState state = snapshot.data;
          final bool isLoading = state == RadioPlaybackState.connecting;
          final bool isPlaying = state == RadioPlaybackState.playing;

          return FloatingActionButton(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ))
                : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (isLoading) return;

              isPlaying ? RadioBloc.stop() : RadioBloc.start();
            },
          );
        });
  }
}
