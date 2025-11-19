import { useEffect } from 'react';
import { AppState, type AppStateStatus } from 'react-native';

/**
 * Custom hook to handle app lifecycle events
 * Pauses camera processing when app goes to background
 * Resumes when app comes back to foreground
 *
 * @param setIsActive - Function to set camera active state
 * @param onPause - Optional callback when app goes to background
 * @param onResume - Optional callback when app comes back to foreground
 */
export function useAppLifecycle(
  setIsActive: (isActive: boolean) => void,
  onPause?: () => void,
  onResume?: () => void
) {
  useEffect(() => {
    const subscription = AppState.addEventListener(
      'change',
      handleAppStateChange
    );

    return () => {
      subscription.remove();
    };
  }, []);

  const handleAppStateChange = (nextAppState: AppStateStatus) => {
    if (nextAppState === 'active') {
      // App is in foreground - resume camera processing
      setIsActive(true);
      onResume?.();
    } else if (nextAppState === 'background' || nextAppState === 'inactive') {
      // App is backgrounded or inactive - stop camera processing
      setIsActive(false);
      onPause?.();
    }
  };
}
