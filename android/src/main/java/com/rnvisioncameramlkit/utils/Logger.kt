package com.rnvisioncameramlkit.utils

import android.util.Log

/**
 * Custom logger for RNVisionCameraMLKit with configurable log levels
 * to control verbosity and minimize performance impact.
 */
object Logger {
  private const val TAG = "RNVisionCameraMLKit"

  enum class LogLevel(val priority: Int) {
    DEBUG(0),
    INFO(1),
    WARN(2),
    ERROR(3),
    NONE(4)
  }

  @Volatile
  private var currentLogLevel: LogLevel = LogLevel.WARN

  /**
   * Set the current log level. Logs below this level will be ignored.
   */
  fun setLogLevel(level: LogLevel) {
    currentLogLevel = level
    info("Log level set to: ${level.name}")
  }

  /**
   * Get the current log level
   */
  fun getLogLevel(): LogLevel = currentLogLevel

  /**
   * Log a debug message
   */
  fun debug(message: String, tag: String = TAG) {
    if (currentLogLevel.priority <= LogLevel.DEBUG.priority) {
      Log.d(tag, message)
    }
  }

  /**
   * Log an info message
   */
  fun info(message: String, tag: String = TAG) {
    if (currentLogLevel.priority <= LogLevel.INFO.priority) {
      Log.i(tag, message)
    }
  }

  /**
   * Log a warning message
   */
  fun warn(message: String, tag: String = TAG) {
    if (currentLogLevel.priority <= LogLevel.WARN.priority) {
      Log.w(tag, message)
    }
  }

  /**
   * Log an error message
   */
  fun error(message: String, throwable: Throwable? = null, tag: String = TAG) {
    if (currentLogLevel.priority <= LogLevel.ERROR.priority) {
      if (throwable != null) {
        Log.e(tag, message, throwable)
      } else {
        Log.e(tag, message)
      }
    }
  }

  /**
   * Log performance metrics (DEBUG level)
   */
  fun performance(message: String, durationMs: Long, tag: String = TAG) {
    debug("⏱️ $message: ${durationMs}ms", tag)
  }
}
