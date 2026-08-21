package com.afnan.wird

import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceFragmentActivity

// AudioServiceFragmentActivity (not plain FlutterActivity) is required by
// just_audio_background/audio_service for continuous Surah playback's
// notification/lock-screen controls - without it, AudioService.init() fails
// at runtime with "The Activity class declared in your AndroidManifest.xml
// is wrong or has not provided the correct FlutterEngine", confirmed by
// actually running the app after wiring in background playback.
class MainActivity : AudioServiceFragmentActivity() {
    // Android 12+'s SplashScreen API plays its own scale-and-fade exit
    // transition on the icon when handing off to the app, on top of - and
    // separate from - the sizing already matched in values-v31/styles.xml
    // and tool/generate_splash_icon.js. That default transition is what
    // reads as a big logo blurring away right before Flutter's own,
    // correctly-sized loading screen appears. There is no XML attribute for
    // it; removing the splash view immediately, with no exit animation of
    // its own, is the only way to skip it.
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { it.remove() }
        }
        super.onCreate(savedInstanceState)
    }
}
