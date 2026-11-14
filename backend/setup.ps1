# Установка приёмника заявок fotomogilev.by в Google Apps Script (Windows PowerShell).
# Запуск:
#   irm https://raw.githubusercontent.com/fotomogilev/fotomogilev.github.io/claude/adoring-faraday-vuzqap/backend/setup.ps1 | iex
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Base = 'https://raw.githubusercontent.com/fotomogilev/fotomogilev.github.io/claude/adoring-faraday-vuzqap/backend'
$ChatId = '-5062026849'
$OldTokenPrefix = '8241145818:AAHfPDJT'

function Say($t) { Write-Host ''; Write-Host "▶ $t" -ForegroundColor Magenta }
function Pause-Step($t = '   Нажмите Enter, чтобы продолжить…') { [void](Read-Host $t) }
function Clasp { & npx.cmd -y '@google/clasp@2.4.2' @args; if ($LASTEXITCODE -ne 0) { throw "clasp $($args[0]) завершился с ошибкой" } }
function Get-Text($url) { [Text.Encoding]::UTF8.GetString((New-Object Net.WebClient).DownloadData($url)) }
$Utf8 = New-Object Text.UTF8Encoding $false

if (-not (Get-Command npx.cmd -ErrorAction SilentlyContinue)) {
  Write-Host 'Нужна программа Node.js. Скачайте её с https://nodejs.org (зелёная кнопка LTS),'
  Write-Host 'установите, ЗАКРОЙТЕ и снова откройте PowerShell и вставьте команду ещё раз.'
  return
}

$Work = Join-Path $env:TEMP ('fotomogilev-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work | Out-Null
Push-Location $Work
try {
  # ------------------------------------------------------------ 1. Токен
  Say 'Шаг 1 из 5. Новый токен бота'
  while ($true) {
    $sec = Read-Host '   Вставьте НОВЫЙ токен от @BotFather и нажмите Enter (символы не видны — так и задумано)' -AsSecureString
    $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)).Trim()
    if ($Token -notmatch '^[0-9]+:[A-Za-z0-9_-]{30,}$') { Write-Host '   Это не похоже на токен. Скопируйте его из @BotFather целиком.'; continue }
    if ($Token.StartsWith($OldTokenPrefix)) { Write-Host '   Это СТАРЫЙ (утёкший) токен. Сначала отправьте @BotFather команду /revoke.'; continue }
    try {
      $me = Invoke-RestMethod "https://api.telegram.org/bot$Token/getMe" -TimeoutSec 15
      Write-Host "   ✅ Токен рабочий, бот: @$($me.result.username)"; break
    } catch {
      if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401) {
        Write-Host '   ❌ Telegram не принял этот токен. Проверьте, что скопировали его полностью.'
      } else { Write-Host '   (Не удалось связаться с Telegram для проверки — продолжаю.)'; break }
    }
  }

  # ------------------------------------------------------------ 2. API
  Say 'Шаг 2 из 5. Разрешить доступ к Google Apps Script'
  Write-Host '   Сейчас откроется страница настроек. Переключите «Google Apps Script API» в положение ВКЛ.'
  Start-Process 'https://script.google.com/home/usersettings'
  Pause-Step

  # ------------------------------------------------------------ 3. Вход
  Say 'Шаг 3 из 5. Вход в Google'
  Write-Host '   Откроется браузер: выберите Google-аккаунт и нажмите «Разрешить».'
  Clasp login

  # ------------------------------------------------------------ 4. Загрузка кода
  Say 'Шаг 4 из 5. Создаю проект и загружаю код'
  Clasp create --type standalone --title 'fotomogilev.by — заявки с сайта' | Out-Null
  $code = (Get-Text "$Base/telegram-form.gs").Replace('__TELEGRAM_TOKEN__', $Token).Replace('__CHAT_ID__', $ChatId)
  [IO.File]::WriteAllText((Join-Path $Work 'Code.gs'), $code, $Utf8)
  [IO.File]::WriteAllText((Join-Path $Work 'appsscript.json'), (Get-Text "$Base/appsscript.json"), $Utf8)
  Get-ChildItem -File | Where-Object { $_.Extension -in '.js', '.gs' -and $_.Name -ne 'Code.gs' } | Remove-Item
  Clasp push -f | Out-Null
  Write-Host '   ✅ Код загружен'
  Write-Host ''
  Write-Host '   Теперь откроется редактор проекта. В нём:'
  Write-Host '     1) вверху в списке функций выберите  test'
  Write-Host '     2) нажмите  ▶ Выполнить'
  Write-Host '     3) «Проверить разрешения» → выберите аккаунт → «Дополнительные настройки»'
  Write-Host '        → «Перейти на страницу проекта» → «Разрешить»'
  Write-Host '   В Telegram придёт сообщение «✅ Тест: форма сайта … подключена».'
  try { Clasp open | Out-Null } catch {}
  Pause-Step '   Когда сообщение пришло, нажмите Enter…'

  # ------------------------------------------------------------ 5. Публикация
  Say 'Шаг 5 из 5. Публикую приёмник заявок'
  $out = (Clasp deploy -d 'site form') -join "`n"
  $m = [regex]::Matches($out, 'AKfy[A-Za-z0-9_-]*')
  if ($m.Count -eq 0) { Write-Host $out; Write-Host 'Не удалось получить адрес. Пришлите этот текст Claude.'; return }
  $Url = "https://script.google.com/macros/s/$($m[$m.Count - 1].Value)/exec"

  try {
    $res = Invoke-RestMethod $Url -Method Post -TimeoutSec 30 -Body @{
      name = 'Проверка установки'; phone = '+375 29 000-00-00'
      comment = 'Тестовая заявка, можно не отвечать'; elapsed = '5000'
    }
    if ($res.ok) { Write-Host '   ✅ Проверка пройдена: в Telegram пришла тестовая заявка.' }
    else { Write-Host "   ⚠️  Проверочная заявка не прошла ($($res.error)). Всё равно пришлите адрес ниже Claude." }
  } catch { Write-Host '   ⚠️  Проверочная заявка не прошла. Всё равно пришлите адрес ниже Claude.' }

  try { Clasp logout | Out-Null } catch {}
  try { Set-Clipboard -Value $Url } catch {}
  Write-Host ''
  Write-Host '════════════════════════════════════════════════════════════════'
  Write-Host '  Готово! Отправьте Claude этот адрес (он уже скопирован):'
  Write-Host ''
  Write-Host "  $Url" -ForegroundColor Green
  Write-Host ''
  Write-Host '  Он не секретный — токена в нём нет.'
  Write-Host '════════════════════════════════════════════════════════════════'
}
finally {
  Pop-Location
  Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}
