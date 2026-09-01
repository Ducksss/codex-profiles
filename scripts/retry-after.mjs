export function retryAfterDelay(value, fallback, now = Date.now()) {
  if (!Number.isFinite(fallback) || fallback < 0) {
    throw new TypeError('fallback delay must be a non-negative number');
  }
  if (value === null || value === undefined) return fallback;
  const text = String(value).trim();
  if (!text) return fallback;
  const seconds = Number(text);
  if (Number.isFinite(seconds) && seconds >= 0) return seconds * 1000;
  const at = Date.parse(text);
  return Number.isFinite(at) ? Math.max(0, at - now) : fallback;
}
