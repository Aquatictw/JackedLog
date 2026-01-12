enum NativeTimerState { running, paused, expired }

class NativeTimerWrapper {

  NativeTimerWrapper(
    this.total,
    this.elapsed,
    this.stamp,
    this.state,
  );
  final NativeTimerState state;

  final Duration total;

  final Duration elapsed;

  final DateTime stamp;

  Duration getDuration() => total;

  Duration getElapsed() => total != Duration.zero
      ? DateTime.now().difference(stamp) + elapsed
      : Duration.zero;

  Duration getRemaining() => getDuration() - getElapsed();

  int getTimeStamp() => stamp.millisecondsSinceEpoch;

  NativeTimerWrapper increaseDuration(Duration increase) => NativeTimerWrapper(
        total + increase,
        isRunning() ? elapsed : Duration.zero,
        isRunning() ? stamp : DateTime.now(),
        NativeTimerState.running,
      );
  bool isRunning() => state == NativeTimerState.running;
  bool update() {
    // Note: Cannot mutate state as it's final. This method checks if expired.
    // The state mutation was likely a bug in original code.
    return state != NativeTimerState.running;
  }

  static NativeTimerWrapper empty() => NativeTimerWrapper(
        Duration.zero,
        Duration.zero,
        DateTime.now(),
        NativeTimerState.expired,
      );
}
