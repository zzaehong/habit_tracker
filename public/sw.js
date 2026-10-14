const CACHE = 'chagok-shell-v1';
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(c => c.addAll(['/', '/icon.svg', '/manifest.webmanifest']))));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', event => {
 if(event.request.method !== 'GET' || new URL(event.request.url).origin !== self.location.origin || new URL(event.request.url).pathname.startsWith('/api')) return;
 event.respondWith(fetch(event.request).then(response => {
  if(response.ok) { const copy=response.clone(); caches.open(CACHE).then(c=>c.put(event.request,copy)); } return response;
 }).catch(async()=> (await caches.match(event.request)) || (event.request.mode==='navigate' ? await caches.match('/') : Response.error())));
});
