import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tormentedplayer/blocs/radio_bloc.dart';
import 'package:tormentedplayer/services/radio.dart';

class PlayerButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    RadioBloc _bloc = Provider.of<RadioBloc>(context);
    final color = Theme.of(context).primaryColorDark;
    final highlight = Theme.of(context).primaryColor.withAlpha(30);
    final splash = Theme.of(context).primaryColor.withAlpha(50);

    return Material(
      child: Center(
        child: Ink(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.0),
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: StreamBuilder<RadioPlaybackState>(
              initialData: RadioPlaybackState.none,
              stream: _bloc.playbackStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data ?? RadioPlaybackState.none;
                final bool isLoading = state == RadioPlaybackState.connecting;
                final bool isPlaying = state == RadioPlaybackState.playing;

                return InkWell(
                  splashColor: splash,
                  highlightColor: highlight,
                  borderRadius: BorderRadius.circular(100.0),
                  child: isLoading
                      ? Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ))
                      : Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: color,
                          size: 60,
                        ),
                  onTap: () {
                    if (isLoading) return;

                    isPlaying ? _bloc.stopRadio() : _bloc.startRadio();
                  },
                );
              }),
        ),
      ),
    );
  }
}
