#!/usr/bin/env bash
# Установка приёмника заявок fotomogilev.by в Google Apps Script (macOS / Linux).
# Запуск:
#   curl -fsSL https://raw.githubusercontent.com/fotomogilev/fotomogilev.github.io/claude/adoring-faraday-vuzqap/backend/setup.sh | bash
set -euo pipefail

BASE="https://raw.githubusercontent.com/fotomogilev/fotomogilev.github.io/claude/adoring-faraday-vuzqap/backend"
CHAT_ID="-5062026849"
OLD_TOKEN_PREFIX="8241145818:AAHfPDJT"

say()   { printf '\n\033[1;35m▶ %s\033[0m\n' "$*"; }
pause() { printf '%s' "${1:-   Нажмите Enter, чтобы продолжить…}"; read -r _ </dev/tty; }
open_url() {
  echo "   $1"
  if command -v open >/dev/null 2>&1; then open "$1"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1 || true
  fi
}
clasp() { npx -y @google/clasp@2.4.2 "$@" </dev/tty; }

if ! command -v npx >/dev/null 2>&1; then
  echo "Нужна программа Node.js. Скачайте её с https://nodejs.org (зелёная кнопка LTS),"
  echo "установите и вставьте команду в терминал ещё раз."
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

# ---------------------------------------------------------------- 1. Токен
say "Шаг 1 из 5. Новый токен бота"
while :; do
  printf '   Вставьте НОВЫЙ токен от @BotFather и нажмите Enter (символы не видны — так и задумано): '
  read -rs TOKEN </dev/tty; echo
  TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]')"
  if [[ ! "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]{30,}$ ]]; then
    echo "   Это не похоже на токен. Скопируйте его из @BotFather целиком и попробуйте ещё раз."; continue
  fi
  if [[ "$TOKEN" == "$OLD_TOKEN_PREFIX"* ]]; then
    echo "   Это СТАРЫЙ (утёкший) токен. Сначала отправьте @BotFather команду /revoke и вставьте новый."; continue
  fi
  ME="$(curl -s -m 15 "https://api.telegram.org/bot${TOKEN}/getMe" || true)"
  if [[ "$ME" == *'"ok":true'* ]]; then
    echo "   ✅ Токен рабочий, бот: @$(printf '%s' "$ME" | sed -n 's/.*"username":"\([^"]*\)".*/\1/p')"
    break
  elif [[ "$ME" == *'"ok":false'* ]]; then
    echo "   ❌ Telegram не принял этот токен. Проверьте, что скопировали его полностью."
  else
    echo "   (Не удалось связаться с Telegram для проверки — продолжаю.)"; break
  fi
done

# ---------------------------------------------------------------- 2. API
say "Шаг 2 из 5. Разрешить доступ к Google Apps Script"
echo "   Сейчас откроется страница настроек Google Apps Script."
echo "   Переключите «Google Apps Script API» в положение ВКЛ (один переключатель)."
open_url "https://script.google.com/home/usersettings"
pause

# ---------------------------------------------------------------- 3. Вход
say "Шаг 3 из 5. Вход в Google"
echo "   Откроется браузер: выберите Google-аккаунт и нажмите «Разрешить»."
clasp login

# ---------------------------------------------------------------- 4. Загрузка кода
say "Шаг 4 из 5. Создаю проект и загружаю код"
clasp create --type standalone --title "fotomogilev.by — заявки с сайта" >/dev/null
curl -fsSL "$BASE/telegram-form.gs" -o Code.gs
curl -fsSL "$BASE/appsscript.json" -o appsscript.json
TOKEN="$TOKEN" CHAT_ID="$CHAT_ID" perl -pi -e 's/__TELEGRAM_TOKEN__/$ENV{TOKEN}/g; s/__CHAT_ID__/$ENV{CHAT_ID}/g' Code.gs
find . -maxdepth 1 -type f \( -name '*.js' -o -name '*.gs' \) ! -name Code.gs -delete
clasp push -f >/dev/null
echo "   ✅ Код загружен"

echo
echo "   Теперь откроется редактор проекта. В нём:"
echo "     1) вверху в списке функций выберите  test"
echo "     2) нажмите  ▶ Выполнить"
echo "     3) «Проверить разрешения» → выберите аккаунт → «Дополнительные настройки»"
echo "        → «Перейти на страницу проекта» → «Разрешить»"
echo "   В Telegram придёт сообщение «✅ Тест: форма сайта … подключена»."
clasp open >/dev/null 2>&1 || true
pause "   Когда сообщение пришло, нажмите Enter…"

# ---------------------------------------------------------------- 5. Публикация
say "Шаг 5 из 5. Публикую приёмник заявок"
OUT="$(clasp deploy -d "site form")"
ID="$(printf '%s' "$OUT" | grep -o 'AKfy[A-Za-z0-9_-]*' | tail -1 || true)"
if [[ -z "$ID" ]]; then echo "$OUT"; echo "Не удалось получить адрес. Пришлите этот текст Claude."; exit 1; fi
URL="https://script.google.com/macros/s/${ID}/exec"

RES="$(curl -sL -m 30 --data-urlencode "name=Проверка установки" --data-urlencode "phone=+375 29 000-00-00" \
  --data-urlencode "comment=Тестовая заявка, можно не отвечать" --data-urlencode "elapsed=5000" "$URL" || true)"
if [[ "$RES" == *'"ok":true'* ]]; then
  echo "   ✅ Проверка пройдена: в Telegram пришла тестовая заявка."
else
  echo "   ⚠️  Проверочная заявка не прошла (ответ: ${RES:0:200}). Всё равно пришлите адрес ниже Claude."
fi

clasp logout >/dev/null 2>&1 || true

(printf '%s' "$URL" | pbcopy 2>/dev/null || printf '%s' "$URL" | xclip -selection clipboard 2>/dev/null) || true
echo
echo "════════════════════════════════════════════════════════════════"
echo "  Готово! Отправьте Claude этот адрес (он уже скопирован):"
echo
echo "  $URL"
echo
echo "  Он не секретный — токена в нём нет."
echo "════════════════════════════════════════════════════════════════"
