/* Browser-only bridge. No Android notification code or preferences are used. */
(() => {
  'use strict';
  const tokenKey = 'muslim_web_push_token_v1';
  const workerUrl = new URL('prayer_push_worker.js', document.baseURI);
  const fail = (code) => { throw new Error(code); };
  let lastSync = '';
  let activeCall = null;

  function checkSupport() {
    if (!window.isSecureContext || !('serviceWorker' in navigator) ||
        !('PushManager' in window) || !('Notification' in window)) fail('unsupported');
  }

  function baseUrl(value) {
    if (!value) fail('setup_required');
    const url = new URL(value, document.baseURI);
    if (url.protocol !== 'https:' &&
        !(url.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(url.hostname))) {
      fail('setup_required');
    }
    return url.href.replace(/\/$/, '');
  }

  function token(create = false) {
    let value = localStorage.getItem(tokenKey);
    if (!value && create) {
      const bytes = crypto.getRandomValues(new Uint8Array(32));
      value = btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
      localStorage.setItem(tokenKey, value);
    }
    return value;
  }

  async function request(api, path, method = 'GET', body, allowMissing = false) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 45000);
    try {
      const headers = { 'Content-Type': 'application/json' };
      const credential = token();
      if (credential) headers.Authorization = `Bearer ${credential}`;
      const response = await fetch(`${api}${path}`, {
        method, headers, body: body === undefined ? undefined : JSON.stringify(body),
        credentials: 'omit', redirect: 'error', signal: controller.signal,
      });
      if (allowMissing && response.status === 404) return null;
      if (!response.ok) fail(path === '/config' && response.status === 503 ? 'setup_required' : 'network');
      return response.status === 204 ? {} : await response.json();
    } finally { clearTimeout(timer); }
  }

  async function registration(create = false) {
    // Do not wait indefinitely on serviceWorker.ready on an unregistered site.
    let reg = await navigator.serviceWorker.getRegistration(workerUrl.href);
    if (create) {
      reg = await navigator.serviceWorker.register(workerUrl.href, {
        scope: new URL('./', document.baseURI).href,
        updateViaCache: 'none',
      });
      if (reg.installing || reg.waiting || !reg.active) await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('network')), 20000);
        const worker = reg.installing || reg.waiting;
        if (!worker) { clearTimeout(timer); reject(new Error('network')); return; }
        const changed = () => {
          if (worker.state === 'activated') { clearTimeout(timer); resolve(); }
          if (worker.state === 'redundant') { clearTimeout(timer); reject(new Error('network')); }
        };
        worker.addEventListener('statechange', changed);
        changed();
      });
    }
    return reg;
  }

  async function status(api) {
    await request(api, '/config'); // Verify backend configuration before offering enable.
    const reg = await registration();
    const sub = reg && await reg.pushManager.getSubscription();
    const saved = token() ? await request(api, '/subscriptions/me', 'GET', undefined, true) : null;
    return {
      ...(saved || {}),
      enabled: !!sub && !!saved && Notification.permission === 'granted',
      subscribed: !!saved,
      permission: Notification.permission,
    };
  }

  async function perform(action, api, data, permissionPromise) {
    if (action === 'status') return status(api);
    if (action === 'disable') {
      // Keep the credential and subscription if deletion fails, allowing retry.
      if (token()) await request(api, '/subscriptions/me', 'DELETE', undefined, true);
      lastSync = '';
      const reg = await registration();
      const sub = reg && await reg.pushManager.getSubscription();
      if (sub) await sub.unsubscribe();
      return {};
    }
    if (action === 'test') {
      return request(api, '/subscriptions/me/test', 'POST', {});
    }
    if (action !== 'enable' && action !== 'sync') fail('unsupported');
    if (action === 'enable') {
      if (await permissionPromise !== 'granted') fail('permission_denied');
    } else if (Notification.permission !== 'granted') {
      // Permission may have been revoked outside the app. Stop server sends.
      if (token()) await request(api, '/subscriptions/me', 'DELETE', undefined, true);
      fail('permission_denied');
    }
    const reg = await registration(action === 'enable');
    let sub = reg && await reg.pushManager.getSubscription();
    let created = false;
    if (!sub && action === 'sync') fail('permission_denied');
    const config = await request(api, '/config');
    if (!sub) {
      const padded = config.publicKey.replace(/-/g, '+').replace(/_/g, '/');
      const key = Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
      sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key });
      created = true;
    }
    token(true);
    const signature = JSON.stringify({ api, data, subscription: sub.toJSON() });
    if (action === 'sync' && signature === lastSync) return {};
    try {
      const result = await request(api, '/subscriptions/me', 'PUT', {
        subscription: sub.toJSON(), configuration: data,
      });
      lastSync = signature;
      return result;
    } catch (error) {
      if (created) await sub.unsubscribe().catch(() => {});
      throw error;
    }
  }

  window.muslimWebPush = {
    call(action, apiValue, payload) {
      try {
        checkSupport();
        const api = baseUrl(apiValue);
        // Must execute synchronously in the original button's user gesture.
        const permission = action === 'enable' ? Notification.requestPermission() : null;
        const data = JSON.parse(payload);
        const task = activeCall
          ? activeCall.catch(() => {}).then(() => perform(action, api, data, permission))
          : perform(action, api, data, permission);
        activeCall = task;
        return task.then(JSON.stringify)
          .catch((error) => JSON.stringify({ error: error.message || 'network' }))
          .finally(() => { if (activeCall === task) activeCall = null; });
      } catch (error) {
        return Promise.resolve(JSON.stringify({ error: error.message || 'network' }));
      }
    },
  };
})();
