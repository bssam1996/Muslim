// Run with Node: node --test test/web_push_browser_test.cjs
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { webcrypto } = require('node:crypto');

function browser({permission = 'default', failPut = false, failDelete = false} = {}) {
  const events = [], storage = new Map();
  let sub = null, saved = null;
  const reg = {
    active: true,
    pushManager: {
      getSubscription: async () => sub,
      subscribe: async () => {
        events.push('subscribe');
        sub = {toJSON: () => ({endpoint: 'https://fcm.googleapis.com/test', keys: {auth: 'auth', p256dh: 'key'}}), unsubscribe: async () => {events.push('unsubscribe'); sub = null; return true;}};
        return sub;
      },
    },
  };
  const notification = {permission, requestPermission() {events.push('permission'); this.permission = 'granted'; return Promise.resolve('granted');}};
  const sandbox = {
    URL, Uint8Array, setTimeout, clearTimeout, AbortController, crypto: webcrypto,
    btoa: value => Buffer.from(value, 'binary').toString('base64'),
    atob: value => Buffer.from(value, 'base64').toString('binary'),
    document: {baseURI: 'https://example.com/muslim/'},
    localStorage: {getItem: key => storage.get(key), setItem: (key, value) => storage.set(key, value)},
    navigator: {serviceWorker: {getRegistration: async () => reg, register: async (url, options) => {events.push(['register', url, options.scope]); return reg;}}},
    Notification: notification,
    window: {isSecureContext: true, Notification: notification, PushManager: function() {}},
    fetch: async (url, options) => {
      events.push([options.method, url, options.headers.Authorization]);
      if (url.endsWith('/config')) return {ok: true, status: 200, json: async () => ({publicKey: 'AQID'})};
      if (options.method === 'PUT') {
        if (failPut) return {ok: false, status: 500};
        saved = JSON.parse(options.body); return {ok: true, status: 200, json: async () => ({enabled: true})};
      }
      if (options.method === 'DELETE') {
        if (failDelete) return {ok: false, status: 500};
        saved = null; return {ok: true, status: 204};
      }
      return saved ? {ok: true, status: 200, json: async () => ({enabled: true})} : {ok: false, status: 404};
    },
  };
  vm.runInNewContext(fs.readFileSync('web/web_push.js', 'utf8'), sandbox);
  const call = (action, api = 'https://api.example/web-push', payload = {prayers: ['Fajr']}) => sandbox.window.muslimWebPush.call(action, api, JSON.stringify(payload)).then(JSON.parse);
  return {call, events, notification, saved: () => saved, sub: () => sub};
}

test('permission is requested synchronously and scoped worker supports subpath hosting', async () => {
  const b = browser();
  const result = b.call('enable');
  assert.equal(b.events[0], 'permission');
  assert.equal((await result).error, undefined);
  const registered = b.events.find(event => Array.isArray(event) && event[0] === 'register');
  assert.deepEqual(registered, ['register', 'https://example.com/muslim/prayer_push_worker.js', 'https://example.com/muslim/']);
  assert.equal((await b.call('status')).enabled, true);
  const put = b.events.find(event => Array.isArray(event) && event[0] === 'PUT');
  assert.match(put[2], /^Bearer [A-Za-z0-9_-]{43}$/);
});

test('failed subscription save rolls back newly created browser subscription', async () => {
  const b = browser({failPut: true});
  assert.equal((await b.call('enable')).error, 'network');
  assert.equal(b.sub(), null);
  assert.equal((await b.call('status')).enabled, false);
});

test('disable deletes backend first and preserves subscription if deletion fails', async () => {
  const b = browser({failDelete: true});
  await b.call('enable');
  assert.equal((await b.call('disable')).error, 'network');
  assert.ok(b.sub());
  assert.ok(b.saved());
  const good = browser();
  await good.call('enable');
  await good.call('disable');
  const deleted = good.events.findIndex(event => Array.isArray(event) && event[0] === 'DELETE');
  assert.ok(deleted < good.events.indexOf('unsubscribe'));
  assert.equal((await good.call('status')).enabled, false);
});

test('permission revoked outside app removes server reminders without a permission prompt', async () => {
  const b = browser();
  await b.call('enable');
  b.notification.permission = 'denied';
  const blocked = await b.call('status');
  assert.equal(blocked.enabled, false);
  assert.equal(blocked.subscribed, true);
  assert.equal((await b.call('sync')).error, 'permission_denied');
  assert.equal(b.saved(), null);
  assert.equal(b.events.filter(event => event === 'permission').length, 1);
});

test('unconfigured backend never requests notification permission', async () => {
  const b = browser();
  assert.equal((await b.call('enable', '')).error, 'setup_required');
  assert.equal(b.events.length, 0);
});

test('concurrent startup sync and status operations are serialized', async () => {
  const b = browser();
  await b.call('enable');
  const results = await Promise.all([b.call('sync'), b.call('status'), b.call('sync')]);
  assert.ok(results.every(result => !result.error));
  assert.equal(results[1].enabled, true);
});

test('worker displays incoming pushes and clicks open its app scope', async () => {
  const handlers = {}, shown = [], opened = [];
  const scope = 'https://example.com/muslim/';
  const self = {
    addEventListener: (name, handler) => {handlers[name] = handler;},
    registration: {scope, showNotification: async (...args) => {shown.push(args);}},
    clients: {matchAll: async () => [], openWindow: async url => {opened.push(url);}},
  };
  vm.runInNewContext(fs.readFileSync('web/prayer_push_worker.js', 'utf8'), {self, URL});
  let done;
  handlers.push({data: {json: () => ({title: 'Fajr', body: 'Time for prayer', tag: 'prayer-2026-10-24-Fajr'})}, waitUntil: promise => {done = promise;}});
  await done;
  assert.equal(shown[0][0], 'Fajr');
  assert.equal(shown[0][1].body, 'Time for prayer');
  assert.equal(shown[0][1].icon, `${scope}icons/Icon-192.png`);
  handlers.notificationclick({notification: {close() {}}, waitUntil: promise => {done = promise;}});
  await done;
  assert.deepEqual(opened, [scope]);
});
