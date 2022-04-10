package com.easazade.android_long_task

import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ContentValues.TAG
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Binder
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.easazade.android_long_task.ui_components.NotificationButton
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class AppService : Service() {

    private val binder = LocalBinder()
    private val channel_name = "APP_SERVICE_CHANNEL_NAME"
    private var channel: MethodChannel? = null
    var serviceData: JSONObject? = null
    private var observer: ((JSONObject) -> Unit)? = null
    private var executionResultListener: ((JSONObject) -> Unit)? = null
    private val notifId = 101
    private var engine: FlutterEngine? = null
    private val BUTTON_PRESSED_ACTION = "onButtonPressed"
    private val ACTION_DATA_NAME = "data"

    private var clickCallback: ((String) -> Unit)? = null;

    // A broadcast receiver that handles intents that occur within the foreground service.
    private var broadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            try {
                val action = intent?.action ?: return
                val data = intent.getStringExtra(ACTION_DATA_NAME)
                data?.let { resultData ->
                    if (action == BUTTON_PRESSED_ACTION) {
                        clickCallback?.let {
                            it(resultData)
                            channel?.invokeMethod(BUTTON_PRESSED_ACTION,resultData)

                        }
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "invokeMethod", e)
            }
        }
    }

    inner class LocalBinder : Binder() {
        fun getInstance(): AppService = this@AppService
    }

    fun setServiceDataObserver(observer: (JSONObject) -> Unit) {
        this.observer = observer
    }

    fun setMethodExecutionResultListener(listener: (JSONObject) -> Unit) {
        this.executionResultListener = listener
    }

    fun runDartFunction() {
        engine = FlutterEngine(applicationContext)

        val entrypoint = DartEntrypoint("lib/main.dart", "serviceMain")
        engine!!.dartExecutor.executeDartEntrypoint(entrypoint)

        channel = MethodChannel(engine!!.dartExecutor.binaryMessenger, channel_name)
        channel!!.setMethodCallHandler { call, result ->

            if (call.method == "stop_service") {
                stopDartService()
                result.success("stopped service")
            } else if (call.method == "SET_SERVICE_DATA") {
                try {
                    val jObject = JSONObject(call.arguments as String)
                    setData(jObject)
                    result.success("set data on service")
                } catch (e: Throwable) {
                    result.error(
                        "CODE: FAILED SETTING DATA",
                        "!!! Failed to set data on service !!!",
                        ""
                    )
                    e.printStackTrace()
                }
            } else if (call.method == "END_EXECUTION") {
                try {
                    val jObject = JSONObject(call.arguments as String)
                    endExecution(jObject)
                    result.success("!!! Ended execution.")
                } catch (e: Throwable) {
                    result.error(
                        "CODE:FAILED EDNING EXECUTION",
                        "!!! failed to end the execution",
                        ""
                    )
                    e.printStackTrace()
                }
            }
        }

        if (serviceData != null) {
            channel!!.invokeMethod("runDartCode", serviceData.toString())
        } else {
            Log.e("DART/NATIVE", "please set ServiceData before calling execute")
        }

    }

    fun stopDartService() {
        stopForeground(true)
        stopSelf()
        engine?.destroy()
        unregisterBroadcastReceiver()
    }

    private fun registerBroadcastReceiver() {
        val intentFilter = IntentFilter().apply {
            addAction(BUTTON_PRESSED_ACTION)
        }
        registerReceiver(broadcastReceiver, intentFilter)
    }

    private fun unregisterBroadcastReceiver() {
        unregisterReceiver(broadcastReceiver)
    }

    override fun onCreate() {
        super.onCreate()
//    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        registerBroadcastReceiver()
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(getMipMapIconId())
        startForeground(notifId, builder.build())
//    }

    }

    override fun onBind(intent: Intent?): IBinder? = binder

    fun setData(data: JSONObject?) {
        data?.let {
            serviceData = it
            updateNotification()
            observer?.invoke(it)
        }
    }

    private fun endExecution(data: JSONObject?) {
        data?.let {
            serviceData = it
            executionResultListener?.invoke(it)
        }
    }


    private fun buildButtonCompatActions(buttons: MutableList<NotificationButton>): MutableList<NotificationCompat.Action> {
        val list: MutableList<NotificationCompat.Action> = mutableListOf()

        for (i in 0 until buttons.size) {
            val buttonId = buttons.elementAt(i).id
            val buttonText = buttons.elementAt(i).text

            val bIntent = Intent(BUTTON_PRESSED_ACTION).apply {
                putExtra(ACTION_DATA_NAME, buttonId)
            }
            val bPendingIntent =
                PendingIntent.getBroadcast(this, i + 1, bIntent, PendingIntent.FLAG_IMMUTABLE)
            val button = NotificationCompat.Action.Builder(0, buttonText, bPendingIntent).build()
            list.add(button)
        }
        return list
    }

    private fun buttonsFromJsonArray(array: JSONArray): MutableList<NotificationButton> {
        val list: MutableList<NotificationButton> = mutableListOf()

        for (i in 0 until array.length()) {
            val obj = JSONObject(array[i].toString())
            val buttonId = obj.getString("id")
            val buttonText = obj.getString("text")
            list.add(NotificationButton(buttonId, buttonText))
        }

        return list
    }

    private fun updateNotification() {
        serviceData?.let {
            val hasDescriptionAndTitle: Boolean =
                it.has("notif_title") && !it.isNull("notif_title")
                        && it.has("notif_description") && !it.isNull("notif_description")

            if (!hasDescriptionAndTitle)
                return

            val title = it.getString("notif_title")
            val description = it.getString("notif_description")
            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentText(description)
                .setContentTitle(title)
                .setSmallIcon(getMipMapIconId())

            if (it.has("notif_buttons") && !it.isNull("notif_buttons")) {
                val buttons = this.buttonsFromJsonArray(it.getJSONArray("notif_buttons"))
                val actions = this.buildButtonCompatActions(buttons)
                for (action in actions) {
                    builder.addAction(action)
                }
            }

            if (it.has("notif_progress") && !it.isNull("notif_progress")) {
                var jsonObj =
                    it.optJSONObject("notif_progress") ?: JSONObject(it.getString("notif_progress"))
                if (jsonObj.has("progress") && !jsonObj.isNull("progress") &&
                    jsonObj.has("maximum") && !jsonObj.isNull("maximum") &&
                    jsonObj.has("indeterminate") && !jsonObj.isNull("indeterminate")
                ) {
                    val progress = jsonObj.getInt("progress")
                    val maximum = jsonObj.getInt("maximum")
                    val indeterminate = jsonObj.getBoolean("indeterminate")

                    builder.setProgress(maximum, progress, indeterminate)
                }
            }

            startForeground(notifId, builder.build())
        }
    }

    private fun getMipMapIconId(): Int =
        this.applicationContext.resources.getIdentifier(
            "ic_launcher",
            "mipmap",
            this.applicationContext.packageName
        )

    fun setOnClickCallback(callback: ((String) -> Unit)) {
        this.clickCallback = callback
    }

}