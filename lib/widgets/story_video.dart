import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

import '../controller/story_controller.dart';
import '../utils.dart';

class VideoLoader {
  String url;

  File? videoFile;

  Map<String, dynamic>? requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    if (this.videoFile != null) {
      this.state = LoadState.success;
      onComplete();
    }

    final fileStream = DefaultCacheManager().getFileStream(this.url,
        headers: this.requestHeaders as Map<String, String>?);

    fileStream.listen((fileResponse) {
      if (fileResponse is FileInfo) {
        if (this.videoFile == null) {
          this.state = LoadState.success;
          this.videoFile = fileResponse.file;
          onComplete();
        }
      }
    });
  }
}

class StoryVideo extends StatefulWidget {
  final StoryController? storyController;
  final VideoLoader videoLoader;
  final bool isHLS;
  final VideoPlayerController? playerController;

  StoryVideo(this.videoLoader,
      {this.storyController,
      this.playerController,
      this.isHLS = false,
      Key? key})
      : super(key: key ?? UniqueKey());

  static StoryVideo url(String url,
      {StoryController? controller,
      required bool isHLS,
      Map<String, dynamic>? requestHeaders,
      VideoPlayerController? playerController,
      Key? key}) {
    return StoryVideo(VideoLoader(url, requestHeaders: requestHeaders),
        storyController: controller,
        key: key,
        playerController: playerController,
        isHLS: isHLS);
  }

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  Future<void>? playerLoader;

  StreamSubscription? _streamSubscription;

  VideoPlayerController? playerController;

  @override
  void initState() {
    super.initState();

    widget.storyController!.pause();

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        /// if video is HLS, need to load it from network, if is a downloaded file, need to load it from local cache
        if (widget.isHLS) {
          this.playerController =
              VideoPlayerController.network(widget.videoLoader.url);
        } else {
          this.playerController =
              VideoPlayerController.file(widget.videoLoader.videoFile!);
        }
        // this.playerController!.initialize().then((v) {
        //   setState(() {});
        //   widget.storyController!.play();
        // });

        if (widget.playerController!.value.isInitialized) {
          widget.storyController!.play();
          setState(() {});
        } else {}

        if (widget.storyController != null) {
          _streamSubscription =
              widget.storyController!.playbackNotifier.listen((playbackState) {
            if (playbackState == PlaybackState.pause) {
              widget.playerController!.pause();
            } else {
              widget.playerController!.play();
            }
          });
        }
      } else {
        setState(() {});
      }
    });
  }

  Widget getContentView() {
    if (widget.videoLoader.state == LoadState.success &&
        widget.playerController!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: widget.playerController!.value.aspectRatio,
          child: VideoPlayer(widget.playerController!),
        ),
      );
    }

    return widget.videoLoader.state == LoadState.loading ||
            !playerController!.value.isInitialized == true
        ? Shimmer.fromColors(
            baseColor: Color(0xFF222124),
            highlightColor: Colors.grey.withOpacity(0.2),
            child: Container(
              color: Colors.black,
              child: Container(
                decoration: ShapeDecoration(
                  color: Colors.grey[500]!,
                  shape: const RoundedRectangleBorder(),
                ),
              ),
            ),
          )
        : Center(
            child: Text(
            "Media failed to load.",
            style: TextStyle(
              color: Colors.white,
            ),
          ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      height: double.infinity,
      width: double.infinity,
      child: getContentView(),
    );
  }

  @override
  void dispose() {
    // playerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
