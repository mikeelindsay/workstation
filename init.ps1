<#
	.SYNOPSIS
#>

$errorActionPreference = "Stop"
$warningPreference = "Continue"

Set-Variable -Name OPEN_SSH_FULL_PATH -Scope Private -Option Constant -Value 'C:\Windows\System32\OpenSSH\ssh.exe'

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
If (-not $isAdmin)
{
    Throw "This script must be ran as administrator."
}

Function Install-Git
{
	<#
		.DESCRIPTION
		Installs Git.
	#>

	Set-Variable -Name GIT_FULL_PATH -Scope Private -Option Constant -Value "C:\Program Files\Git\bin\git.exe"

	Write-Host -ForegroundColor DarkGray "Checking if Git is installed..."
	# If (-not (Test-Path -Path $GIT_FULL_PATH))
	# {
		Write-Host -ForegroundColor Red "Git is not installed. Please install Git and run this script again."

		Write-Host -ForegroundColor DarkGray "Installing Git..."
		Invoke-Expression "winget install --id Git.Git -e --silent --source winget"
		Write-Host -ForegroundColor DarkGray "Git installed."
	# }
	# Else {
		# Write-Host -ForegroundColor DarkGray "Git is installed."
	# }
}

Function Enable-OpenSshService
{
	<#
		.DESCRIPTION
		Enables the OpenSSH service if it is not already enabled, sets the service to start automatically, and starts the service.
	#>

	Set-Variable -Name OPENSSH_SERVICE_NAME -Scope Private -Option Constant -Value "ssh-agent"

	Write-Host -ForegroundColor DarkGray "Enabling OpenSSH service..."
	Set-Service -Name $OPENSSH_SERVICE_NAME -StartupType "Automatic" -Force
	Write-Host -ForegroundColor DarkGray "OpenSSH service enabled."

	Write-Host -ForegroundColor DarkGray "Starting OpenSSH service..."
	if ((Get-Service -Name $OPENSSH_SERVICE_NAME).Status -eq "Stopped")
	{
		Write-Host -ForegroundColor DarkGray "OpenSSH service is stopped. Starting service..."
		Start-Service -Name $OPENSSH_SERVICE_NAME
		Write-Host -ForegroundColor DarkGray "OpenSSH service started."
	}
	Else {
		Write-Host -ForegroundColor DarkGray "OpenSSH service is already running."
	}

	Write-Host "OpenSSH service enabled and started."
}

Function Install-SshKey
{
	<#
		.DESCRIPTION
		Generates an SSH key pair.
	#>

	Set-Variable -Name SSH_KEY_NAME -Scope Private -Option Constant -Value "id_ed25519"
	Set-Variable -Name SSH_CONFIG_NAME -Scope Private -Option Constant -Value "config"

	$config = "Host *
    AddKeysToAgent yes
    IdentitiesOnly yes
"
	$sshRootPath = "$env:USERPROFILE/.ssh/"


	Write-Host -ForegroundColor DarkGray "Checking for existing SSH key..."
	If (-not (Test-Path -Path "$sshRootPath/$SSH_KEY_NAME"))
	{
		$emailAddress = Read-Host -Prompt "Enter your email address: "
		Write-Host -ForegroundColor DarkGray "No existing SSH key found. Generating new SSH key..."
		ssh-keygen -t ed25519 -f "$sshRootPath/$SSH_KEY_NAME" -C $emailAddress
	}
	Else {
		Write-Host -ForegroundColor DarkGray "Existing SSH key found."
	}

	Write-Host -ForegroundColor DarkGray "Checking if SSH key is already in ssh-agent..."
	$existingKeys = ssh-add -L
	$keyContent = Get-Content -Path "$sshRootPath/$SSH_KEY_NAME.pub"
	If ($existingKeys -notcontains $keyContent)
	{
		Write-Host -ForegroundColor DarkGray "SSH key is not in ssh-agent. Adding to ssh-agent..."

		Write-Host -ForegroundColor DarkGray "Adding SSH key to ssh-agent..."
		ssh-add "$sshRootPath/$SSH_KEY_NAME"
		Write-Host -ForegroundColor DarkGray "SSH key generated and added to ssh-agent."
	}
	Else {
		Write-Host -ForegroundColor DarkGray "SSH key is already in ssh-agent."
	}

	Write-Host -ForegroundColor DarkGray "Copying SSH key to clipboard..."
	Get-Content -Path "$sshRootPath/$SSH_KEY_NAME.pub" | Set-Clipboard
	Write-Host -ForegroundColor Green "SSH key copied to clipboard."

	Write-Host -ForegroundColor DarkGray "Writing SSH config..."
	Set-Content -Path "$sshRootPath/$SSH_CONFIG_NAME" -Value $config
	Write-Host -ForegroundColor DarkGray "SSH config written."
}

Install-Git
Enable-OpenSshService
Install-SshKey
Read-Host -Prompt "Press Enter to continue..."
