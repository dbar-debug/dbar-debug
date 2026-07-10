# setup-portproxy.ps1
# Піднімає WSL (а отже бекенд+Nginx через systemd) і оновлює проброс
# портів Windows -> WSL на ПОТОЧНИЙ IP WSL (він змінюється після
# перезапуску WSL). Запускати при вході в Windows через Task Scheduler
# з правами адміністратора.
#
# Ручний запуск (PowerShell від адміністратора):
#   powershell -ExecutionPolicy Bypass -File C:\dev\court-app\server\windows\setup-portproxy.ps1

$ErrorActionPreference = "Stop"

# Назва дистрибутива — перевірте своєю: wsl -l -v
$Distro = "Ubuntu-22.04"

Write-Host "Піднімаю WSL ($Distro) ..."
# Будь-яка команда піднімає дистрибутив; systemd стартує court-app + nginx
wsl -d $Distro -u root true
Start-Sleep -Seconds 5

$wslIp = (wsl -d $Distro hostname -I).Trim().Split()[0]
if (-not $wslIp) { Write-Error "Не вдалося отримати WSL IP"; exit 1 }
Write-Host "WSL IP: $wslIp"

netsh interface portproxy reset
netsh interface portproxy add v4tov4 listenport=80  listenaddress=0.0.0.0 connectport=80  connectaddress=$wslIp
netsh interface portproxy add v4tov4 listenport=443 listenaddress=0.0.0.0 connectport=443 connectaddress=$wslIp

Write-Host "portproxy оновлено -> $wslIp :80 та :443"
netsh interface portproxy show all
