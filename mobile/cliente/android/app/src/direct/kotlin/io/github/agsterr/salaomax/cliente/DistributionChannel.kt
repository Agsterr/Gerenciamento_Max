package io.github.agsterr.salaomax.cliente

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * APK fora da loja: abre o instalador do Android para o APK baixado pelo app
 * (salao_core/AppUpdateService). Só existe no flavor "direct".
 */
object DistributionChannel {
    private const val CHANNEL = "salaomax/apk_installer"

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("ARGUMENT", "Caminho do APK ausente", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(install(activity, File(path)))
                    } catch (e: Exception) {
                        result.error("INSTALL", e.message ?: "Não foi possível abrir o instalador", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** "started" = instalador aberto; "permission" = usuário precisa liberar "instalar apps desconhecidos". */
    private fun install(activity: Activity, file: File): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !activity.packageManager.canRequestPackageInstalls()) {
            activity.startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            return "permission"
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
        activity.startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        return "started"
    }
}
