package com.rnvisioncameramlkit.utils

import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import java.io.ByteArrayOutputStream

/**
 * Utility class for efficient image cloning and conversion.
 * 
 * Purpose: Clone camera Image data to Bitmap to release the original Image immediately.
 * This prevents "maxImages has already been acquired" errors when ML Kit processing
 * takes longer than the camera frame rate.
 * 
 * The ImageReader used by CameraX has a limited buffer (typically 6 images).
 * If we hold references to Image objects during ML Kit processing, the buffer fills up.
 * By copying to a Bitmap first, we can release the original Image immediately.
 */
object ImageUtils {

    // Reusable buffers to avoid per-frame allocations
    // ThreadLocal ensures thread safety when multiple frame processors run concurrently
    private val nv21BufferLocal = ThreadLocal<ByteArray>()
    private val jpegBufferLocal = ThreadLocal<ByteArrayOutputStream>()

    /**
     * Clone an Image to a Bitmap for independent processing.
     * 
     * This method extracts pixel data from the camera Image and creates a new Bitmap.
     * The original Image can be released immediately after this call returns.
     * 
     * @param image The camera Image (YUV_420_888 format)
     * @param rotationDegrees Rotation to apply (0, 90, 180, 270)
     * @return A new Bitmap containing the image data, or null on failure
     */
    fun imageToBitmap(image: Image, rotationDegrees: Int = 0): Bitmap? {
        return try {
            when (image.format) {
                ImageFormat.YUV_420_888 -> yuv420ToBitmap(image, rotationDegrees)
                ImageFormat.JPEG -> jpegToBitmap(image, rotationDegrees)
                else -> {
                    Logger.warn("Unsupported image format: ${image.format}, attempting YUV conversion")
                    yuv420ToBitmap(image, rotationDegrees)
                }
            }
        } catch (e: Exception) {
            val formatDetails = if (image.format == ImageFormat.YUV_420_888) {
                "pixelStride=${image.planes[1].pixelStride}, rowStride=${image.planes[1].rowStride}"
            } else {
                ""
            }
            Logger.error("Failed to convert image to bitmap (format=${image.format} ${formatDetails})", e)
            null
        }
    }

    /**
     * Convert YUV_420_888 image to Bitmap via NV21 intermediate format.
     * 
     * Performance notes:
     * - Uses reusable buffers to minimize GC pressure
     * - YUV -> NV21 -> JPEG -> Bitmap pipeline is well-optimized on Android
     * - Alternative: RenderScript (deprecated) or direct pixel manipulation (slower)
     */
    private fun yuv420ToBitmap(image: Image, rotationDegrees: Int): Bitmap? {
        val width = image.width
        val height = image.height

        // Get or create reusable NV21 buffer
        val requiredSize = width * height * 3 / 2  // NV21 size: Y + UV interleaved
        var nv21Buffer = nv21BufferLocal.get()
        if (nv21Buffer == null || nv21Buffer.size < requiredSize) {
            nv21Buffer = ByteArray(requiredSize)
            nv21BufferLocal.set(nv21Buffer)
        }

        // Convert YUV_420_888 to NV21
        imageToNv21(image, nv21Buffer)

        // Get or create reusable JPEG output stream
        var jpegStream = jpegBufferLocal.get()
        if (jpegStream == null) {
            jpegStream = ByteArrayOutputStream(width * height / 4)  // JPEG is typically ~25% of raw
            jpegBufferLocal.set(jpegStream)
        } else {
            jpegStream.reset()
        }

        // Convert NV21 to JPEG (uses hardware-accelerated codec)
        val yuvImage = YuvImage(nv21Buffer, ImageFormat.NV21, width, height, null)
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 90, jpegStream)

        // Decode JPEG to Bitmap
        val jpegBytes = jpegStream.toByteArray()
        var bitmap = android.graphics.BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)

        // Apply rotation if needed
        if (rotationDegrees != 0 && bitmap != null) {
            val matrix = Matrix()
            matrix.postRotate(rotationDegrees.toFloat())
            val rotatedBitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotatedBitmap != bitmap) {
                bitmap.recycle()
            }
            bitmap = rotatedBitmap
        }

        return bitmap
    }

    /**
     * Convert YUV_420_888 Image to NV21 byte array.
     * 
     * YUV_420_888 layout varies by device:
     * - Some devices have interleaved UV (NV21-like)
     * - Some have planar UV (I420-like)
     * 
     * This method handles both cases by checking pixel stride.
     */
    private fun imageToNv21(image: Image, nv21: ByteArray) {
        val width = image.width
        val height = image.height
        val yPlane = image.planes[0]
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]

        val yBuffer = yPlane.buffer
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer

        val yRowStride = yPlane.rowStride
        val uvRowStride = uPlane.rowStride
        val uvPixelStride = uPlane.pixelStride

        // Copy Y plane
        var yPos = 0
        for (row in 0 until height) {
            yBuffer.position(row * yRowStride)
            yBuffer.get(nv21, yPos, width)
            yPos += width
        }

        // Copy UV planes (interleaved as VU for NV21)
        val uvHeight = height / 2
        val uvWidth = width / 2
        var uvPos = width * height

        if (uvPixelStride == 2) {
            // UV data is interleaved (e.g., VUVUVU...) - common on most devices
            // pixelStride == 2 means each color component occupies 2 bytes
            for (row in 0 until uvHeight) {
                val rowOffset = row * uvRowStride
                for (col in 0 until uvWidth) {
                    val pixelOffset = rowOffset + col * 2
                    nv21[uvPos++] = vBuffer.get(pixelOffset)
                    nv21[uvPos++] = uBuffer.get(pixelOffset)
                }
            }
        } else {
            // UV data is planar (pixelStride == 1) - separate U and V planes
            for (row in 0 until uvHeight) {
                val rowOffset = row * uvRowStride
                for (col in 0 until uvWidth) {
                    nv21[uvPos++] = vBuffer.get(rowOffset + col)
                    nv21[uvPos++] = uBuffer.get(rowOffset + col)
                }
            }
        }
    }

    /**
     * Convert JPEG Image to Bitmap (simple case).
     */
    private fun jpegToBitmap(image: Image, rotationDegrees: Int): Bitmap? {
        val buffer = image.planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)

        var bitmap = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)

        if (rotationDegrees != 0 && bitmap != null) {
            val matrix = Matrix()
            matrix.postRotate(rotationDegrees.toFloat())
            val rotatedBitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotatedBitmap != bitmap) {
                bitmap.recycle()
            }
            bitmap = rotatedBitmap
        }

        return bitmap
    }

    /**
     * Clear thread-local buffers to free memory.
     * Call this when the plugin is being destroyed.
     */
    fun clearBuffers() {
        nv21BufferLocal.remove()
        jpegBufferLocal.remove()
    }
}

