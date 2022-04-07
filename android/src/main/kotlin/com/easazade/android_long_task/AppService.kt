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
import android.widget.Button
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.easazade.android_long_task.ui_components.NotificationButton
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterMain
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

    private var title: String? = null
    private var description: String? = null
    private var buttons: MutableList<NotificationButton> = mutableListOf()
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
        //    channel = MethodChannel(messenger, channel_name)
//    channel?.invokeMethod(dartFunctionName, "arguments from service")
        // FlutterMain.startInitialization(this)
        // FlutterMain.ensureInitializationComplete(this, emptyArray<String>())

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
                    Log.d("DART/NATIVE", "update json data from service client -> $jObject")
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

    fun setData(data: JSONObject?) {
        // Log.d("DART/NATIVE", "setting data on service")
        //Log.d("DART/NATIVE", data?.toString() ?: "json data is null")
        serviceData = data
        data?.let {
            observer?.invoke(it)
            if (it.has("notif_title") && it.has("notif_description")) {
                this.title = it.getString("notif_title")
                this.description = it.getString("notif_description")
                if (it.has("notif_buttons")) {
                    this.buttons = buttonsFromJsonArray(it.getJSONArray("notif_buttons"))
                }
                updateNotification()
            }
        }
    }

    private fun endExecution(data: JSONObject?) {
        //Log.d("DART/NATIVE", "ending execution of method call")
        //Log.d("DART/NATIVE", data?.toString() ?: "result data is null")
        serviceData = data
        data?.let {
            /*
          if (it.has("notif_title") && it.has("notif_description")) {
            val title = it.getString("notif_title")
            val description = it.getString("notif_description")
            updateNotification(title, description)
          }*/
            executionResultListener?.invoke(it)
        }
    }

    private fun buildButtonCompatActions(): MutableList<NotificationCompat.Action> {
        val list: MutableList<NotificationCompat.Action> = mutableListOf()

        for (i in 0 until this.buttons.size) {
            val buttonId = this.buttons.elementAt(i).id
            val buttonText = this.buttons.elementAt(i).text

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

    private fun updateNotification() {
        //Log.d("DART/NATIVE", "updating notification => $title | $description")
//    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        if (this.title == null || this.description == null)
            return

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentText(description)
            .setContentTitle(title)
            .setSmallIcon(getMipMapIconId())

        if (this.buttons.isNotEmpty()) {
            for (button in buildButtonCompatActions()) {
                builder.addAction(button)
            }
        }

        startForeground(notifId, builder.build())
//    }
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