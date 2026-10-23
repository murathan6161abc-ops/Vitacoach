package com.vitacoach.vitacoach

import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.fitness.FitnessLocal
import com.google.android.gms.fitness.LocalRecordingClient
import com.google.android.gms.fitness.data.LocalDataType
import com.google.android.gms.fitness.data.LocalField
import com.google.android.gms.fitness.request.LocalDataReadRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vitacoach/step_history")
            .setMethodCallHandler { call, result ->
                if (call.method == "dailyTotals") {
                    val days = (call.argument<Int>("days") ?: 7).coerceIn(1, 10)
                    dailyTotals(days, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Gün gün adım toplamları. Google Play hizmetlerinin Kayıt API'si
     * adımları uygulama kapalıyken de cihazda kaydeder (hesap gerekmez,
     * veri cihazdan çıkmaz). Kayıt ilk abonelikten sonra başlar; Play
     * hizmetleri yoksa veya izin verilmediyse null döner.
     */
    private fun dailyTotals(days: Int, result: MethodChannel.Result) {
        val available = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(
            this,
            LocalRecordingClient.LOCAL_RECORDING_CLIENT_MIN_VERSION_CODE,
        )
        if (available != ConnectionResult.SUCCESS) {
            result.success(null)
            return
        }
        val client = FitnessLocal.getLocalRecordingClient(this)
        client.subscribe(LocalDataType.TYPE_STEP_COUNT_DELTA)
            .addOnSuccessListener { readTotals(client, days, result) }
            .addOnFailureListener { result.success(null) }
    }

    private fun readTotals(client: LocalRecordingClient, days: Int, result: MethodChannel.Result) {
        val zone = ZoneId.systemDefault()
        val start = LocalDate.now(zone).minusDays((days - 1).toLong()).atStartOfDay(zone)
        val end = ZonedDateTime.now(zone)
        val request = LocalDataReadRequest.Builder()
            .aggregate(LocalDataType.TYPE_STEP_COUNT_DELTA)
            .bucketByTime(1, TimeUnit.DAYS)
            .setTimeRange(start.toEpochSecond(), end.toEpochSecond(), TimeUnit.SECONDS)
            .build()
        client.readData(request)
            .addOnSuccessListener { response ->
                val totals = HashMap<String, Int>()
                for (bucket in response.buckets) {
                    val day = Instant.ofEpochSecond(bucket.getStartTime(TimeUnit.SECONDS))
                        .atZone(zone)
                        .toLocalDate()
                        .toString()
                    var steps = 0
                    for (dataSet in bucket.dataSets) {
                        for (point in dataSet.dataPoints) {
                            steps += point.getValue(LocalField.FIELD_STEPS).asInt()
                        }
                    }
                    totals[day] = steps
                }
                result.success(if (totals.isEmpty()) null else totals)
            }
            .addOnFailureListener { result.success(null) }
    }
}
