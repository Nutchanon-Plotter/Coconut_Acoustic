package com.example.coconut_maturity_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.flex.FlexDelegate
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.coconut_maturity_app/tflite"
    private var interpreter: Interpreter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "loadModel") {
                try {
                    val assetLookupKey = io.flutter.FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/models/coconut_maturity_model.tflite")
                    val assetFileDescriptor = assets.openFd(assetLookupKey)
                    val mappedByteBuffer = FileInputStream(assetFileDescriptor.fileDescriptor).channel
                        .map(FileChannel.MapMode.READ_ONLY, assetFileDescriptor.startOffset, assetFileDescriptor.declaredLength)

                    val options = Interpreter.Options()
                    options.addDelegate(FlexDelegate())
                    
                    interpreter = Interpreter(mappedByteBuffer, options)
                    result.success("Model Loaded")
                } catch (e: Exception) {
                    result.error("LOAD_ERROR", e.message, null)
                }
            } else if (call.method == "predict") {
                try {
                    val input = call.argument<DoubleArray>("input")!!
                    val buffer = ByteBuffer.allocateDirect(1 * 224 * 224 * 3 * 4).order(ByteOrder.nativeOrder())
                    for (d in input) buffer.putFloat(d.toFloat())
                    
                    val output = arrayOf(FloatArray(3))
                    interpreter?.run(buffer, output)
                    result.success(output[0].map { it.toDouble() })
                } catch (e: Exception) {
                    result.error("PREDICT_ERROR", e.message, null)
                }
            }
        }
    }
}