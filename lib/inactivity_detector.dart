library inactivity_detector;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class InactivityDetector extends StatefulWidget {
  const InactivityDetector({
    super.key,
    required this.child,
    this.timeOut = 180000, // 3 minutes
    this.enabled = true,
  });
  final bool enabled;
  final int timeOut;
  final Widget child;

  @override
  State<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends State<InactivityDetector>
    with WidgetsBindingObserver {
  late Timer _timer;
  late int sessionMillis; // 3 minutes
  final backgroundedTimeKey = 'backgroundedTimeKey';
  final lastKnownStateKey = 'lastKnownStateKey';

  @override
  void initState() {
    sessionMillis = widget.timeOut;
    if (widget.enabled) {
      _initializeTimer();

      WidgetsBinding.instance.addObserver(this);
    }
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _resumed();
        break;
      case AppLifecycleState.paused:
        _paused();
        break;
      case AppLifecycleState.inactive:
        _inactive();
        break;
      case AppLifecycleState.detached:
        _detached();
        break;
    }
  }

  Future<void> _resumed() async {
    final sp = sl<SharedPreferences>();
    final currentTime = DateTime.now().toLocal().millisecondsSinceEpoch;
    final bgTime = sp.getInt(backgroundedTimeKey) ?? currentTime;
    final allowedBackgroundTime = bgTime + sessionMillis;

    final reachTimeOut = currentTime > allowedBackgroundTime;

    if (reachTimeOut) {
      await _logOutUser();

      return;
    }

    _initializeTimer();
    await sp.remove(backgroundedTimeKey); // clean
    await sp.setInt(
      lastKnownStateKey,
      AppLifecycleState.resumed.index,
    ); // previous state
  }

  Future<void> _inactive() async {
    final sp = sl<SharedPreferences>();
    final currentTime = DateTime.now().toLocal().millisecondsSinceEpoch;
    final prevState = sp.getInt(lastKnownStateKey);
    final prevStateIsNotPaused = prevState != null &&
        AppLifecycleState.values[prevState] != AppLifecycleState.paused;

    if (prevStateIsNotPaused) {
      // save App backgrounded time to Shared preferences

      await sp.setInt(
        backgroundedTimeKey,
        currentTime,
      );
    } else {
      await sp.remove(backgroundedTimeKey);
    }

    _initializeTimer(isForeground: false);
    // update previous state as inactive
    await sp.setInt(lastKnownStateKey, AppLifecycleState.inactive.index);
  }

  Future<void> _paused() async {
    await sl<SharedPreferences>()
        .setInt(lastKnownStateKey, AppLifecycleState.paused.index);
  }

  Future<void> _detached() async {
  }

  void _initializeTimer({
    Duration duration = const Duration(minutes: 3),
    bool isForeground = true,
  }) {
    try {
      if (_timer.isActive) {
        _timer.cancel();
      }
    } catch (err) {
    } finally {
      if (mounted) {
        _timer = isForeground
            ? Timer(duration, _showAlert)
            : Timer(duration, _logOutUser);
      }
    }
  }

  void _showAlert() => {
    //TODO logout

  }

  void _logOutUser()=>{
    //TODO logout
  }

  void onAlertCloseFunction() {
    Navigator.of(context).pop();
    _initializeTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _initializeTimer,
      onPanDown: (_) => _initializeTimer(),
      child: widget.child,
    );
  }
}
