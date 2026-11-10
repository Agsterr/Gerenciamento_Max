package io.github.agsterr.salaomax.cliente

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Troca o ícone do app conforme o tema de cor: liga o activity-alias do tema e desliga os outros. */
object AppIcon {
    private val ids = listOf("rosa", "azul", "verde", "grafite", "laranja", "roxo")
    private const val DEFAULT = "rosa"

    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "salaomax/app_icon").setMethodCallHandler { call, result ->
            if (call.method == "set") {
                set(context, call.arguments as? String ?: DEFAULT)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun set(context: Context, id: String) {
        val target = if (id in ids) id else DEFAULT
        val pm = context.packageManager
        // liga o novo antes de desligar os outros: nunca fica sem ícone
        val order = listOf(target) + ids.filter { it != target }
        for (alias in order) {
            val component = ComponentName(context.packageName, "io.github.agsterr.salaomax.cliente.Icon${alias.replaceFirstChar { c -> c.uppercase() }}")
            val want = alias == target
            val state = pm.getComponentEnabledSetting(component)
            val enabledNow = when (state) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
                else -> alias == DEFAULT
            }
            if (enabledNow == want) continue
            pm.setComponentEnabledSetting(
                component,
                if (want) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
