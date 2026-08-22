// The terminal block's behaviour, shared by the landing page and the /docs
// recipes. One tablist and one code panel per page, so the ids stay singular.

// ── language tabs ───────────────────────────────────────────
(function () {
  const list = document.querySelector('.tabs');
  if (!list) return;
  const tabs = [...document.querySelectorAll('.tab')];
  const name = document.getElementById('langname');

  function select(tab) {
    tabs.forEach(t => {
      const on = t === tab;
      t.setAttribute('aria-selected', String(on));
      // Roving tabindex: the tablist is one Tab stop, not thirteen, and the
      // arrow keys below move within it.
      t.tabIndex = on ? 0 : -1;
      document.getElementById(t.getAttribute('aria-controls')).hidden = !on;
    });
    const panel = document.getElementById(tab.getAttribute('aria-controls'));
    if (name) name.textContent = panel.dataset.name;
  }

  tabs.forEach(tab => {
    tab.tabIndex = tab.getAttribute('aria-selected') === 'true' ? 0 : -1;
    tab.addEventListener('click', () => select(tab));
  });

  // arrows, Home and End move between tabs, as a tablist should
  list.addEventListener('keydown', e => {
    const i = tabs.indexOf(document.activeElement);
    if (i < 0) return;
    let next;
    if (e.key === 'ArrowRight') next = (i + 1) % tabs.length;
    else if (e.key === 'ArrowLeft') next = (i - 1 + tabs.length) % tabs.length;
    else if (e.key === 'Home') next = 0;
    else if (e.key === 'End') next = tabs.length - 1;
    else return;
    e.preventDefault();
    const target = tabs[next];
    target.focus();
    select(target);
  });
})();

// ── copy buttons ────────────────────────────────────────────
(function () {
  const status = document.getElementById('copystatus');
  if (!status) return;

  function flash(btn, text) {
    // Read the label before awaiting, or a second click inside the 1.5s window
    // captures "Copied" as the label to restore and it never goes back.
    const was = btn.dataset.label || btn.textContent;
    btn.dataset.label = was;

    const settle = (label, state, said) => {
      btn.textContent = label;
      if (state) btn.dataset.state = state; else delete btn.dataset.state;
      status.textContent = said;
      clearTimeout(btn._t);
      btn._t = setTimeout(() => {
        btn.textContent = was;
        delete btn.dataset.state;
        status.textContent = '';
      }, state ? 4000 : 1500);
    };

    // Rejects on an insecure origin or a denied permission, and the button
    // would otherwise sit reading "Copy" as though nothing had been asked.
    (navigator.clipboard ? navigator.clipboard.writeText(text) : Promise.reject())
      .then(() => settle('Copied', null, 'Copied to the clipboard'),
            () => settle('Select and copy', 'failed',
                         'Could not copy. Select the text and copy it yourself.'));
  }

  document.querySelectorAll('.copy[data-copy]').forEach(btn =>
    btn.addEventListener('click', () => flash(btn, btn.dataset.copy)));

  const codeBtn = document.getElementById('copycode');
  if (codeBtn) {
    codeBtn.addEventListener('click', () => {
      const open = document.querySelector('.panel:not([hidden]) pre');
      if (open) flash(codeBtn, open.innerText);
    });
  }

  window.notifiCopy = flash;
})();
