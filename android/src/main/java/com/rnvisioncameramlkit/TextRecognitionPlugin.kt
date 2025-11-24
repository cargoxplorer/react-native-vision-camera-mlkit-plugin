package com.rnvisioncameramlkit

import android.graphics.Point
import android.graphics.Rect
import android.media.Image
import com.facebook.react.bridge.WritableNativeArray
import com.facebook.react.bridge.WritableNativeMap
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.TextRecognizerOptionsInterface
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.mrousavy.camera.frameprocessors.Frame
import com.mrousavy.camera.frameprocessors.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessors.VisionCameraProxy
import com.rnvisioncameramlkit.utils.Logger
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Text Recognition v2 Frame Processor Plugin
 *
 * Performs on-device text recognition using Google ML Kit
 * Supports multiple scripts: Latin, Chinese, Devanagari, Japanese, Korean
 */
class TextRecognitionPlugin(
    proxy: VisionCameraProxy,
    options: Map<String, Any>?
) : FrameProcessorPlugin() {

    private var recognizer: TextRecognizer
    private val isProcessing = AtomicBoolean(false)

    init {
        val language = options?.get("language")?.toString() ?: "latin"
        Logger.info("Initializing text recognition with language: $language")

        val recognizerOptions: TextRecognizerOptionsInterface = when (language.lowercase()) {
            "chinese" -> ChineseTextRecognizerOptions.Builder().build()
            "devanagari" -> DevanagariTextRecognizerOptions.Builder().build()
            "japanese" -> JapaneseTextRecognizerOptions.Builder().build()
            "korean" -> KoreanTextRecognizerOptions.Builder().build()
            "latin", "default" -> TextRecognizerOptions.Builder().build()
            else -> {
                Logger.warn("Unknown language '$language', defaulting to Latin")
                TextRecognizerOptions.Builder().build()
            }
        }

        recognizer = TextRecognition.getClient(recognizerOptions)
        Logger.info("Text recognition initialized successfully")
    }

    /**
     * Cleanup resources when plugin is destroyed
     * Called automatically by finalize() when the plugin is garbage collected,
     * or can be called manually to release resources earlier.
     */
    fun cleanup() {
        try {
            // Close ML Kit recognizer to release native resources
            recognizer.close()
            Logger.debug("Text recognizer resources cleaned up successfully")
        } catch (e: Exception) {
            Logger.error("Error cleaning up text recognizer resources", e)
        }
    }

    /**
     * Finalizer to ensure cleanup happens when plugin is garbage collected
     * This prevents memory leaks of ML Kit native resources (models, GPU memory)
     */
    @Suppress("DEPRECATION")
    protected fun finalize() {
        cleanup()
    }

    override fun callback(frame: Frame, arguments: Map<String, Any>?): Any? {
        // Skip frame if previous processing is still in progress
        if (!isProcessing.compareAndSet(false, true)) {
            Logger.debug("Skipping frame - previous processing still in progress")
            return null
        }

        val startTime = System.currentTimeMillis()

        try {
            val mediaImage: Image = frame.image
            val image = InputImage.fromMediaImage(
                mediaImage,
                frame.imageProxy.imageInfo.rotationDegrees
            )

            Logger.debug("Processing frame: ${frame.width}x${frame.height}, rotation: ${frame.imageProxy.imageInfo.rotationDegrees}")

            val task: Task<Text> = recognizer.process(image)
            val text: Text = Tasks.await(task)

            val processingTime = System.currentTimeMillis() - startTime
            Logger.performance("Text recognition processing", processingTime)

            if (text.text.isEmpty()) {
                Logger.debug("No text detected in frame")
                return null
            }

            Logger.debug("Text detected: ${text.text.length} characters, ${text.textBlocks.size} blocks")

            val result = WritableNativeMap().apply {
                putString("text", text.text)
                putArray("blocks", processBlocks(text.textBlocks))
            }

            return result.toHashMap()

        } catch (e: Exception) {
            val processingTime = System.currentTimeMillis() - startTime
            Logger.error("Error during text recognition", e)
            Logger.performance("Text recognition processing (error)", processingTime)
            return null
        } finally {
            isProcessing.set(false)
        }
    }

    companion object {
        /**
         * Process text blocks into React Native compatible format
         */
        private fun processBlocks(blocks: List<Text.TextBlock>): WritableNativeArray {
            val blockArray = WritableNativeArray()

            for (block in blocks) {
                val blockMap = WritableNativeMap().apply {
                    putString("text", block.text)
                    putMap("frame", processRect(block.boundingBox))
                    putArray("cornerPoints", processCornerPoints(block.cornerPoints))
                    putArray("lines", processLines(block.lines))

                    // Add language if recognized
                    block.recognizedLanguage?.let { lang ->
                        putString("recognizedLanguage", lang)
                    }

                    // Add confidence if available (ML Kit doesn't provide this for v2, but keeping for future)
                    // putDouble("confidence", block.confidence?.toDouble() ?: 0.0)
                }
                blockArray.pushMap(blockMap)
            }

            return blockArray
        }

        /**
         * Process text lines into React Native compatible format
         */
        private fun processLines(lines: List<Text.Line>): WritableNativeArray {
            val lineArray = WritableNativeArray()

            for (line in lines) {
                val lineMap = WritableNativeMap().apply {
                    putString("text", line.text)
                    putMap("frame", processRect(line.boundingBox))
                    putArray("cornerPoints", processCornerPoints(line.cornerPoints))
                    putArray("elements", processElements(line.elements))

                    line.recognizedLanguage?.let { lang ->
                        putString("recognizedLanguage", lang)
                    }
                }
                lineArray.pushMap(lineMap)
            }

            return lineArray
        }

        /**
         * Process text elements (words) into React Native compatible format
         */
        private fun processElements(elements: List<Text.Element>): WritableNativeArray {
            val elementArray = WritableNativeArray()

            for (element in elements) {
                val elementMap = WritableNativeMap().apply {
                    putString("text", element.text)
                    putMap("frame", processRect(element.boundingBox))
                    putArray("cornerPoints", processCornerPoints(element.cornerPoints))
                    putArray("symbols", processSymbols(element.symbols))

                    element.recognizedLanguage?.let { lang ->
                        putString("recognizedLanguage", lang)
                    }
                }
                elementArray.pushMap(elementMap)
            }

            return elementArray
        }

        /**
         * Process text symbols (characters) into React Native compatible format
         */
        private fun processSymbols(symbols: List<Text.Symbol>): WritableNativeArray {
            val symbolArray = WritableNativeArray()

            for (symbol in symbols) {
                val symbolMap = WritableNativeMap().apply {
                    putString("text", symbol.text)
                    putMap("frame", processRect(symbol.boundingBox))
                    putArray("cornerPoints", processCornerPoints(symbol.cornerPoints))

                    symbol.recognizedLanguage?.let { lang ->
                        putString("recognizedLanguage", lang)
                    }
                }
                symbolArray.pushMap(symbolMap)
            }

            return symbolArray
        }

        /**
         * Convert Android Rect to React Native format
         */
        private fun processRect(boundingBox: Rect?): WritableNativeMap {
            val rectMap = WritableNativeMap()

            boundingBox?.let { box ->
                rectMap.putDouble("x", box.exactCenterX().toDouble())
                rectMap.putDouble("y", box.exactCenterY().toDouble())
                rectMap.putInt("width", box.width())
                rectMap.putInt("height", box.height())
            }

            return rectMap
        }

        /**
         * Convert Android corner points to React Native format
         */
        private fun processCornerPoints(cornerPoints: Array<Point>?): WritableNativeArray {
            val pointsArray = WritableNativeArray()

            cornerPoints?.forEach { point ->
                val pointMap = WritableNativeMap().apply {
                    putInt("x", point.x)
                    putInt("y", point.y)
                }
                pointsArray.pushMap(pointMap)
            }

            return pointsArray
        }
    }
}
