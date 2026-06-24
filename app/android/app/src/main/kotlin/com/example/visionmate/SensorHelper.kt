package com.example.visionmate

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.sqrt

class SensorHelper(context: Context, private val callback: (String) -> Unit) : SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val lightSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT)

    private var lastShakeTime: Long = 0
    private var isLowLight: Boolean? = null
    private var isEnabled = true

    fun start() {
        isEnabled = true
        accelerometer?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
        lightSensor?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
    }

    fun stop() {
        isEnabled = false
        sensorManager.unregisterListener(this)
        isLowLight = null
    }

    fun setEnabled(enabled: Boolean) {
        isEnabled = enabled
        if (!enabled) isLowLight = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onSensorChanged(event: SensorEvent?) {
        if (!isEnabled) return
        val sensorEvent = event ?: return

        when (sensorEvent.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                val x = sensorEvent.values[0]
                val y = sensorEvent.values[1]
                val z = sensorEvent.values[2]
                val gForce = sqrt(x * x + y * y + z * z)

                if (gForce > 15.0f) {
                    val now = System.currentTimeMillis()
                    if (now - lastShakeTime > 2500) {
                        lastShakeTime = now
                        callback("SHAKE")
                    }
                }
            }
            Sensor.TYPE_LIGHT -> {
                val lux = sensorEvent.values[0]
                // 🔥 BETTER AUTO-FLASH THRESHOLDS:
                // Low: 40 lux (Indoor dim light)
                // OK: 60 lux (Indoor normal light)
                if (lux < 40.0f) {
                    if (isLowLight != true) {
                        isLowLight = true
                        callback("LIGHT_LOW")
                    }
                } else if (lux > 60.0f) {
                    if (isLowLight != false) {
                        isLowLight = false
                        callback("LIGHT_OK")
                    }
                }
            }
        }
    }
}
