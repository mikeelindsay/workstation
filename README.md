# Workstation Configuration

## 1 line configuration for windows
```powershell
Invoke-Expression "& { $(Invoke-RestMethod -Headers @{"Cache-Control"="no-cache"} https://raw.githubusercontent.com/mikeelindsay/workstation/refs/heads/master/init.ps1) }"
```