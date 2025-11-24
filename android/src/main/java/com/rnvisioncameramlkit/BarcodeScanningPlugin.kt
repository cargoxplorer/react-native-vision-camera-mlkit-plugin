package com.rnvisioncameramlkit

import android.graphics.Point
import android.graphics.Rect
import android.media.Image
import com.facebook.react.bridge.WritableNativeArray
import com.facebook.react.bridge.WritableNativeMap
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.mrousavy.camera.frameprocessors.Frame
import com.mrousavy.camera.frameprocessors.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessors.VisionCameraProxy
import com.rnvisioncameramlkit.utils.ImageUtils
import com.rnvisioncameramlkit.utils.Logger
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Barcode Scanning Frame Processor Plugin
 *
 * Performs on-device barcode scanning using Google ML Kit
 * Supports 1D and 2D formats with structured data extraction
 */
class BarcodeScanningPlugin(
    proxy: VisionCameraProxy,
    options: Map<String, Any>?
) : FrameProcessorPlugin(), AutoCloseable {

    private var scanner: BarcodeScanner
    private val isProcessing = AtomicBoolean(false)
    private var detectInvertedBarcodes: Boolean = false
    private var tryRotations: Boolean = true  // Try 90 degree rotation if no barcodes found (default: enabled)
    // Reusable buffers to avoid per-frame allocations during inversion
    // Note: Only Y buffer needed since we use grayscale (not YUV→RGB)
    private var invertedYBuffer: ByteArray? = null
    private var rgbIntBuffer: IntArray? = null
    // Note: We cannot reuse bitmap objects because ML Kit reads them asynchronously.
    // Reusing bitmaps causes memory corruption when frames overlap during processing.

    init {
        Logger.info("Initializing barcode scanner")

        // Extract options
        detectInvertedBarcodes = options?.get("detectInvertedBarcodes") as? Boolean ?: false
        if (detectInvertedBarcodes) {
            Logger.warn("⚠️ Inverted barcode detection ENABLED - adds 30-40ms per frame when no barcodes found. Only enable if you specifically need white-on-black barcodes.")
        }

        // 90 degree rotation attempts: try both current rotation and 90 degrees (default: enabled)
        // Set tryRotations=false if camera orientation is fixed to skip secondary rotation attempts
        tryRotations = options?.get("tryRotations") as? Boolean ?: true
        if (!tryRotations) {
            Logger.info("90 degree rotation attempts DISABLED - only using current camera rotation (saves ~10-20ms per frame)")
        }

        val formats = options?.get("formats") as? List<*>
        val scannerOptions = if (formats != null && formats.isNotEmpty()) {
            Logger.debug("Parsing ${formats.size} barcode format(s) from options: $formats")

            val barcodeFormats = formats.mapNotNull { formatString ->
                val formatStr = formatString.toString()
                val parsedFormat = parseBarcodeFormat(formatStr)
                if (parsedFormat == null) {
                    Logger.error("FAILED to parse barcode format: '$formatStr'")
                } else {
                    Logger.debug("Successfully parsed format: '$formatStr' -> format code: $parsedFormat")
                }
                parsedFormat
            }

            if (barcodeFormats.isEmpty()) {
                Logger.error("No valid barcode formats could be parsed! Original formats: $formats. Falling back to FORMAT_ALL_FORMATS")
                BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
                    .build()
            } else {
                Logger.info("Scanning ${barcodeFormats.size} barcode format(s): ${barcodeFormats.map { it }}")
                BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(
                        barcodeFormats.first(),
                        *barcodeFormats.drop(1).toIntArray()
                    )
                    .build()
            }
        } else {
            Logger.info("No format filter specified, scanning all barcode formats")
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
                .build()
        }

        scanner = BarcodeScanning.getClient(scannerOptions)
        Logger.info("Barcode scanner initialized successfully")
    }

    /**
     * Cleanup resources when plugin is destroyed.
     * Note: Vision Camera v4 does not provide explicit lifecycle callbacks for plugins.
     * ML Kit's BarcodeScanner implements Closeable, so resources will be freed when
     * the plugin instance is garbage collected. For manual cleanup, this method can
     * be called externally if needed.
     */
    override fun close() {
        try {
            // Clear buffer arrays to allow GC
            invertedYBuffer = null
            rgbIntBuffer = null

            // Clear ImageUtils thread-local buffers
            ImageUtils.clearBuffers()

            // Close ML Kit scanner to release native resources
            scanner.close()
            Logger.debug("Barcode scanner resources cleaned up successfully")
        } catch (e: Exception) {
            Logger.error("Error cleaning up barcode scanner resources", e)
        }
    }

    override fun callback(frame: Frame, arguments: Map<String, Any>?): Any? {
        // Skip frame if previous processing is still in progress
        if (!isProcessing.compareAndSet(false, true)) {
            if (Logger.isDebugEnabled()) {
                Logger.debug("Skipping frame - previous processing still in progress")
            }
            return null
        }

        val startTime = System.currentTimeMillis()

        try {
            val mediaImage: Image = frame.image
            val baseRotation = frame.imageProxy.imageInfo.rotationDegrees

            if (Logger.isDebugEnabled()) {
                Logger.debug("Processing frame: ${frame.width}x${frame.height}, rotation: $baseRotation")
            }

            // CRITICAL: Clone image to bitmap IMMEDIATELY to release the camera's Image buffer.
            // This prevents "maxImages (6) has already been acquired" errors.
            // The ImageReader has a limited buffer, and holding Image references during
            // ML Kit processing causes the buffer to fill up and crash.
            val clonedBitmap = ImageUtils.imageToBitmap(mediaImage, 0)  // Don't apply rotation yet
            if (clonedBitmap == null) {
                Logger.error("Failed to clone camera image to bitmap")
                return null
            }

            // Try scanning at current rotation and optionally 90 degree rotation
            val rotations = if (tryRotations) {
                listOf(baseRotation, (baseRotation + 90) % 360)
            } else {
                listOf(baseRotation)  // Only try current rotation
            }
            var barcodes: List<Barcode> = emptyList()

            try {
                // 1. Try normal image at current rotation (using cloned bitmap)
                val image = InputImage.fromBitmap(clonedBitmap, rotations[0])
                val task: Task<List<Barcode>> = scanner.process(image)
                barcodes = Tasks.await(task)

                if (barcodes.isNotEmpty()) {
                    if (Logger.isDebugEnabled()) {
                        Logger.debug("Found ${barcodes.size} barcode(s) at rotation ${rotations[0]}")
                    }
                } else if (tryRotations && rotations.size > 1) {
                    // 2. Try normal image at 90 degree rotation (only if tryRotations is enabled)
                    if (Logger.isDebugEnabled()) {
                        Logger.debug("No barcodes at rotation ${rotations[0]}, trying ${rotations[1]}")
                    }
                    val image90 = InputImage.fromBitmap(clonedBitmap, rotations[1])
                    val task90: Task<List<Barcode>> = scanner.process(image90)
                    barcodes = Tasks.await(task90)

                    if (barcodes.isNotEmpty() && Logger.isDebugEnabled()) {
                        Logger.debug("Found ${barcodes.size} barcode(s) at rotation ${rotations[1]}")
                    }
                }

                // 3. If no barcodes found and inverted detection is enabled, try inverted images
                if (barcodes.isEmpty() && detectInvertedBarcodes) {
                    if (Logger.isDebugEnabled()) {
                        Logger.debug("No barcodes in normal image, attempting inverted image scan...")
                    }

                    val startInvertTime = System.currentTimeMillis()

                    // Create a single inverted Bitmap from the cloned bitmap (not the original mediaImage)
                    val invertedBitmap = createInvertedBitmapFromBitmap(clonedBitmap)

                    if (invertedBitmap != null) {
                        try {
                            // Try inverted at current rotation
                            val invertedImage = InputImage.fromBitmap(invertedBitmap, rotations[0])
                            val invertedTask: Task<List<Barcode>> = scanner.process(invertedImage)
                            barcodes = Tasks.await(invertedTask)

                            if (barcodes.isNotEmpty()) {
                                if (Logger.isDebugEnabled()) {
                                    Logger.debug("Found ${barcodes.size} barcode(s) in inverted image at rotation ${rotations[0]}")
                                }
                            } else if (tryRotations && rotations.size > 1) {
                                // Try inverted at 90 degree rotation (only if tryRotations is enabled)
                                if (Logger.isDebugEnabled()) {
                                    Logger.debug("No barcodes in inverted at ${rotations[0]}, trying ${rotations[1]}")
                                }

                                val invertedImage90 = InputImage.fromBitmap(invertedBitmap, rotations[1])
                                val invertedTask90: Task<List<Barcode>> = scanner.process(invertedImage90)
                                barcodes = Tasks.await(invertedTask90)

                                if (barcodes.isNotEmpty() && Logger.isDebugEnabled()) {
                                    Logger.debug("Found ${barcodes.size} barcode(s) in inverted image at rotation ${rotations[1]}")
                                }
                            }
                        } finally {
                            invertedBitmap.recycle()
                        }
                    }

                    val invertTime = System.currentTimeMillis() - startInvertTime
                    Logger.performance("Inverted image scan", invertTime)
                }

                val processingTime = System.currentTimeMillis() - startTime
                Logger.performance("Barcode scanning processing", processingTime)

                if (barcodes.isEmpty()) {
                    if (Logger.isDebugEnabled()) {
                        Logger.debug("No barcodes detected in frame (tried all rotations)")
                    }
                    return null
                }

                if (Logger.isDebugEnabled()) {
                    Logger.debug("Barcodes detected: ${barcodes.size} barcode(s)")
                }

                val result = WritableNativeMap().apply {
                    putArray("barcodes", processBarcodes(barcodes))
                }

                return result.toHashMap()
            } finally {
                // Always recycle the cloned bitmap to free memory
                clonedBitmap.recycle()
            }

        } catch (e: Exception) {
            val processingTime = System.currentTimeMillis() - startTime
            Logger.error("Error during barcode scanning", e)
            Logger.performance("Barcode scanning processing (error)", processingTime)
            return null
        } finally {
            isProcessing.set(false)
        }
    }

    /**
     * Create an inverted version of a Bitmap for detecting white-on-black barcodes.
     * This method takes an already-cloned bitmap and inverts its pixel values.
     *
     * @param sourceBitmap The bitmap to invert (will NOT be modified or recycled)
     * @return A new inverted bitmap, or null on failure
     */
    private fun createInvertedBitmapFromBitmap(sourceBitmap: android.graphics.Bitmap): android.graphics.Bitmap? {
        return try {
            val width = sourceBitmap.width
            val height = sourceBitmap.height
            val pixelCount = width * height

            // Ensure reusable buffer is allocated
            val requiredSize = pixelCount
            if (rgbIntBuffer == null || rgbIntBuffer!!.size < requiredSize) {
                rgbIntBuffer = IntArray(requiredSize)
            }
            val pixels = rgbIntBuffer!!

            // Get all pixels from source bitmap
            sourceBitmap.getPixels(pixels, 0, width, 0, 0, width, height)

            // Invert each pixel (preserve alpha, invert RGB)
            for (i in 0 until pixelCount) {
                val pixel = pixels[i]
                val alpha = pixel and 0xFF000000.toInt()
                val r = (pixel shr 16) and 0xFF
                val g = (pixel shr 8) and 0xFF
                val b = pixel and 0xFF
                // Invert RGB values
                pixels[i] = alpha or ((255 - r) shl 16) or ((255 - g) shl 8) or (255 - b)
            }

            // Create new bitmap with inverted pixels
            val invertedBitmap = android.graphics.Bitmap.createBitmap(
                width,
                height,
                android.graphics.Bitmap.Config.ARGB_8888
            )
            invertedBitmap.setPixels(pixels, 0, width, 0, 0, width, height)

            if (Logger.isDebugEnabled()) {
                Logger.debug("Created inverted bitmap: ${width}x${height}")
            }

            invertedBitmap
        } catch (e: Exception) {
            Logger.error("Failed to create inverted bitmap from bitmap", e)
            null
        }
    }

    /**
     * Create an inverted version of the image for detecting white-on-black barcodes.
     * Inverts the Y plane pixels (for YUV_420_888 format) and converts to grayscale Bitmap.
     *
     * NOTE: This method is kept for backwards compatibility but is no longer used
     * since we now clone images to bitmaps first. Use createInvertedBitmapFromBitmap instead.
     *
     * PERFORMANCE OPTIMIZATION:
     * - Uses grayscale (Y plane only) instead of full YUV→RGB conversion
     * - Skips U/V plane processing (not needed for barcode edge detection)
     * - Single-pass inversion with integer math only
     * - ~4-5x faster than YUV→RGB approach
     *
     * Critical: We MUST create a new image because ML Kit reads the image data
     * at processing time, so modifying buffers in-place doesn't work.
     * Solution: Convert inverted Y plane to grayscale Bitmap that ML Kit can process.
     *
     * Fixed: Now properly handles YUV plane stride and pixel stride to avoid
     * crashes and corruption on devices with non-contiguous plane layouts.
     *
     * Performance: Uses reusable buffers stored on the plugin instance to avoid
     * per-frame allocations.
     */
    @Suppress("unused")
    private fun createInvertedBitmap(mediaImage: Image): android.graphics.Bitmap? {
        return try {
            val width = mediaImage.width
            val height = mediaImage.height

            // Extract Y plane only (brightness/luminance information)
            val yPlane = mediaImage.planes[0]
            val yRowStride = yPlane.rowStride
            val yPixelStride = yPlane.pixelStride

            // Ensure reusable buffer is allocated with sufficient size
            val requiredYSize = width * height
            if (invertedYBuffer == null || invertedYBuffer!!.size < requiredYSize) {
                invertedYBuffer = ByteArray(requiredYSize)
            }
            val yData = invertedYBuffer!!

            // Copy and invert Y plane.
            // FAST PATH: contiguous Y plane (most devices) -> bulk copy + tight loop
            val yBuffer = yPlane.buffer
            yBuffer.rewind()

            if (yPixelStride == 1 && yRowStride == width) {
                // Contiguous layout, we can read all pixels in one go.
                if (yBuffer.hasArray() && yBuffer.arrayOffset() == 0 && yBuffer.capacity() >= requiredYSize) {
                    val src = yBuffer.array()
                    for (i in 0 until requiredYSize) {
                        yData[i] = (255 - (src[i].toInt() and 0xFF)).toByte()
                    }
                } else {
                    // Fallback to copying into a temporary array first.
                    val tmp = ByteArray(requiredYSize)
                    yBuffer.get(tmp, 0, requiredYSize)
                    for (i in 0 until requiredYSize) {
                        yData[i] = (255 - (tmp[i].toInt() and 0xFF)).toByte()
                    }
                }
            } else {
                // GENERIC PATH: handle arbitrary row/pixel strides safely.
                for (row in 0 until height) {
                    val rowBase = row * yRowStride
                    var colBase = rowBase
                    val arrayRowOffset = row * width
                    for (col in 0 until width) {
                        val value = yBuffer.get(colBase).toInt() and 0xFF
                        // INVERT: brightness (0->255, 255->0) using integer math
                        yData[arrayRowOffset + col] = (255 - value).toByte()
                        colBase += yPixelStride
                    }
                }
            }

            if (Logger.isDebugEnabled()) {
                Logger.debug("Creating inverted grayscale bitmap: ${width}x${height}, Y plane inverted (fastPath=${yPixelStride == 1 && yRowStride == width})")
            }

            // Convert inverted Y plane to grayscale Bitmap for ML Kit
            // Note: A new bitmap is created for each frame to avoid corruption during async processing
            yToGrayscaleBitmap(width, height, yData)
        } catch (e: Exception) {
            Logger.error("Failed to create inverted bitmap", e)
            null
        }
    }

    /**
     * Convert inverted Y plane to grayscale Bitmap
     *
     * PERFORMANCE OPTIMIZATION (vs YUV→RGB):
     * - Single loop iteration (was 2 nested loops for YUV→RGB)
     * - Integer bit operations only (was floating-point for color formula)
     * - No U/V plane processing (was 2 additional plane iterations)
     * - No Color.rgb() calls (allocations avoided)
     * - ~4-5x faster than YUV→RGB approach
     *
     * IMPORTANT: Creates a new bitmap for each frame. We cannot reuse bitmaps because
     * ML Kit processes images asynchronously. If we reuse the same bitmap object and
     * modify it while ML Kit is still reading from a previous frame, we get memory
     * corruption and crashes. The buffer arrays (rgbIntBuffer) can be reused safely
     * since they're not shared with ML Kit.
     *
     * For barcode detection, grayscale brightness is sufficient for edge detection.
     * Color information is unnecessary and adds computational overhead.
     */
    private fun yToGrayscaleBitmap(width: Int, height: Int, yData: ByteArray): android.graphics.Bitmap {
        val pixelCount = width * height
        val requiredSize = pixelCount
        if (rgbIntBuffer == null || rgbIntBuffer!!.size < requiredSize) {
            rgbIntBuffer = IntArray(requiredSize)
        }
        val rgb = rgbIntBuffer!!

        // Create grayscale bitmap - single pass, integer math only
        // Format: ARGB with R=G=B for grayscale (standard grayscale representation)
        for (i in 0 until pixelCount) {
            val gray = yData[i].toInt() and 0xFF
            // Bit operations are faster than Color.rgb() call
            // Format: 0xFF000000 (opaque alpha) | (gray << 16) | (gray << 8) | gray
            rgb[i] = -0x1000000 or (gray shl 16) or (gray shl 8) or gray
        }

        // Always create a new bitmap - ML Kit needs stable pixel data during async processing
        val bitmap = android.graphics.Bitmap.createBitmap(
            width,
            height,
            android.graphics.Bitmap.Config.RGB_565
        )
        bitmap.setPixels(rgb, 0, width, 0, 0, width, height)
        return bitmap
    }

    companion object {
        /**
         * Parse barcode format string to ML Kit format constant
         */
        private fun parseBarcodeFormat(format: String): Int? {
            return when (format.lowercase()) {
                "codabar" -> Barcode.FORMAT_CODABAR
                "code39" -> Barcode.FORMAT_CODE_39
                "code93" -> Barcode.FORMAT_CODE_93
                "code128" -> Barcode.FORMAT_CODE_128
                "ean8" -> Barcode.FORMAT_EAN_8
                "ean13" -> Barcode.FORMAT_EAN_13
                "itf" -> Barcode.FORMAT_ITF
                "upca" -> Barcode.FORMAT_UPC_A
                "upce" -> Barcode.FORMAT_UPC_E
                "aztec" -> Barcode.FORMAT_AZTEC
                "datamatrix" -> Barcode.FORMAT_DATA_MATRIX
                "pdf417" -> Barcode.FORMAT_PDF417
                "qrcode" -> Barcode.FORMAT_QR_CODE
                else -> {
                    Logger.warn("Unknown barcode format: $format")
                    null
                }
            }
        }

        /**
         * Convert ML Kit barcode format to string
         */
        private fun barcodeFormatToString(format: Int): String {
            return when (format) {
                Barcode.FORMAT_CODABAR -> "codabar"
                Barcode.FORMAT_CODE_39 -> "code39"
                Barcode.FORMAT_CODE_93 -> "code93"
                Barcode.FORMAT_CODE_128 -> "code128"
                Barcode.FORMAT_EAN_8 -> "ean8"
                Barcode.FORMAT_EAN_13 -> "ean13"
                Barcode.FORMAT_ITF -> "itf"
                Barcode.FORMAT_UPC_A -> "upca"
                Barcode.FORMAT_UPC_E -> "upce"
                Barcode.FORMAT_AZTEC -> "aztec"
                Barcode.FORMAT_DATA_MATRIX -> "datamatrix"
                Barcode.FORMAT_PDF417 -> "pdf417"
                Barcode.FORMAT_QR_CODE -> "qrcode"
                else -> "unknown"
            }
        }

        /**
         * Convert ML Kit value type to string
         */
        private fun valueTypeToString(valueType: Int): String {
            return when (valueType) {
                Barcode.TYPE_TEXT -> "text"
                Barcode.TYPE_URL -> "url"
                Barcode.TYPE_EMAIL -> "email"
                Barcode.TYPE_PHONE -> "phone"
                Barcode.TYPE_SMS -> "sms"
                Barcode.TYPE_WIFI -> "wifi"
                Barcode.TYPE_GEO -> "geo"
                Barcode.TYPE_CONTACT_INFO -> "contact"
                Barcode.TYPE_CALENDAR_EVENT -> "calendarEvent"
                Barcode.TYPE_DRIVER_LICENSE -> "driverLicense"
                else -> "unknown"
            }
        }

        /**
         * Process barcodes into React Native compatible format
         */
        private fun processBarcodes(barcodes: List<Barcode>): WritableNativeArray {
            val barcodeArray = WritableNativeArray()

            for (barcode in barcodes) {
                val barcodeMap = WritableNativeMap().apply {
                    putString("rawValue", barcode.rawValue ?: "")
                    putString("displayValue", barcode.displayValue ?: "")
                    putString("format", barcodeFormatToString(barcode.format))
                    putString("valueType", valueTypeToString(barcode.valueType))

                    // Bounding box and corner points
                    putMap("frame", processRect(barcode.boundingBox))
                    putArray("cornerPoints", processCornerPoints(barcode.cornerPoints))

                    // Structured data based on type
                    when (barcode.valueType) {
                        Barcode.TYPE_WIFI -> {
                            barcode.wifi?.let { wifi ->
                                putMap("wifi", WritableNativeMap().apply {
                                    putString("ssid", wifi.ssid ?: "")
                                    putString("password", wifi.password ?: "")
                                    putString("encryptionType", when (wifi.encryptionType) {
                                        Barcode.WiFi.TYPE_OPEN -> "open"
                                        Barcode.WiFi.TYPE_WPA -> "wpa"
                                        Barcode.WiFi.TYPE_WEP -> "wep"
                                        else -> "unknown"
                                    })
                                })
                            }
                        }
                        Barcode.TYPE_URL -> {
                            barcode.url?.let { url ->
                                putString("url", url.url ?: "")
                            }
                        }
                        Barcode.TYPE_EMAIL -> {
                            barcode.email?.let { email ->
                                putString("email", email.address ?: "")
                            }
                        }
                        Barcode.TYPE_PHONE -> {
                            barcode.phone?.let { phone ->
                                putString("phone", phone.number ?: "")
                            }
                        }
                        Barcode.TYPE_SMS -> {
                            barcode.sms?.let { sms ->
                                putMap("sms", WritableNativeMap().apply {
                                    putString("phoneNumber", sms.phoneNumber ?: "")
                                    putString("message", sms.message ?: "")
                                })
                            }
                        }
                        Barcode.TYPE_GEO -> {
                            barcode.geoPoint?.let { geo ->
                                putMap("geo", WritableNativeMap().apply {
                                    putDouble("latitude", geo.lat)
                                    putDouble("longitude", geo.lng)
                                })
                            }
                        }
                        Barcode.TYPE_CONTACT_INFO -> {
                            barcode.contactInfo?.let { contact ->
                                putMap("contact", WritableNativeMap().apply {
                                    contact.name?.let { name ->
                                        putString("name", "${name.first ?: ""} ${name.last ?: ""}".trim())
                                    }
                                    putString("organization", contact.organization ?: "")

                                    contact.phones?.let { phones ->
                                        val phoneArray = WritableNativeArray()
                                        phones.forEach { phone ->
                                            phoneArray.pushString(phone.number ?: "")
                                        }
                                        putArray("phones", phoneArray)
                                    }

                                    contact.emails?.let { emails ->
                                        val emailArray = WritableNativeArray()
                                        emails.forEach { email ->
                                            emailArray.pushString(email.address ?: "")
                                        }
                                        putArray("emails", emailArray)
                                    }

                                    contact.urls?.let { urls ->
                                        val urlArray = WritableNativeArray()
                                        urls.forEach { url ->
                                            urlArray.pushString(url ?: "")
                                        }
                                        putArray("urls", urlArray)
                                    }

                                    contact.addresses?.let { addresses ->
                                        val addressArray = WritableNativeArray()
                                        addresses.forEach { address ->
                                            val addressLines = listOfNotNull(
                                                address.addressLines?.joinToString(", ")
                                            )
                                            addressArray.pushString(addressLines.joinToString(" "))
                                        }
                                        putArray("addresses", addressArray)
                                    }
                                })
                            }
                        }
                        Barcode.TYPE_CALENDAR_EVENT -> {
                            barcode.calendarEvent?.let { event ->
                                putMap("calendarEvent", WritableNativeMap().apply {
                                    putString("summary", event.summary ?: "")
                                    putString("description", event.description ?: "")
                                    putString("location", event.location ?: "")
                                    event.start?.let { start ->
                                        putString("start", start.rawValue ?: "")
                                    }
                                    event.end?.let { end ->
                                        putString("end", end.rawValue ?: "")
                                    }
                                })
                            }
                        }
                        Barcode.TYPE_DRIVER_LICENSE -> {
                            barcode.driverLicense?.let { license ->
                                putMap("driverLicense", WritableNativeMap().apply {
                                    putString("documentType", license.documentType ?: "")
                                    putString("firstName", license.firstName ?: "")
                                    putString("lastName", license.lastName ?: "")
                                    putString("gender", license.gender ?: "")
                                    putString("addressStreet", license.addressStreet ?: "")
                                    putString("addressCity", license.addressCity ?: "")
                                    putString("addressState", license.addressState ?: "")
                                    putString("addressZip", license.addressZip ?: "")
                                    putString("licenseNumber", license.licenseNumber ?: "")
                                    putString("issueDate", license.issueDate ?: "")
                                    putString("expiryDate", license.expiryDate ?: "")
                                    putString("birthDate", license.birthDate ?: "")
                                    putString("issuingCountry", license.issuingCountry ?: "")
                                })
                            }
                        }
                    }
                }
                barcodeArray.pushMap(barcodeMap)
            }

            return barcodeArray
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
