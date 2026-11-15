// Яндекс.Метрика. Номер счётчика — из кабинета metrika.yandex.ru.
// Пока номер 0 — Метрика не загружается.
(function () {
  var YM_ID = 114253236;

  window.trackGoal = function (name) {
    if (YM_ID && typeof window.ym === 'function') window.ym(YM_ID, 'reachGoal', name);
  };

  if (!YM_ID) return;

  (function (m, e, t, r, i, k, a) {
    m[i] = m[i] || function () { (m[i].a = m[i].a || []).push(arguments); };
    m[i].l = 1 * new Date();
    for (var j = 0; j < document.scripts.length; j++) { if (document.scripts[j].src === r) { return; } }
    k = e.createElement(t), a = e.getElementsByTagName(t)[0], k.async = 1, k.src = r, a.parentNode.insertBefore(k, a);
  })(window, document, 'script', 'https://mc.yandex.ru/metrika/tag.js', 'ym');

  window.ym(YM_ID, 'init', {
    clickmap: true,
    trackLinks: true,
    accurateTrackBounce: true,
    webvisor: true
  });

  // Цели: клик по телефону и по мессенджерам
  document.addEventListener('click', function (e) {
    var link = e.target.closest && e.target.closest('a[href]');
    if (!link) return;
    var href = link.getAttribute('href') || '';
    if (href.indexOf('tel:') === 0) window.trackGoal('phone_click');
    else if (/t\.me|telegram|viber|wa\.me|whatsapp|instagram/i.test(href)) window.trackGoal('messenger_click');
  });
})();
