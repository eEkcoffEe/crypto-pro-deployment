# CryptoPro Deployment

Автоматизированная установка, штатная и полная переустановка КриптоПро CSP **5.0.13820 KC1** и Browser plug-in **2.0.15820** на Windows через PowerShell, WinRM и GPO.

## Структура проекта

```text
crypto-pro-deployment/
├── Install-CryptoPro.ps1
├── Reinstall-CryptoPro.ps1
├── Clean-Reinstall-CryptoPro.ps1
├── Get-CryptoProInfo.ps1
├── Deploy-CryptoProRemote.ps1
├── Installers/
├── .gitignore
└── README.md
```

## Требования и установщик

- Windows PowerShell 5.1 x64, права администратора на целевом ПК.
- Для удалённого запуска — WinRM и доступ к целевому ПК.
- Все PS1-файлы должны находиться в одной папке проекта.
- До переустановки сохраните сертификаты и доступные для экспорта ключевые контейнеры штатными средствами, проверьте возможность восстановления и наличие действующей лицензии.
- Скрипты рассчитаны на KC1; не используйте их для ПК, которым необходим KC2/KC3.

По умолчанию используется установщик:

```text
\\vfs01\soft\Programs\crypto pro\CryptoPro-5.0.13820.exe
```

Можно поместить оригинальный EXE в `Installers\CryptoPro-5.0.13820.exe` либо явно указать `-InstallerPath`. EXE не включён в Git и архив. Проверяется Authenticode и имя издателя. Ограничьте права записи в сетевой каталог и локальный каталог развёртывания администраторами и SYSTEM.

## 1. Локальный запуск

Все команды этого раздела выполняются **на целевом ПК**, в Windows PowerShell x64 от имени администратора, из папки проекта.

### 1.1. Обычная установка / обновление

```powershell
.\Install-CryptoPro.ps1
```

С автоматической перезагрузкой:

```powershell
.\Install-CryptoPro.ps1 -Restart
```

С указанием другого установщика:

```powershell
.\Install-CryptoPro.ps1 -InstallerPath 'C:\Temp\CryptoPro-5.0.13820.exe'
```

Если обе целевые версии уже установлены, обычная установка пропускается. Понижение версии блокируется.

### 1.2. Штатная переустановка

```powershell
.\Reinstall-CryptoPro.ps1
```

С автоматической перезагрузкой:

```powershell
.\Reinstall-CryptoPro.ps1 -Restart
```

С указанием установщика:

```powershell
.\Reinstall-CryptoPro.ps1 -InstallerPath 'C:\Temp\CryptoPro-5.0.13820.exe'
```

Используется штатный параметр `-reinstall`, без предварительного удаления продукта.

### 1.3. Полная переустановка (Clean)

```powershell
.\Clean-Reinstall-CryptoPro.ps1 -Force
```

С автоматической перезагрузкой:

```powershell
.\Clean-Reinstall-CryptoPro.ps1 -Force -Restart
```

С указанием установщика:

```powershell
.\Clean-Reinstall-CryptoPro.ps1 -Force -InstallerPath 'C:\Temp\CryptoPro-5.0.13820.exe'
```

Если удаление потребовало перезагрузки, после неё выполните обычную установку (не Clean повторно):

```powershell
.\Install-CryptoPro.ps1 -InstallerPath 'C:\ProgramData\CryptoProDeployment\CryptoPro-5.0.13820.exe'
```

### 1.4. Диагностика

```powershell
.\Get-CryptoProInfo.ps1
```

### 1.5. Перезагрузка Windows

```powershell
Restart-Computer -Force
```

### 1.6. Проверка лицензии

На интерактивном рабочем столе целевого ПК нажмите Win+R:

```cmd
control.exe "C:\Program Files\Crypto Pro\CSP\cpanel.cpl"
```

На вкладке «Общие» проверьте тип лицензии, дату первой установки и срок действия.

## 2. Удалённый запуск

Все команды этого раздела выполняются **на административном ПК**, из папки проекта, вне `Enter-PSSession`. В примерах целевой ПК — `PC-IT-TEH`; замените имя при необходимости.

### 2.1. Проверка подключения

```powershell
Test-WSMan PC-IT-TEH
```

### 2.2. Обычная установка / обновление

```powershell
.\Deploy-CryptoProRemote.ps1 -ComputerName PC-IT-TEH
```

С автоматической перезагрузкой:

```powershell
.\Deploy-CryptoProRemote.ps1 -ComputerName PC-IT-TEH -Restart
```

С указанием установщика на административном ПК:

```powershell
.\Deploy-CryptoProRemote.ps1 -ComputerName PC-IT-TEH -InstallerPath 'C:\Temp\CryptoPro-5.0.13820.exe'
```

### 2.3. Штатная переустановка

```powershell
.\Deploy-CryptoProRemote.ps1 -ComputerName PC-IT-TEH -Repair
```

С автоматической перезагрузкой:

```powershell
.\Deploy-CryptoProRemote.ps1 -ComputerName PC-IT-TEH -Repair -Restart
```

