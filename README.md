# CryptoPro Deployment v6

Чистая локальная переустановка КриптоПро CSP 5.0.13820 с официальной утилитой cspclean.exe. Windows PowerShell 5.1 x64, права администратора.

## Подготовка

Поместите `cspclean.exe` из официального центра загрузки https://cryptopro.ru/downloads в `Installers`. Установщик `CryptoPro-5.0.13820.exe` берётся из `Installers` или корпоративной папки. EXE в архив не входят. Сохраните закрытые ключи и сертификаты штатными средствами на внешнем носителе и проверьте восстановление. Не используйте на ПК с другими продуктами КриптоПро или КриптоАРМ. Закройте приложения и убедитесь, что все пользователи сохранили данные: перезагрузки принудительные.

## Шаг 1. Удаление

В PowerShell от имени администратора:

```powershell
cd '\\vfs01\soft\Programs\crypto pro\crypto-pro-deployment'
.\Clean-Reinstall-CryptoPro.ps1 -Force -KeysBackedUp -Restart
```

`-KeysBackedUp` подтверждает наличие резервной копии, но не создаёт её. После удаления компьютер перезагрузится.

## Шаг 2. Глубокая очистка

После первой перезагрузки откройте PowerShell от имени администратора и выполните:

```powershell
$Task = Get-ScheduledTask -TaskName 'CryptoProDeployment-Resume'
$Script = ($Task.Actions.Arguments -split '"')[1]
& $Script -Cleanup
```

Не запускайте удаление повторно. Утилита работает интерактивно; не подтверждайте удаление закрытых ключей. После успешной очистки и сохранения ключей введите `YES`. Далее автоматически выполняются вторая перезагрузка, установка от SYSTEM, финальная принудительная перезагрузка, проверка CSP и удаление временного задания. Без `-Restart` первую перезагрузку нужно выполнить вручную; последующие перезагрузки обязательны.

## Шаг 3. Проверка

```powershell
Get-ScheduledTask -TaskName 'CryptoProDeployment-Resume' -ErrorAction SilentlyContinue
cd '\\vfs01\soft\Programs\crypto pro\crypto-pro-deployment'
.\Get-CryptoProInfo.ps1
control.exe 'C:\Program Files\Crypto Pro\CSP\cpanel.cpl'
```

После успешного завершения задача отсутствует, а тесты CSP x86/x64 возвращают код 0. Лицензию проверяйте вручную. Сброс демонстрационного периода не реализован.

## Состав проекта

- `Clean-Reinstall-CryptoPro.ps1` — основной запуск.
- `Resume-CryptoPro.ps1` — продолжение очистки и автоматизация после перезагрузок.
- `Install-CryptoPro.ps1` — внутренний этап установки.
- `Get-CryptoProInfo.ps1` — диагностика.
- `Installers/` — файлы производителя.

## Журналы и ошибки

Журналы находятся в `C:\ProgramData\CryptoProDeployment\Logs` и `C:\ProgramData\CryptoProDeployment\Resume-*\resume.log`. При ошибке проверьте журнал и `phase.txt`; не запускайте удаление повторно вслепую. Экспорт реестра не заменяет резервную копию ключей.

В v6 удалён отдельный сценарий переустановки и все вызовы Restart-Computer заменены на Restart-Computer -Force. Основная последовательность v5 проверена на PC-IT-TEH; изменения v6 требуют контрольного запуска Windows.
