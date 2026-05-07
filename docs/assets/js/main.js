/*
 * Hanif CLI marketing site — small, dependency-free progressive enhancement.
 * Handles: theme toggle, mobile nav, copy buttons, animated hero terminal,
 * and current-year stamping. All DOM access is null-checked so the script is
 * safe to load on any page.
 */
(function () {
  'use strict';

  // ---------- Theme toggle (respects system, persists choice) ----------
  var STORAGE_KEY = 'hanif-theme';
  var root = document.documentElement;

  function getStoredTheme() {
    try { return localStorage.getItem(STORAGE_KEY); } catch (e) { return null; }
  }
  function storeTheme(t) {
    try { localStorage.setItem(STORAGE_KEY, t); } catch (e) { /* ignore */ }
  }
  function preferredTheme() {
    var stored = getStoredTheme();
    if (stored === 'light' || stored === 'dark') return stored;
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) return 'dark';
    return 'light';
  }
  function applyTheme(t) {
    root.setAttribute('data-theme', t);
    var btns = document.querySelectorAll('[data-theme-toggle]');
    for (var i = 0; i < btns.length; i++) {
      btns[i].setAttribute('aria-pressed', t === 'dark' ? 'true' : 'false');
      btns[i].setAttribute('aria-label', t === 'dark' ? 'Switch to light theme' : 'Switch to dark theme');
    }
  }
  applyTheme(preferredTheme());

  document.addEventListener('click', function (ev) {
    var btn = ev.target.closest && ev.target.closest('[data-theme-toggle]');
    if (!btn) return;
    var next = root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    storeTheme(next);
    applyTheme(next);
  });

  // ---------- Mobile nav ----------
  document.addEventListener('click', function (ev) {
    var toggle = ev.target.closest && ev.target.closest('[data-nav-toggle]');
    if (toggle) {
      var menu = document.getElementById(toggle.getAttribute('aria-controls') || 'nav-menu');
      if (menu) {
        var isOpen = menu.classList.toggle('is-open');
        toggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
      }
      return;
    }
    // close on link click (mobile)
    var link = ev.target.closest && ev.target.closest('.nav-links a');
    if (link) {
      var menu2 = document.getElementById('nav-menu');
      if (menu2 && menu2.classList.contains('is-open')) {
        menu2.classList.remove('is-open');
        var t = document.querySelector('[data-nav-toggle]');
        if (t) t.setAttribute('aria-expanded', 'false');
      }
    }
  });

  // ---------- Copy buttons ----------
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      try {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.setAttribute('readonly', '');
        ta.style.position = 'absolute';
        ta.style.left = '-9999px';
        document.body.appendChild(ta);
        ta.select();
        var ok = document.execCommand && document.execCommand('copy');
        document.body.removeChild(ta);
        ok ? resolve() : reject(new Error('copy failed'));
      } catch (e) { reject(e); }
    });
  }

  document.addEventListener('click', function (ev) {
    var btn = ev.target.closest && ev.target.closest('.copy-btn');
    if (!btn) return;
    ev.preventDefault();
    var targetSel = btn.getAttribute('data-copy-target');
    var text = '';
    if (targetSel) {
      var el = document.querySelector(targetSel);
      if (el) text = el.innerText.trim();
    } else {
      // copy nearest <code> in row, or previous sibling code/pre
      var row = btn.closest('.copy-row, .code-block');
      if (row) {
        var code = row.querySelector('code, pre');
        if (code) text = code.innerText.trim();
      }
    }
    if (!text) return;
    copyText(text).then(function () {
      var original = btn.textContent;
      btn.classList.add('is-copied');
      btn.textContent = 'Copied!';
      window.setTimeout(function () {
        btn.classList.remove('is-copied');
        btn.textContent = original;
      }, 1600);
    }).catch(function () {
      btn.textContent = 'Press Ctrl+C';
      window.setTimeout(function () { btn.textContent = 'Copy'; }, 2000);
    });
  });

  // ---------- Current year ----------
  var years = document.querySelectorAll('[data-year]');
  for (var y = 0; y < years.length; y++) {
    years[y].textContent = String(new Date().getFullYear());
  }

  // ---------- Animated hero terminal ----------
  var term = document.querySelector('[data-terminal]');
  if (term) {
    var prefersReduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    // Each step is an array of HTML lines. The last line is treated as the
    // active prompt and the rest are appended at once for readability.
    var steps = [
      [
        '<span class="t-prompt">$</span> <span class="t-cmd">hanif sync</span>',
        '<span class="t-info">→</span> Updating <span class="t-str">main</span>…',
        '<span class="t-ok">✓</span> main is up to date with origin/main',
        '<span class="t-info">→</span> Rebasing <span class="t-str">feature/om-755_login</span> onto main',
        '<span class="t-ok">✓</span> Rebase complete — 3 commits replayed',
        '<span class="t-info">→</span> Cleaning merged branches…',
        '<span class="t-ok">✓</span> Deleted 4 stale branches',
        ''
      ],
      [
        '<span class="t-prompt">$</span> <span class="t-cmd">hanif nf</span> <span class="t-str">OM-1200: refactor checkout flow</span>',
        '<span class="t-info">→</span> Branch name: <span class="t-str">feature/om-1200_refactor_checkout_flow</span>',
        '<span class="t-ok">✓</span> Switched to a new branch',
        ''
      ],
      [
        '<span class="t-prompt">$</span> <span class="t-cmd">hanif squash</span> <span class="t-flag">5</span>',
        '<span class="t-muted">  1) a524b8f  Fifth commit</span>',
        '<span class="t-muted">  2) ef3798f  Fourth commit</span>',
        '<span class="t-muted">  3) 1a6c6d8  Third commit  ← squash into</span>',
        '<span class="t-ok">✓</span> Squashed 3 commits into <span class="t-str">"OM-1200 refactor checkout"</span>',
        ''
      ],
      [
        '<span class="t-prompt">$</span> <span class="t-cmd">hanif bv</span> <span class="t-flag">minor</span>',
        '<span class="t-info">→</span> 1.4.2  →  <span class="t-str">1.5.0-rc0</span>',
        '<span class="t-ok">✓</span> Updated package.json, Cargo.toml, .bumpversion.cfg',
        '<span class="t-ok">✓</span> Tagged <span class="t-str">v1.5.0-rc0</span> and pushed',
        ''
      ],
      [
        '<span class="t-prompt">$</span> <span class="t-cmd">hanif env set</span> <span class="t-str">API_KEY=sk-•••</span>',
        '<span class="t-warn">⚠</span> Existing value will be overwritten',
        '<span class="t-ok">✓</span> Saved to ~/.hanif/env.sh (masked in <span class="t-cmd">env list</span>)',
        ''
      ]
    ];

    var body = term.querySelector('[data-terminal-body]');
    if (!body) return;

    if (prefersReduced) {
      // Render the first scenario fully, no animation.
      renderStep(0, true);
      return;
    }

    var stepIdx = 0;
    function renderStep(i, instant) {
      var lines = steps[i];
      body.innerHTML = '';
      // Render all but the last line instantly to keep things readable.
      var k;
      for (k = 0; k < lines.length - 1; k++) {
        var div = document.createElement('div');
        div.className = 'terminal-line';
        div.innerHTML = lines[k];
        body.appendChild(div);
      }
      // Cursor placeholder for the new prompt line
      var promptDiv = document.createElement('div');
      promptDiv.className = 'terminal-line';
      promptDiv.innerHTML = '<span class="t-prompt">$</span> <span class="cursor" aria-hidden="true"></span>';
      body.appendChild(promptDiv);

      if (instant) return;

      // Schedule the next step
      window.setTimeout(function () {
        stepIdx = (stepIdx + 1) % steps.length;
        renderStep(stepIdx, false);
      }, Math.max(3500, lines.length * 700));
    }
    renderStep(0, false);
  }

  // ---------- Version injection ----------
  // Reads window.HANIF_VERSION (set inline in <head>) and stamps every
  // version-bearing element on the page. Safe to call on any page that
  // may not have these elements.
  function injectVersion() {
    var v = window.HANIF_VERSION;
    if (!v) return;

    // Hero eyebrow badge
    var badge = document.getElementById('js-version-badge');
    if (badge) badge.textContent = 'v' + v;

    // self-update demo "Latest: x.x.x"
    var latest = document.getElementById('js-version-latest');
    if (latest) latest.textContent = v;

    // install verify "hanif x.x.x"
    var verify = document.getElementById('js-version-verify');
    if (verify) verify.textContent = v;

    // JSON-LD structured data
    var ldScript = document.querySelector('script[type="application/ld+json"]');
    if (ldScript) {
      try {
        var data = JSON.parse(ldScript.textContent);
        data.softwareVersion = v;
        ldScript.textContent = JSON.stringify(data, null, 4);
      } catch (e) { /* leave as-is if JSON parse fails */ }
    }
  }
  injectVersion();
})();
