import { useOnlineStatus } from '../hooks/useOnlineStatus';

/**
 * Displays a non-intrusive red banner at the top of the screen when the
 * browser has lost its network connection. Intended to be mounted once
 * inside the main Layout component.
 */
export default function OfflineBanner() {
  const isOnline = useOnlineStatus();

  if (isOnline) return null;

  return (
    <div
      role="alert"
      aria-live="polite"
      className="fixed top-0 left-0 right-0 z-50 bg-red-600 text-white text-center py-2 text-sm font-medium shadow"
    >
      You are offline. Transactions cannot be saved until the connection is restored.
    </div>
  );
}
