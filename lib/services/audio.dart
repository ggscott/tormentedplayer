import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show Client;
import 'package:rxdart/rxdart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tormentedplayer/models/track.dart';
import 'package:tormentedplayer/resources/repository.dart';

MediaControl playControl = MediaControl(
  label: 'Play',
  action: MediaAction.play,
  androidIcon: 'drawable/ic_play_black',
);
MediaControl pauseControl = MediaControl(
  label: 'Pause',
  action: MediaAction.pause,
  androidIcon: 'drawable/ic_pause_black',
);

void audioPlayerTaskEntryPoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

// This is just a wrapper for AudioService to simplify testing
// See https://github.com/mockito/mockito/issues/1013
class AudioClient {
  Future<void> play() => AudioService.play();

  Future<bool> start() => AudioService.start(
        backgroundTaskEntrypoint: audioPlayerTaskEntryPoint,
        androidNotificationChannelName: 'Tormented Player',
        notificationColor: 0xFF212121,
        androidNotificationIcon: 'drawable/ic_notification_eye',
        enableQueue: false,
        androidStopForegroundOnPause: true,
      );

  Future<void> stop() => AudioService.stop();

  bool get connected => AudioService.connected;

  PlaybackState get playbackState => AudioService.playbackState;

  Stream<PlaybackState> get playbackStateStream =>
      AudioService.playbackStateStream;

  Stream<MediaItem> get currentMediaItemStream =>
      AudioService.currentMediaItemStream;

  MediaItem get currentMediaItem => AudioService.currentMediaItem;
}

class AudioPlayerTask extends BackgroundAudioTask {
  AudioPlayer _audioPlayer = AudioPlayer();
  Repository _repository = Repository(Client());
  StreamSubscription<AudioPlaybackEvent> _eventSubscription;
  StreamSubscription<MediaItem> _mediaItemSubscription;
  final String _url = 'http://stream2.mpegradio.com:8070/tormented.mp3';
  Completer _completer = Completer();

  BasicPlaybackState _stateToBasicState(AudioPlaybackState state) {
    switch (state) {
      case AudioPlaybackState.none:
        return BasicPlaybackState.none;
      case AudioPlaybackState.stopped:
        return BasicPlaybackState.stopped;
      case AudioPlaybackState.paused:
        return BasicPlaybackState.paused;
      case AudioPlaybackState.playing:
        return BasicPlaybackState.playing;
      case AudioPlaybackState.connecting:
        return BasicPlaybackState.connecting;
      case AudioPlaybackState.completed:
        return BasicPlaybackState.stopped;
      default:
        throw Exception('Illegal state');
    }
  }

  List<MediaControl> _getControls(state) {
    if (state == BasicPlaybackState.playing) {
      return [
        pauseControl,
      ];
    } else {
      return [
        playControl,
      ];
    }
  }

  void _setState(BasicPlaybackState state) {
    AudioServiceBackground.setState(
      basicState: state,
      controls: _getControls(state),
    );
  }

  List<String> _parseIcyTitle(String title) {
    if (title == null) return [null, null];
    final RegExp matcher = RegExp(r'^(.*) - (.*)$');
    final match = matcher.firstMatch(title);

    if (match == null) return [null, null];

    final song = match.group(1);
    final artist = match.group(2);

    return [song, artist];
  }

  Stream<MediaItem> _mediaItemStream(IcyMetadata item) async* {
    final String icyTitle = item?.info?.title;
    final List<String> parsedTitle = _parseIcyTitle(icyTitle);
    final String title = parsedTitle[1];
    final String artist = parsedTitle[0];

    // TODO advise @ryanheise of a bug with empty title and artist
    yield MediaItem(
      id: _url,
      album: '',
      title: title ?? ' ',
      artist: artist ?? ' ',
      artUri: null,
    );

    if ((title ?? '').isEmpty || (artist ?? '').isEmpty) return;

    try {
      Track fullTrack = await _repository.fetchTrack(title, artist);

      yield MediaItem(
        id: _url,
        album: fullTrack.album ?? '',
        title: title,
        artist: artist,
        artUri: fullTrack.image,
      );
    } catch (err) {
      print('Error while fetching current track\'s info: $err');
    }
  }

  @override
  Future<void> onStart() async {
    // Subscribe to AudioPlayer events
    // Playback state events
    _eventSubscription = _audioPlayer.playbackEventStream.listen(
      (event) {
        final state = _stateToBasicState(event.state);
        if (state != BasicPlaybackState.stopped) {
          _setState(state);
        }
        _setState(state);
      },
      onError: (err, stack) {
        print('Error during playback: $err; $stack');
        onError();
      },
    );

    // Icy metadata events
    _mediaItemSubscription = _audioPlayer.icyMetadataStream
        .distinct((prev, next) => prev.info?.title == next.info?.title)
        .switchMap(_mediaItemStream)
        .listen(AudioServiceBackground.setMediaItem);

    try {
      await _audioPlayer.setUrl(_url);
      // Start playing immediately
      onPlay();
    } catch (err) {
      print('Error while connecting to the URL: $err');
      onError();
    }
    await _completer.future;
  }

  @override
  void onPlay() {
    _audioPlayer.play();
  }

  @override
  void onPause() {
    _audioPlayer.pause();
  }

  @override
  void onStop() {
    _audioPlayer.stop();
    _setState(BasicPlaybackState.stopped);
    _eventSubscription.cancel();
    _mediaItemSubscription.cancel();
    _completer.complete();
  }

  void onError() {
    _audioPlayer.stop();
    _setState(BasicPlaybackState.error);
    _eventSubscription.cancel();
    _mediaItemSubscription.cancel();
    _completer.complete();
  }

  @override
  void onAudioFocusLost() {
    onPause();
  }
}
