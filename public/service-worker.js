const CACHE = "salute-admin-cache-v2";
const offlineFallbackPage = "/admin";

self.addEventListener("install", function (event) {
  console.log("[ServiceWorker] Install");
  self.skipWaiting(); // Force activation of new serviceworker

  event.waitUntil(
    caches.open(CACHE).then(function (cache) {
      console.log("[ServiceWorker] Caching offline page");
      return cache.add(offlineFallbackPage);
    })
  );
});

self.addEventListener("activate", function (event) {
  console.log("[ServiceWorker] Activate");
  event.waitUntil(clients.claim()); // Take control of clients immediately
});

self.addEventListener("fetch", function (event) {
  // Only intercept navigation requests (for offline support)
  // Let everything else (images, css, js) go direct to network
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(function () {
        return caches.match(offlineFallbackPage);
      })
    );
  }
});
