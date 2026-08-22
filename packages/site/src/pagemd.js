// "Copy page as Markdown". The Markdown twin is already served at this URL with
// `Accept: text/markdown`, so the button fetches the sibling rather than
// scraping the DOM — what lands on the clipboard is the same bytes an agent
// gets.
(function () {
  var btn = document.getElementById('copymd');
  if (!btn || !window.notifiCopy) return;

  btn.addEventListener('click', function () {
    fetch(btn.dataset.src, { headers: { Accept: 'text/markdown' } })
      .then(function (res) {
        if (!res.ok) throw new Error(String(res.status));
        return res.text();
      })
      .then(function (text) { window.notifiCopy(btn, text); })
      .catch(function () {
        btn.dataset.state = 'failed';
        btn.textContent = 'Open ' + btn.dataset.src;
      });
  });
})();
