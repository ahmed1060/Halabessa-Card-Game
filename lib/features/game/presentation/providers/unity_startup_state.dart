/// Only a completed handshake may replace Flutter's board. Failure is sticky
/// so a delayed ready message cannot flash a failed renderer back on screen.
class UnityStartupState {
  bool isReady = false;
  bool hasFailed = false;

  bool handleEvent(String? event) {
    if (event == 'UNITY_FAILED') {
      hasFailed = true;
      isReady = false;
      return true;
    }
    if (event == 'UNITY_READY' && !hasFailed) {
      isReady = true;
      return true;
    }
    return false;
  }
}
