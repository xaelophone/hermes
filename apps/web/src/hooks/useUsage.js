import { useCallback, useEffect, useRef, useState } from 'react';
import { fetchCurrentUsage } from '@hermes/api';

const CACHE_TTL = 30_000; // 30 seconds

export default function useUsage(session) {
  const [usage, setUsage] = useState(null);
  const [loading, setLoading] = useState(true);
  const lastFetchRef = useRef(0);

  const refresh = useCallback(async (force = false) => {
    if (!session?.access_token) return;

    if (!force && Date.now() - lastFetchRef.current < CACHE_TTL) return;

    try {
      const data = await fetchCurrentUsage(session.access_token);
      setUsage(data);
      lastFetchRef.current = Date.now();
    } catch {
      // Usage counter is non-critical — fail silently
    } finally {
      setLoading(false);
    }
  }, [session?.access_token]);

  useEffect(() => {
    if (!session?.access_token) {
      setUsage(null);
      setLoading(false);
      return;
    }
    refresh(true);
  }, [session?.access_token, refresh]);

  return { usage, loading, refresh };
}
