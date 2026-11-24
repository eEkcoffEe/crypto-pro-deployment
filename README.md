# CryptoPro Deployment v5

Локальная установка и чистая переустановка CSP 5.0.13820. Windows PowerShell 5.1 x64, права администратора.

Поместите официальный cspclean.exe в Installers (https://cryptopro.ru/downloads). Установщик CSP берётся из Installers или прежней корпоративной папки. EXE не включены в архив. Проверьте цифровые подписи. Сохраните все закрытые ключи и сертификаты штатными средствами на внешнем носителе и проверьте восстановление. Не используйте на ПК с другими продуктами КриптоПро или КриптоАРМ.

```powershell
.\Clean-Reinstall-CryptoPro.ps1 -Force -KeysBackedUp -Restart
```

После штатного удаления и первой перезагрузки выполните в локальном PowerShell администратора команду Resume-CryptoPro.ps1 -Cleanup, которую напечатал скрипт. Если окно закрыто, путь к ней можно найти так:

```powershell
(Get-ScheduledTask -TaskName CryptoProDeployment-Resume).Actions.Arguments
```

Используйте указанный там путь к Resume-CryptoPro.ps1 с параметром -Cleanup. Утилита запускается интерактивно, без параметра удаления ключей. Не подтверждайте удаление закрытых ключей. После успешной очистки подтвердите YES. Следующие перезагрузки, установка и диагностика выполняются автоматически. Без -Restart первую перезагрузку выполните вручную. Финальная перезагрузка обязательна.

```powershell
.\Install-CryptoPro.ps1 -Restart
.\Reinstall-CryptoPro.ps1 -Restart
.\Get-CryptoProInfo.ps1
```

Логи: C:\ProgramData\CryptoProDeployment\Logs и Resume-*\resume.log. При ошибке проверьте журнал и статус задачи, не запускайте очистку повторно вслепую. Проверка лицензии — вручную в cpanel.cpl. Сброс пробной лицензии не реализован. Экспорт реестра не заменяет резервное копирование ключей. Автоматическая глубокая очистка в SYSTEM не применяется, поскольку не подтвержден безусловно безопасный тихий режим. Не испытано на Windows.

Документация: https://cryptopro.ru/downloads ; https://cryptopro.ru/faq/avariinoe-udalenie-kriptopro-csp
