package com.bplusplus.muslim

import io.flutter.embedding.android.FlutterActivity
import android.view.KeyEvent
import com.bplusplus.prayer_audio.AdhanPlaybackService

class MainActivity: FlutterActivity() {
    private var silencedKey: Int? = null

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_UP && silencedKey == event.keyCode) {
            silencedKey = null
            return true
        }
        if (event.action == KeyEvent.ACTION_DOWN &&
            event.keyCode in listOf(KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_VOLUME_MUTE) &&
            AdhanPlaybackService.stopIfPlaying()) {
            silencedKey = event.keyCode
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
