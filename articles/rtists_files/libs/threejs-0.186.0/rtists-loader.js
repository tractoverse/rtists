// Bootstrap for the rtists htmlwidget on three.js r186.
//
// three.js r186 is ESM-only (no UMD/IIFE): there is no global `THREE`. This
// classic script (declared first in rtists.yaml) makes the ESM widget work
// inside the classic htmlwidgets script-loading model by:
//   1. injecting an <script type="importmap"> that binds the bare specifier
//      "three" to lib/threejs/three.module.js (relative to its own location),
//   2. dynamically importing the widget module at rtists-render.js.
//
// The import map MUST be present before any module executes, so it is injected
// synchronously in the document head before the dynamic import() call.
(function () {
  // Base URL of this script (lib/threejs/).
  var scriptUrl = document.currentScript && document.currentScript.src;
  if (!scriptUrl) return;                 // only meaningful when loaded as a script
  var base = scriptUrl.slice(0, scriptUrl.lastIndexOf('/') + 1);

  // three.module.js re-exports three.core.js via a relative import, so mapping
  // the bare "three" specifier to it is sufficient.
  var map = {
    'imports': {
      'three': base + 'three.module.js'
    }
  };

  // Insert the import map ahead of any module evaluation.
  var im = document.createElement('script');
  im.type = 'importmap';
  im.textContent = JSON.stringify(map);
  document.head.appendChild(im);

  // Widget module is co-located here (rtists-render.js).
  import(base + 'rtists-render.js')
    ['catch'](function (err) {
      console.error('[rtists] failed to load ESM widget module:', err);
    })
    ['then'](function () {
      // The ESM module registers the htmlwidgets widget binding only when it
      // finishes loading (dynamic import is asynchronous), which is after
      // htmlwidgets' initial binding scan:
      //
      //   * Shiny  - Shiny scans for output bindings once at app init, so any
      //              rtists outputs already in the DOM before the module loaded
      //              are skipped and never bound (they stay empty, no factory
      //              call). Re-run Shiny's binding scan so they get bound. The
      //              scan is idempotent: already-bound outputs/inputs are
      //              skipped.
      //   * static - the same race affects the static (non-Shiny) htmlwidgets
      //              path used by the R console / Viewer pane (and pkgdown or
      //              plain-web renderings): staticRender() runs once on
      //              DOMContentLoaded and skips any widget whose binding is not
      //              yet registered, so rtists produced no canvas and no error.
      //              Re-run it here. It is idempotent per element: already-bound
      //              elements are skipped via the html-widget-static-bound class,
      //              so re-rendering leaves every other widget untouched.
      var rebind = function () {
        if (typeof window.Shiny !== 'undefined' && window.Shiny.bindAll) {
          window.Shiny.bindAll(document)['catch'](function (err) {
            console.error('[rtists] Shiny re-bind failed:', err);
          });
        } else if (
          typeof window.HTMLWidgets !== 'undefined' &&
          typeof window.HTMLWidgets.staticRender === 'function'
        ) {
          window.HTMLWidgets.staticRender();
        }
      };
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', rebind);
      } else {
        rebind();
      }
    });
})();
