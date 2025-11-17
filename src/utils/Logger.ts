/**
 * Custom logger for react-native-vision-camera-ml-kit
 * Provides configurable log levels to control verbosity and minimize performance impact
 */

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  NONE = 4,
}

class LoggerClass {
  private currentLogLevel: LogLevel = LogLevel.WARN;

  /**
   * Set the log level. Logs below this level will be ignored.
   * @param level The minimum log level to output
   *
   * @example
   * ```ts
   * import { Logger, LogLevel } from 'react-native-vision-camera-ml-kit';
   *
   * // Enable debug logging
   * Logger.setLogLevel(LogLevel.DEBUG);
   *
   * // Disable all logging
   * Logger.setLogLevel(LogLevel.NONE);
   * ```
   */
  setLogLevel(level: LogLevel): void {
    this.currentLogLevel = level;
    this.info(`Log level set to: ${LogLevel[level]}`);
  }

  /**
   * Get the current log level
   */
  getLogLevel(): LogLevel {
    return this.currentLogLevel;
  }

  /**
   * Log a debug message (for development/troubleshooting)
   * Only logged when log level is DEBUG
   */
  debug(message: string, ...args: unknown[]): void {
    if (this.currentLogLevel <= LogLevel.DEBUG) {
      console.log(`[MLKit:DEBUG] ${message}`, ...args);
    }
  }

  /**
   * Log an informational message
   * Only logged when log level is INFO or below
   */
  info(message: string, ...args: unknown[]): void {
    if (this.currentLogLevel <= LogLevel.INFO) {
      console.log(`[MLKit:INFO] ${message}`, ...args);
    }
  }

  /**
   * Log a warning message
   * Only logged when log level is WARN or below
   */
  warn(message: string, ...args: unknown[]): void {
    if (this.currentLogLevel <= LogLevel.WARN) {
      console.warn(`[MLKit:WARN] ${message}`, ...args);
    }
  }

  /**
   * Log an error message
   * Only logged when log level is ERROR or below
   */
  error(message: string, error?: Error | unknown, ...args: unknown[]): void {
    if (this.currentLogLevel <= LogLevel.ERROR) {
      if (error instanceof Error) {
        console.error(`[MLKit:ERROR] ${message}`, error, ...args);
      } else if (error) {
        console.error(`[MLKit:ERROR] ${message}`, error, ...args);
      } else {
        console.error(`[MLKit:ERROR] ${message}`, ...args);
      }
    }
  }

  /**
   * Log performance metrics (DEBUG level)
   * Useful for monitoring frame processing times
   */
  performance(operation: string, durationMs: number): void {
    this.debug(`⏱️  ${operation}: ${durationMs.toFixed(2)}ms`);
  }
}

export const Logger = new LoggerClass();
