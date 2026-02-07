// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;

/// Print the current page (fallback)
void printWebPage() {
  html.window.print();
}

/// Print board HTML in a new window
void printBoardHtml(String htmlContent) {
  // Escape the HTML content for JavaScript
  final escapedHtml = htmlContent
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '');

  js.context.callMethod('eval', ['''
    (function() {
      var printWindow = window.open('', '_blank');
      if (printWindow) {
        printWindow.document.write('$escapedHtml');
        printWindow.document.close();
        setTimeout(function() {
          printWindow.print();
        }, 300);
      }
    })();
  ''']);
}

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
