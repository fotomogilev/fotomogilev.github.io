/**
 * Приёмник заявок с сайта fotomogilev.by → Telegram.
 *
 * Работает в Google Apps Script (script.google.com). Токен бота хранится
 * ТОЛЬКО здесь, в закрытом проекте Google, и никогда не попадает на сайт.
 *
 * В публичном репозитории лежит копия-шаблон без токена.
 */

// ⬇️ Вставьте НОВЫЙ токен от @BotFather (тот, что выдан после /revoke)
const TELEGRAM_TOKEN = 'ВСТАВЬТЕ_СЮДА_НОВЫЙ_ТОКЕН';
// ⬇️ ID чата, куда приходят заявки
const CHAT_ID = 'ВСТАВЬТЕ_СЮДА_ID_ЧАТА';

// Не больше стольких заявок в час (защита от спама)
const MAX_PER_HOUR = 30;
// Человек не заполнит форму быстрее, чем за 3 секунды
const MIN_FILL_MS = 3000;

function doPost(e) {
  try {
    const p = (e && e.parameter) || {};

    // Ловушка для роботов: скрытое поле, которое человек не видит и не заполняет.
    // Роботу отвечаем «успешно», чтобы он не пытался снова.
    if (p.website) return reply_(true);
    if (!(Number(p.elapsed) >= MIN_FILL_MS)) return reply_(true);

    const name = clean_(p.name, 100);
    const phone = clean_(p.phone, 40);
    const comment = clean_(p.comment, 1000);
    const digits = phone.replace(/\D/g, '');
    if (!name || digits.length < 7 || digits.length > 15 || /[^\d\s()+\-]/.test(phone)) {
      return reply_(false, 'invalid');
    }

    if (!takeSlot_()) return reply_(false, 'rate');

    const text =
      'Заявка с сайта\n' +
      'Имя: ' + name + '\n' +
      'Телефон: ' + phone + '\n' +
      'Комментарий: ' + (comment || '—');

    return reply_(sendTelegram_(text), 'telegram');
  } catch (err) {
    console.error(err);
    return reply_(false, 'error');
  }
}

// Открыть адрес приложения в браузере — увидите «ok», значит всё развернуто.
function doGet() {
  return ContentService.createTextOutput('ok');
}

// Запустите эту функцию кнопкой ▶ «Выполнить» — в Telegram придёт тестовое сообщение.
function test() {
  const ok = sendTelegram_('✅ Тест: форма сайта fotomogilev.by подключена');
  console.log(ok ? 'Сообщение отправлено — всё работает' : 'Ошибка: проверьте токен и ID чата');
}

function sendTelegram_(text) {
  const res = UrlFetchApp.fetch('https://api.telegram.org/bot' + TELEGRAM_TOKEN + '/sendMessage', {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({ chat_id: CHAT_ID, text: text, disable_web_page_preview: true }),
    muteHttpExceptions: true
  });
  if (res.getResponseCode() !== 200) console.error(res.getContentText());
  return res.getResponseCode() === 200;
}

function clean_(v, max) {
  return String(v || '').replace(/[\u0000-\u0008\u000B-\u001F\u007F]/g, '').trim().slice(0, max);
}

function takeSlot_() {
  const lock = LockService.getScriptLock();
  lock.waitLock(5000);
  try {
    const cache = CacheService.getScriptCache();
    const key = 'n' + Math.floor(Date.now() / 3600000);
    const n = Number(cache.get(key) || 0);
    if (n >= MAX_PER_HOUR) return false;
    cache.put(key, String(n + 1), 3700);
    return true;
  } finally {
    lock.releaseLock();
  }
}

function reply_(ok, error) {
  return ContentService
    .createTextOutput(JSON.stringify(ok ? { ok: true } : { ok: false, error: error }))
    .setMimeType(ContentService.MimeType.JSON);
}
