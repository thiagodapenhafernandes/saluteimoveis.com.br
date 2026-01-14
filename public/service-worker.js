// This is the "Offline page" service worker

const CACHE = "salute-admin-cache-v1";
const offlineFallbackPage = "/admin";

self.addEventListener("install", function (event) {
  console.log("[ServiceWorker] Install");

  event.waitUntil(
    caches.open(CACHE).then(function (cache) {
      console.log("[ServiceWorker] Caching offline page");
      return cache.add(offlineFallbackPage);
    })
  );
});

self.addEventListener("fetch", function (event) {
  if (event.request.method !== "GET") return;

  event.respondWith(
    fetch(event.request)
      .then(function (response) {
        // If request was success, return it
        return response;
      })
      .catch(function (error) {
        // If request failed within cache, return offline fallback (if accessing page)
        // Here we just use a simplified logic: if generic fetch fails, try cache.
        if (event.request.mode === 'navigate') {
          return caches.match(offlineFallbackPage);
        }
        return null;
      })
  );
});
