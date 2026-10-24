'use strict';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) { /* Show a fallback. */ }
  const expired = typeof data.expiresAt === 'number' && Date.now() > data.expiresAt;
  event.waitUntil(self.registration.showNotification(data.title || 'Muslim', {
    // Always show a visible notification, including for malformed/late payloads.
    body: expired ? (data.expiredBody || 'Open Muslim to see current prayer times.') : (data.body || 'Prayer reminder'),
    icon: new URL('icons/Icon-192.png', self.registration.scope).href,
    badge: new URL('icons/Icon-192.png', self.registration.scope).href,
    tag: data.tag || 'muslim-prayer',
    renotify: false,
    data: { url: self.registration.scope },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const scope = self.registration.scope;
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if (client.url.startsWith(scope) && 'focus' in client) return client.focus();
    }
    return self.clients.openWindow(scope);
  })());
});
