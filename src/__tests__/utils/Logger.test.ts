import { Logger, LogLevel } from '../../utils/Logger';

describe('Logger', () => {
  // Store original console methods
  const originalLog = console.log;
  const originalWarn = console.warn;
  const originalError = console.error;

  // Mock console methods
  let mockLog: jest.Mock;
  let mockWarn: jest.Mock;
  let mockError: jest.Mock;

  beforeEach(() => {
    // Create mocks
    mockLog = jest.fn();
    mockWarn = jest.fn();
    mockError = jest.fn();

    // Replace console methods
    console.log = mockLog;
    console.warn = mockWarn;
    console.error = mockError;

    // Reset to default log level
    Logger.setLogLevel(LogLevel.WARN);
    mockLog.mockClear(); // Clear the setLogLevel info message
  });

  afterEach(() => {
    // Restore original console methods
    console.log = originalLog;
    console.warn = originalWarn;
    console.error = originalError;
  });

  describe('setLogLevel', () => {
    it('should set and get log level', () => {
      Logger.setLogLevel(LogLevel.DEBUG);
      expect(Logger.getLogLevel()).toBe(LogLevel.DEBUG);

      Logger.setLogLevel(LogLevel.ERROR);
      expect(Logger.getLogLevel()).toBe(LogLevel.ERROR);
    });

    it('should log info message when setting log level', () => {
      mockLog.mockClear();
      Logger.setLogLevel(LogLevel.INFO);
      expect(mockLog).toHaveBeenCalledWith(
        '[MLKit:INFO] Log level set to: INFO'
      );
    });
  });

  describe('debug', () => {
    it('should log debug messages when level is DEBUG', () => {
      Logger.setLogLevel(LogLevel.DEBUG);
      mockLog.mockClear();

      Logger.debug('Test debug message');
      expect(mockLog).toHaveBeenCalledWith('[MLKit:DEBUG] Test debug message');
    });

    it('should not log debug messages when level is INFO', () => {
      Logger.setLogLevel(LogLevel.INFO);
      mockLog.mockClear();

      Logger.debug('Test debug message');
      expect(mockLog).not.toHaveBeenCalled();
    });

    it('should log debug messages with additional arguments', () => {
      Logger.setLogLevel(LogLevel.DEBUG);
      mockLog.mockClear();

      const obj = { foo: 'bar' };
      Logger.debug('Test with object', obj);
      expect(mockLog).toHaveBeenCalledWith(
        '[MLKit:DEBUG] Test with object',
        obj
      );
    });
  });

  describe('info', () => {
    it('should log info messages when level is INFO', () => {
      Logger.setLogLevel(LogLevel.INFO);
      mockLog.mockClear();

      Logger.info('Test info message');
      expect(mockLog).toHaveBeenCalledWith('[MLKit:INFO] Test info message');
    });

    it('should not log info messages when level is WARN', () => {
      Logger.setLogLevel(LogLevel.WARN);
      mockLog.mockClear();

      Logger.info('Test info message');
      expect(mockLog).not.toHaveBeenCalled();
    });
  });

  describe('warn', () => {
    it('should log warn messages when level is WARN', () => {
      Logger.setLogLevel(LogLevel.WARN);

      Logger.warn('Test warning');
      expect(mockWarn).toHaveBeenCalledWith('[MLKit:WARN] Test warning');
    });

    it('should not log warn messages when level is ERROR', () => {
      Logger.setLogLevel(LogLevel.ERROR);

      Logger.warn('Test warning');
      expect(mockWarn).not.toHaveBeenCalled();
    });
  });

  describe('error', () => {
    it('should log error messages when level is ERROR', () => {
      Logger.setLogLevel(LogLevel.ERROR);

      Logger.error('Test error');
      expect(mockError).toHaveBeenCalledWith('[MLKit:ERROR] Test error');
    });

    it('should log error messages with Error object', () => {
      Logger.setLogLevel(LogLevel.ERROR);

      const error = new Error('Test error object');
      Logger.error('Error occurred', error);
      expect(mockError).toHaveBeenCalledWith(
        '[MLKit:ERROR] Error occurred',
        error
      );
    });

    it('should log error messages with non-Error object', () => {
      Logger.setLogLevel(LogLevel.ERROR);

      const errorData = { code: 500, message: 'Server error' };
      Logger.error('Error occurred', errorData);
      expect(mockError).toHaveBeenCalledWith(
        '[MLKit:ERROR] Error occurred',
        errorData
      );
    });

    it('should not log error messages when level is NONE', () => {
      Logger.setLogLevel(LogLevel.NONE);

      Logger.error('Test error');
      expect(mockError).not.toHaveBeenCalled();
    });
  });

  describe('performance', () => {
    it('should log performance metrics when level is DEBUG', () => {
      Logger.setLogLevel(LogLevel.DEBUG);
      mockLog.mockClear();

      Logger.performance('Frame processing', 12.5);
      expect(mockLog).toHaveBeenCalledWith(
        '[MLKit:DEBUG] ⏱️  Frame processing: 12.50ms'
      );
    });

    it('should not log performance metrics when level is INFO', () => {
      Logger.setLogLevel(LogLevel.INFO);
      mockLog.mockClear();

      Logger.performance('Frame processing', 12.5);
      expect(mockLog).not.toHaveBeenCalled();
    });

    it('should format duration to 2 decimal places', () => {
      Logger.setLogLevel(LogLevel.DEBUG);
      mockLog.mockClear();

      Logger.performance('Test operation', 1.23456789);
      expect(mockLog).toHaveBeenCalledWith(
        '[MLKit:DEBUG] ⏱️  Test operation: 1.23ms'
      );
    });
  });

  describe('log level hierarchy', () => {
    it('should respect DEBUG level (logs everything)', () => {
      Logger.setLogLevel(LogLevel.DEBUG);
      mockLog.mockClear();
      mockWarn.mockClear();
      mockError.mockClear();

      Logger.debug('debug');
      Logger.info('info');
      Logger.warn('warn');
      Logger.error('error');

      expect(mockLog).toHaveBeenCalledTimes(2); // debug + info
      expect(mockWarn).toHaveBeenCalledTimes(1);
      expect(mockError).toHaveBeenCalledTimes(1);
    });

    it('should respect INFO level', () => {
      Logger.setLogLevel(LogLevel.INFO);
      mockLog.mockClear();
      mockWarn.mockClear();
      mockError.mockClear();

      Logger.debug('debug');
      Logger.info('info');
      Logger.warn('warn');
      Logger.error('error');

      expect(mockLog).toHaveBeenCalledTimes(1); // info only
      expect(mockWarn).toHaveBeenCalledTimes(1);
      expect(mockError).toHaveBeenCalledTimes(1);
    });

    it('should respect WARN level', () => {
      Logger.setLogLevel(LogLevel.WARN);
      mockLog.mockClear();
      mockWarn.mockClear();
      mockError.mockClear();

      Logger.debug('debug');
      Logger.info('info');
      Logger.warn('warn');
      Logger.error('error');

      expect(mockLog).not.toHaveBeenCalled();
      expect(mockWarn).toHaveBeenCalledTimes(1);
      expect(mockError).toHaveBeenCalledTimes(1);
    });

    it('should respect ERROR level', () => {
      Logger.setLogLevel(LogLevel.ERROR);
      mockLog.mockClear();
      mockWarn.mockClear();
      mockError.mockClear();

      Logger.debug('debug');
      Logger.info('info');
      Logger.warn('warn');
      Logger.error('error');

      expect(mockLog).not.toHaveBeenCalled();
      expect(mockWarn).not.toHaveBeenCalled();
      expect(mockError).toHaveBeenCalledTimes(1);
    });

    it('should respect NONE level (logs nothing)', () => {
      Logger.setLogLevel(LogLevel.NONE);
      mockLog.mockClear();
      mockWarn.mockClear();
      mockError.mockClear();

      Logger.debug('debug');
      Logger.info('info');
      Logger.warn('warn');
      Logger.error('error');

      expect(mockLog).not.toHaveBeenCalled();
      expect(mockWarn).not.toHaveBeenCalled();
      expect(mockError).not.toHaveBeenCalled();
    });
  });
});
