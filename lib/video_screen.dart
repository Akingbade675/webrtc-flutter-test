// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_test/socket_client.dart';

class VideoScreen extends StatefulWidget {
  String? meetingId;

  VideoScreen({Key? key, this.meetingId}) : super(key: key);

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  SocketClient socketClient = SocketClient();
  final List<RTCIceCandidate> _iceCandidates = [];
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      print('initState');
      final pc = await createPeerConnection({
        'iceServers': [
          {
            'urls': [
              'stun:stun.l.google.com:19302',
            ],
          },
        ],
      }, <String, dynamic>{
        'mandatory': {},
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      });

      pc.onIceCandidate = (candidate) {
        print(candidate.toMap());
        _iceCandidates.add(candidate);
      };

      pc.onTrack = (event) {
        print('Track RECEIVED');
        event.track.onUnMute = () {
          if (_remoteStream != null) {
            return;
          }

          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
          setState(() {});
        };
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
        setState(() {});
      };

      pc.onAddStream = (stream) {
        _remoteStream = stream;
        _remoteRenderer.srcObject = _remoteStream;
        setState(() {});
      };

      pc.onAddTrack = (stream, track) {
        _remoteStream = stream;
        _remoteStream?.addTrack(track);
        _remoteRenderer.srcObject = _remoteStream;
        setState(() {});
      };

      pc.onIceConnectionState = (state) {
        print(state);
      };

      pc.onIceGatheringState = (state) {
        print('iceGatheringState: $state');
      };

      pc.onSignalingState = (state) {
        print('signalingState: $state');
      };

      pc.onRenegotiationNeeded = () {
        print('renegotiationNeeded');
      };

      pc.onConnectionState = (state) {
        print('connectionState: $state');
      };

      await Future.wait(
          [_localRenderer.initialize(), _remoteRenderer.initialize()]);

      await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
        // 'video': {
        //   'minWidth': '640',
        //   'minHeight': '480',
        //   'minFrameRate': '24',
        //   'facingMode': 'user',
        //   'optional': [],
        // }
      }).then((stream) {
        setState(() {
          _localStream = stream;
          _localRenderer.srcObject = _localStream;
        });

        stream.getTracks().forEach((track) {
          pc.addTrack(track, stream);
        });
      });

      socketClient.connect();

      if (widget.meetingId == null) {
        final meetingId = DateTime.now().millisecondsSinceEpoch.toString();
        widget.meetingId = meetingId;
        print('MEETING ID - $meetingId');
        final offer = await pc.createOffer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': 0,
        });

        await pc.setLocalDescription(offer);

        socketClient.on('answerSDP', (data) async {
          print('ANSWER SDP: $data');
          await pc.setRemoteDescription(
            await createRTCSessionDescriptionFromMap(data['answerSDP']),
          );

          socketClient.on('answerICE', (data) async {
            print('ANSWER ICE: $data');
            await pc.addCandidate(
              await createIceCandidateFromMap(data['candidate']),
            );
          });

          for (var iceCandidate in _iceCandidates) {
            socketClient.emit('offerICE', {
              'meetingId': meetingId,
              'candidate': iceCandidate.toMap(),
            });
          }
        });

        socketClient.emit('video-offer', {
          'meetingId': meetingId,
          'offerSDP': offer.toMap(),
        });
      } else {
        socketClient.on('joined', (data) async {
          print('OFFER SDP: $data');
          await pc.setRemoteDescription(
            await createRTCSessionDescriptionFromMap(data['offerSDP']),
          );

          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          socketClient.emit('video-answer', {
            'meetingId': widget.meetingId,
            'answerSDP': answer.toMap(),
          });

          socketClient.on('offerICE', (data) async {
            print('OFFER ICE: $data');
            await pc.addCandidate(
              await createIceCandidateFromMap(data['candidate']),
            );
          });

          for (var candidate in _iceCandidates) {
            socketClient.emit('answerICE', {
              'meetingId': widget.meetingId,
              'candidate': candidate.toMap(),
            });
          }
        });

        socketClient.emit('join', {'meetingId': widget.meetingId});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Screen'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(
              _localRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 250,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: RTCVideoView(
                  _remoteRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<RTCSessionDescription> createRTCSessionDescriptionFromMap(
    Map<String, dynamic> sessionDescriptionMap) async {
  return RTCSessionDescription(
      sessionDescriptionMap['sdp'], sessionDescriptionMap['type']);
}

Future<RTCIceCandidate> createIceCandidateFromMap(
    Map<String, dynamic> candidateMap) async {
  return RTCIceCandidate(
    candidateMap['candidate'],
    candidateMap['sdpMid'],
    candidateMap['sdpMLineIndex'],
  );
}