С указанием установщика:

```powershell
.\Deploy-CryptoProRemote.ps1 -ComputerName PC-IT-TEH -Repair -InstallerPath 'C:\Temp\CryptoPro-5.0.13820.exe'
```

### 2.4. Полная переустановка (Clean)

```powershell
.\Deploy-CryptoProRemote.ps1 -ComputerName PC-IT-TEH -Clean
```

С автоматической перезагрузкой:

```powershell
.\Deploy-CryptoProRemote.ps1 -ComputerName PC-IT-TEH -Clean -Restart
```

С указанием установщика:

```powershell
.\Deploy-CryptoProRemote.ps1 -ComputerName PC-IT-TEH -Clean -InstallerPath 'C:\Temp\CryptoPro-5.0.13820.exe'
```

Параметр `-Force` передаётся сценарию Clean автоматически. Не совмещайте `-Repair` и `-Clean`.

Если удаление потребовало перезагрузки, после восстановления WinRM выполните обычное удалённое развёртывание без `-Clean`:

```powershell
.\Deploy-CryptoProRemote.ps1 -ComputerName PC-IT-TEH
```

### 2.5. Удалённая диагностика

```powershell
Invoke-Command -ComputerName PC-IT-TEH -FilePath .\Get-CryptoProInfo.ps1
```

### 2.6. Перезагрузка удалённого ПК

```powershell
Restart-Computer -ComputerName PC-IT-TEH -Force -Wait -For PowerShell -Timeout 300
```

Проверка после перезагрузки:

```powershell
Test-WSMan PC-IT-TEH
Invoke-Command -ComputerName PC-IT-TEH -FilePath .\Get-CryptoProInfo.ps1
```

### 2.7. Проверка лицензии удалённого ПК

Подключитесь к интерактивному рабочему столу через RDP или другое разрешённое средство удалённого управления и выполните команду из раздела 1.6. Через `Enter-PSSession` графическое окно не отображается. Автоматическая проверка срока лицензии не реализована.

### 2.8. Особенности удалённого запуска

Установщик и необходимые скрипты копируются с административного ПК через `Copy-Item -ToSession`, что позволяет избежать Double Hop. Временные каталоги `Remote-*` оставляются для диагностики и могут быть удалены после завершения работ. Не запускайте удалённый сценарий внутри другой PSSession. Перезагрузка по умолчанию не выполняется.

## 3. Особенности полной переустановки

Clean проверяет установщик до удаления, экспортирует разделы реестра производителя в защищённый каталог `Backup-*`, удаляет Browser plug-in и затем CSP через MSI. Если перезагрузка не требуется, запускается обычная установка.

При коде 3010 после удаления необходима перезагрузка и отдельный запуск установки. `-Restart` не создаёт автоматического продолжения. Резервная копия HKLM не заменяет резервное копирование ключей. Ручное удаление разделов производителя, ключевых контейнеров, cspclean, CSPDELETEKEYS и сброс пробного срока не реализованы. Восстановление лицензии — штатными средствами производителя. Не импортируйте резервную копию реестра целиком без диагностики.

## 4. Развёртывание через GPO

После пилотного тестирования: Computer Configuration > Policies > Windows Settings > Scripts > Startup. Назначьте `Install-CryptoPro.ps1` в контексте SYSTEM с 64-битным Windows PowerShell. Учётным записям компьютеров необходим доступ на чтение к скрипту и установщику (SMB и NTFS). Не ослабляйте доменную политику выполнения скриптов. Не назначайте Reinstall или Clean как постоянный Startup.

## 5. Журналы и результаты

Каталог на целевом ПК:

```text
C:\ProgramData\CryptoProDeployment\Logs
```

Резервные копии Clean: `C:\ProgramData\CryptoProDeployment\Backup-*`.

| Код | Значение |
| --- | --- |
| 0 | Успех или целевые версии уже установлены |
| 3010 | Требуется перезагрузка |
| 1641 | Установщик инициировал перезагрузку |
| 1 | Ошибка сценария |

Даже при коде 0 проверьте необходимость перезагрузки и работоспособность после неё. При зависании проверьте процессы и MSI-журналы, не завершайте установщик принудительно без диагностики. Перезагрузку выполняйте в согласованное окно при наличии альтернативного доступа; `-Force` у Restart-Computer может привести к потере несохранённых данных.

## 6. Ограничения и проверка

- `csptest -enum -info` проверяет инициализацию CSP, но не срок лицензии.
- Био ДСЧ может потребовать действий пользователя. Полностью безынтерактивная установка не подтверждена; массовый запуск только после пилота под SYSTEM.
- Не изменяйте настройки ДСЧ или класс защиты без согласования.
- Скрипты v2 не проверены непосредственно в Windows; требуется пилотная проверка подписи, поведения EXE, журналов и сохранности ключей.
- PS1-файлы сохранены в UTF-8 BOM для Windows PowerShell 5.1.

Параметры EXE: https://www.cryptopro.ru/forum2/default.aspx?g=posts&t=18028
