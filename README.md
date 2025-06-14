# Workstation Configuration

## 1 line configuration for windows
```powershell
Invoke-Expression "& { $(Invoke-RestMethod https://raw.githubusercontent.com/mikeelindsay/workstation/refs/heads/master/init.ps1 -Headers @{"Cache-Control"="no-cache"}) }"
```