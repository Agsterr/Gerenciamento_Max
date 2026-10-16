package io.github.agsterr.salaomax.cliente

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Canal "direct" registra o instalador de atualização; o canal "play" não faz nada.
        DistributionChannel.register(this, flutterEngine)
    }
}
