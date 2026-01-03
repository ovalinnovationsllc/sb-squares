// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;

/// Reload the web page with cache clearing for PWAs
void reloadWebPage() {
  // Try to unregister service workers to force fresh load
  _clearServiceWorkerCache().then((_) {
    // Force reload bypassing cache
    html.window.location.reload();
  });
}

/// Clear service worker cache to ensure fresh content
Future<void> _clearServiceWorkerCache() async {
  try {
    // Unregister all service workers
    final registrations = await html.window.navigator.serviceWorker?.getRegistrations();
    if (registrations != null) {
      for (final registration in registrations) {
        await registration.unregister();
      }
    }

    // Clear caches
    js.context.callMethod('eval', ['''
      if ('caches' in window) {
        caches.keys().then(function(names) {
          for (let name of names) {
            caches.delete(name);
          }
        });
      }
    ''']);
  } catch (e) {
    print('Error clearing cache: $e');
  }
}
