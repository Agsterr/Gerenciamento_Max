package io.github.agsterr.salaomax.cliente

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine

/** Google Play: sem auto-update (as atualizações vêm da loja). */
object DistributionChannel {
    @Suppress("UNUSED_PARAMETER")
    fun register(activity: Activity, engine: FlutterEngine) = Unit
}
