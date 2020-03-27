import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:tormentedplayer/services/audio.dart';
import 'package:tormentedplayer/services/lastfm.dart';
import 'package:tormentedplayer/widgets/track_cover.dart';
import 'package:tormentedplayer/widgets/track_info.dart';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver {
  LastFM _lastFM = LastFM(LastFMConfig(
    apiKey: 'XXX',
  ));

  void _connect() {
    AudioService.connect();
  }

  void _disconnect() {
    AudioService.disconnect();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    print('starting audioservice');
    AudioService.start(
      backgroundTaskEntrypoint: audioPlayerTaskEntryPoint,
      androidNotificationChannelName: 'Tormented Player',
      notificationColor: 0xFF2196f3,
      androidNotificationIcon: 'drawable/ic_notification_radio',
      enableQueue: false,
    );
    print('audioservice started');
    _connect();
    print('connected to audioservice');
  }

  @override
  void dispose() {
    print('dispose');
    _disconnect();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('AppLifecycleState: $state');
    switch (state) {
      case AppLifecycleState.paused:
        print('onpause');
        _disconnect();
        break;
      case AppLifecycleState.resumed:
        print('onresume');
        _connect();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              print('new media item: $title - $artist');

              if (title.isNotEmpty && artist.isNotEmpty) {
                return FutureBuilder(
                  future: _lastFM.getTrackInfo(track: title, artist: artist),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      print(snapshot.error);
                    }
                    return TrackCover(snapshot.data?.album?.image?.extraLarge);
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
    return StreamBuilder<PlaybackState>(
        stream: AudioService.playbackStateStream,
        builder: (context, snapshot) {
          final BasicPlaybackState state =
              snapshot.data?.basicState ?? BasicPlaybackState.none;
          print('New playback state: ${snapshot.data?.basicState}');
          final bool isLoading = state == null ||
              state == BasicPlaybackState.none ||
              state == BasicPlaybackState.connecting;
          final bool isPlaying = state == BasicPlaybackState.playing;

          return FloatingActionButton(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ))
                : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () async {
              try {
                isPlaying
                    ? await AudioService.pause()
                    : await AudioService.play();
              } catch (err) {
                print(err);
                AudioService.pause();
              }
            },
          );
        });
  }
}
