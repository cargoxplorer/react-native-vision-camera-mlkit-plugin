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
import com.rnvisioncameramlkit.utils.Logger

/**
 * Barcode Scanning Frame Processor Plugin
 *
 * Performs on-device barcode scanning using Google ML Kit
 * Supports 1D and 2D formats with structured data extraction
 */
class BarcodeScanningPlugin(
    proxy: VisionCameraProxy,
    options: Map<String, Any>?
) : FrameProcessorPlugin() {

    private var scanner: BarcodeScanner
    private var detectInvertedBarcodes: Boolean = false

    init {
        Logger.info("Initializing barcode scanner")

        // Extract options
        detectInvertedBarcodes = options?.get("detectInvertedBarcodes") as? Boolean ?: false
        if (detectInvertedBarcodes) {
            Logger.info("Inverted barcode detection enabled")
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

    override fun callback(frame: Frame, arguments: Map<String, Any>?): Any? {
        val startTime = System.currentTimeMillis()

        try {
            val mediaImage: Image = frame.image
            val image = InputImage.fromMediaImage(
                mediaImage,
                frame.imageProxy.imageInfo.rotationDegrees
            )

            Logger.debug("Processing frame: ${frame.width}x${frame.height}, rotation: ${frame.imageProxy.imageInfo.rotationDegrees}")

            // Scan normal image first
            val task: Task<List<Barcode>> = scanner.process(image)
            var barcodes: List<Barcode> = Tasks.await(task)

            // If no barcodes found and inverted detection is enabled, try inverted image
            if (barcodes.isEmpty() && detectInvertedBarcodes) {
                Logger.debug("No barcodes in normal image, attempting inverted image scan...")

                val startInvertTime = System.currentTimeMillis()
                val invertedImage = createInvertedImage(mediaImage, frame.imageProxy.imageInfo.rotationDegrees)

                if (invertedImage != null) {
                    val invertedTask: Task<List<Barcode>> = scanner.process(invertedImage)
                    val invertedBarcodes: List<Barcode> = Tasks.await(invertedTask)

                    val invertTime = System.currentTimeMillis() - startInvertTime
                    Logger.performance("Inverted image scan", invertTime)

                    if (invertedBarcodes.isNotEmpty()) {
                        Logger.debug("Found ${invertedBarcodes.size} barcode(s) in inverted image")
                        barcodes = invertedBarcodes
                    }
                }
            }

            val processingTime = System.currentTimeMillis() - startTime
            Logger.performance("Barcode scanning processing", processingTime)

            if (barcodes.isEmpty()) {
                Logger.debug("No barcodes detected in frame")
                return null
            }

            Logger.debug("Barcodes detected: ${barcodes.size} barcode(s)")

            val result = WritableNativeMap().apply {
                putArray("barcodes", processBarcodes(barcodes))
            }

            return result.toHashMap()

        } catch (e: Exception) {
            val processingTime = System.currentTimeMillis() - startTime
            Logger.error("Error during barcode scanning", e)
            Logger.performance("Barcode scanning processing (error)", processingTime)
            return null
        }
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

        /**
         * Create an inverted version of the image for detecting white-on-black barcodes
         * Inverts the Y plane pixels (for YUV_420_888 format)
         * Returns InputImage for ML Kit processing, or null if inversion fails
         *
         * Critical: We MUST create a new image because ML Kit reads the image data
         * at processing time, so modifying buffers in-place doesn't work.
         * Solution: Convert inverted YUV to RGB Bitmap that ML Kit can process.
         */
        private fun createInvertedImage(mediaImage: Image, rotationDegrees: Int): InputImage? {
            return try {
                val width = mediaImage.width
                val height = mediaImage.height

                // Extract YUV planes
                val yPlane = mediaImage.planes[0]
                val uPlane = mediaImage.planes[1]
                val vPlane = mediaImage.planes[2]

                // Copy Y plane and invert it
                val ySize = yPlane.buffer.limit()
                val yData = ByteArray(ySize)
                yPlane.buffer.rewind()
                yPlane.buffer.get(yData)

                // INVERT ONLY Y PLANE: brightness (0->255, 255->0)
                for (i in yData.indices) {
                    yData[i] = (255 - (yData[i].toInt() and 0xFF)).toByte()
                }

                // Copy U and V planes (color info - don't invert)
                val uSize = uPlane.buffer.limit()
                val uData = ByteArray(uSize)
                uPlane.buffer.rewind()
                uPlane.buffer.get(uData)

                val vSize = vPlane.buffer.limit()
                val vData = ByteArray(vSize)
                vPlane.buffer.rewind()
                vPlane.buffer.get(vData)

                Logger.debug("Created inverted image: ${width}x${height}, Y plane inverted")

                // Convert inverted YUV to RGB Bitmap for ML Kit
                val invertedBitmap = yuvToRgbBitmap(width, height, yData, uData, vData)

                // Create InputImage from Bitmap with rotation
                InputImage.fromBitmap(invertedBitmap, rotationDegrees)
            } catch (e: Exception) {
                Logger.error("Failed to create inverted image", e)
                null
            }
        }

        /**
         * Convert YUV420 plane data to RGB Bitmap for ML Kit processing
         * Uses efficient YUV to RGB conversion optimized for barcode detection
         */
        private fun yuvToRgbBitmap(
            width: Int,
            height: Int,
            yData: ByteArray,
            uData: ByteArray,
            vData: ByteArray
        ): android.graphics.Bitmap {
            val rgb = IntArray(width * height)

            // YUV to RGB conversion
            // For barcode detection, we prioritize accuracy over color fidelity
            var yIndex = 0
            var uvIndex = 0

            for (y in 0 until height) {
                for (x in 0 until width) {
                    // Get Y value (brightness)
                    val yVal = (yData[yIndex].toInt() and 0xFF)
                    yIndex++

                    // Get U and V values (color) - sampled every 2x2 pixels in YUV420
                    val uvPixelIndex = (y / 2) * (width / 2) + (x / 2)
                    val uVal = (uData[uvPixelIndex].toInt() and 0xFF) - 128
                    val vVal = (vData[uvPixelIndex].toInt() and 0xFF) - 128

                    // YUV to RGB formula
                    val r = (yVal + 1.370f * vVal).coerceIn(0f, 255f).toInt()
                    val g = (yVal - 0.343f * uVal - 0.711f * vVal).coerceIn(0f, 255f).toInt()
                    val b = (yVal + 1.732f * uVal).coerceIn(0f, 255f).toInt()

                    rgb[y * width + x] = android.graphics.Color.rgb(r, g, b)
                }
            }

            val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.RGB_565)
            bitmap.setPixels(rgb, 0, width, 0, 0, width, height)
            return bitmap
        }
    }
}
