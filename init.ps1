<#
	.SYNOPSIS
	Installs applications and tools used to configure a Windows workstation.
#>

$errorActionPreference = "Stop"
$warningPreference = "Continue"

Set-Variable -Name OPEN_SSH_FULL_PATH -Scope Private -Option Constant -Value 'C:\Windows\System32\OpenSSH\ssh.exe'
Set-Variable -Name PERSONAL_GITHUB_USERNAME -Scope Private -Option Constant -Value "mikeelindsay"

$repositoryRootPath = "$env:USERPROFILE\source\repos"

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
	If (-not (Test-Path -Path $GIT_FULL_PATH))
	{
		Write-Host -ForegroundColor DarkGray "Git is not installed. Installing Git..."

		Write-Host -ForegroundColor DarkGray "Installing Git..."
		Invoke-Expression "winget install --id Git.Git -e --silent --source winget"
		Write-Host -ForegroundColor DarkGray "Git installed."
	}
	Else
	{
		Write-Host -ForegroundColor DarkGray "Git is installed."
	}

	Write-Host -ForegroundColor DarkGray "Setting Git SSH command..."
	git config --global core.sshCommand $OPEN_SSH_FULL_PATH > $null
	Write-Host -ForegroundColor DarkGray "Git SSH command set."

	Write-Host "Git installed and configured."
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
	Else
	{
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
	Else
	{
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
	Else
	{
		Write-Host -ForegroundColor DarkGray "SSH key is already in ssh-agent."
	}

	Write-Host -ForegroundColor DarkGray "Writing SSH config..."
	Set-Content -Path "$sshRootPath/$SSH_CONFIG_NAME" -Value $config
	Write-Host -ForegroundColor DarkGray "SSH config written."

	Write-Host -NoNewline -ForegroundColor Yellow "Press Enter to copy the SSH key to clipboard..."
	Read-Host | Out-Null
	Get-Content -Path "$sshRootPath/$SSH_KEY_NAME.pub" | Set-Clipboard
	Write-Host -ForegroundColor Green "SSH key copied to clipboard."
}

Function Install-VSCode
{
	<#
		.DESCRIPTION
		Installs VSCode.
	#>

	$vscodePath = "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code\Code.exe"

	Write-Host -ForegroundColor DarkGray "Checking if VSCode is installed..."
	If (-not (Test-Path -Path $vscodePath))
	{
		Write-Host -ForegroundColor DarkGray "VSCode is not installed. Installing VSCode..."

		Write-Host -ForegroundColor DarkGray "Installing VSCode..."
		Invoke-Expression "winget install --id Microsoft.VisualStudioCode -e --silent --source winget"
		Write-Host -ForegroundColor DarkGray "VSCode installed."
	}
	Else
	{
		Write-Host -ForegroundColor DarkGray "VSCode is already installed."
	}

	Write-Host "VSCode installed."
}

Function Install-GitRepository
{
	<#
		.DESCRIPTION
		Installs the WorkstationSetup repository.
	#>
	Param(
		# The type of repository to clone.
		[string] [Parameter(Mandatory = $true)] [ValidateSet('GitHub', 'AzureDevOps')] $RepositoryType,
		# The owner of the repository.
		[string] [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] $RepositoryOwner,
		# The name of the repository.
		[string] [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] $RepositoryName,
		# The branch of the repository to clone.
		[string] [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] $RepositoryBranch = "master",
		# The organization of the repository.\gg
		[string] [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] $AzureDevOpsOrganization
	)

	$azureDevOpsSSHurl = "{0}@vs-ssh.visualstudio.com:v3/{0}/{1}/{2}" -f $AzureDevOpsOrganization, $RepositoryOwner, $RepositoryName
	$githubUrl = "git@github.com:{0}/{1}.git" -f $RepositoryOwner, $RepositoryName

	If ($RepositoryType -eq "GitHub")
	{
		$repositoryUrl = $githubUrl
	}
	ElseIf ($RepositoryType -eq "AzureDevOps")
	{
		$repositoryUrl = $azureDevOpsSSHurl
	}
	Else
	{
		Throw "Invalid repository type '$RepositoryType'."
	}

	Write-Host -ForegroundColor DarkGray "Checking if $repositoryUrl is already cloned in $repositoryRootPath..."
	If (-not (Test-Path -Path "$repositoryRootPath\$repositoryName"))
	{
		Write-Host -ForegroundColor DarkGray "$repositoryUrl is not cloned in $repositoryRootPath. Cloning repository..."
		git clone -b $RepositoryBranch $repositoryUrl "$repositoryRootPath\$RepositoryName"
		Write-Host -ForegroundColor DarkGray "Repository cloned."
	}
	Else
	{
		Write-Host -ForegroundColor DarkGray "$RepositoryName repository is already cloned."

		Write-Host -ForegroundColor DarkGray "Pulling latest changes from $RepositoryBranch branch..."
		git -C "$repositoryRootPath\$RepositoryName" pull origin $RepositoryBranch
		Write-Host -ForegroundColor DarkGray "Latest changes pulled."
	}

	Write-Host -ForegroundColor DarkGray "Adding $repositoryRootPath\$RepositoryName to safe.directory..."
	git config --global --add safe.directory "$repositoryRootPath\$RepositoryName" > $null
	Write-Host -ForegroundColor DarkGray "safe.directory added."

	Write-Host -ForegroundColor DarkCyan "Repository '$repositoryUrl' cloned."
}

Function Test-SymLink([string]$path)
{
	<#
		.DESCRIPTION
		Tests if a path is a symlink.
	#>

	$file = Get-Item $path -Force -ea SilentlyContinue
	return [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

Function Install-SymLinkToEditorSettings
{
	<#
		.DESCRIPTION
		Installs a symlink to the editor settings.
	#>

	Param
	(
		# The type of editor to install settings for.
		[string] [Parameter(Mandatory = $true)] [ValidateSet('VSCode', 'Cursor')] $EditorType
	)

	If ($EditorType -eq "VSCode")
	{
		$editorSettingsPath = "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json"
	}
	ElseIf ($EditorType -eq "Cursor")
	{
		$editorSettingsPath = "$env:USERPROFILE\AppData\Roaming\Cursor\User\settings.json"
	}
	Else
	{
		Throw "Invalid editor type '$EditorType'."
	}

	Write-Host -ForegroundColor DarkGray "Checking if symlink to editor settings exists..."
	If (Test-SymLink -Path $editorSettingsPath)
	{
		Write-Host -ForegroundColor DarkGray "Symlink to editor settings exists."
	}
	Else
	{
		Write-Host -ForegroundColor DarkGray "Symlink to editor settings does not exist. Creating symlink..."

		Write-Host -ForegroundColor DarkGray "Removing existing local settings.json if it exists..."
		If (Test-Path -Path $editorSettingsPath)
		{
			Remove-Item -Path $editorSettingsPath
			Write-Host -ForegroundColor DarkGray "Existing local settings.json removed."
		}

		Write-Host -ForegroundColor DarkGray "Creating symlink to VSCode settings..."
		New-Item -ItemType SymbolicLink -Path $editorSettingsPath -Target "$repositoryRootPath\workstation\$EditorType\settings.json" | Out-Null
		Write-Host -ForegroundColor DarkGray "Symlink to editor settings created."
	}

	Write-Host "Symlink to editor settings created."
}

Function Install-EditorExtensions
{
	<#
		.DESCRIPTION
		Installs editor extensions.
	#>

	Param
	(
		# The type of editor to install extensions for.
		[string] [Parameter(Mandatory = $true)] [ValidateSet('VSCode', 'Cursor')] $EditorType
	)

	Write-Host -ForegroundColor DarkGray "Configuring extensions for $EditorType..."
	$extensions = Get-Content -Path "$repositoryRootPath\workstation\vscode\extensions-to-install.json" | ConvertFrom-Json

	If ($EditorType -eq "VSCode")
	{
		$editorPath = "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code"
		$editorExe = Join-Path $editorPath "Code.exe"
		$cliJs = Join-Path $editorPath "resources\app\out\cli.js"
	}
	ElseIf ($EditorType -eq "Cursor")
	{
		$editorPath = "$env:USERPROFILE\AppData\Local\Programs\Cursor"
		$editorExe = Join-Path $editorPath "Cursor.exe"
		$cliJs = Join-Path $editorPath "resources\app\out\cli.js"
	}
	Else
	{
		Throw "Invalid editor type '$EditorType'."
	}

	$env:ELECTRON_RUN_AS_NODE = 1
	$output = & $editorExe $cliJs --list-extensions
	$installedExtensions = $output -split "`n"

	ForEach ($extension in $extensions)
	{
		If ($installedExtensions.Contains($extension))
		{
			Write-Host -ForegroundColor DarkGray "$extension already installed."
		}
		Else {
			Write-Host -ForegroundColor DarkGray "Installing" $extension "..."
			& $editorExe $cliJs --install-extension $extension > $null
			Write-Host -ForegroundColor DarkGray "Extension '$extension' installed."
		}
	}

	Write-Host "Editor extensions installed for $EditorType."
}

Function Install-EditorKeybindings
{
	<#
		.DESCRIPTION
		Installs editor keybindings.
	#>

	Param
	(
		# The type of editor to install keybindings for.
		[string] [Parameter(Mandatory = $true)] [ValidateSet('VSCode', 'Cursor')] $EditorType
	)

	Write-Host -ForegroundColor DarkGray "Configuring keybindings for $EditorType..."
	$genericEditorKeybindingsPath = "$repositoryRootPath\workstation\vscode\keybindings.json"
	$editorSpecificKeybindingsPath = "$repositoryRootPath\workstation\vscode\$EditorType-keybindings.json"

	Write-Host -ForegroundColor DarkGray "Getting keybindings from $genericEditorKeybindingsPath..."
	$keybindings = Get-Content -Path $genericEditorKeybindingsPath | ConvertFrom-Json
	Write-Host -ForegroundColor DarkGray "Keybindings from $genericEditorKeybindingsPath retrieved."

	Write-Host -ForegroundColor DarkGray "Getting keybindings from $editorSpecificKeybindingsPath..."
	$editorSpecificKeybindings = Get-Content -Path $editorSpecificKeybindingsPath | ConvertFrom-Json
	Write-Host -ForegroundColor DarkGray "Keybindings from $editorSpecificKeybindingsPath retrieved."

	Write-Host -ForegroundColor DarkGray "Combining keybindings..."
	$combinedKeybindings = $keybindings + $editorSpecificKeybindings

	If ($EditorType -eq "VSCode")
	{
		$editorKeybindingsPath = "$env:USERPROFILE\AppData\Roaming\Code\User\keybindings.json"
		Write-Host -ForegroundColor DarkGray "VSCode keybindings path: $editorKeybindingsPath"
	}
	Else
	{
		$editorKeybindingsPath = "$env:USERPROFILE\AppData\Roaming\Cursor\User\keybindings.json"
		Write-Host -ForegroundColor DarkGray "Cursor keybindings path: $editorKeybindingsPath"
	}

	Write-Host -ForegroundColor DarkGray "Writing keybindings to $editorKeybindingsPath..."
	Set-Content -Path $editorKeybindingsPath -Value ($combinedKeybindings | ConvertTo-Json)
	Write-Host -ForegroundColor DarkGray "Keybindings written."
	Write-Host "Editor keybindings installed for $EditorType."
}

Function Install-GlazeWindowManager
{
	<#
		.DESCRIPTION
		Installs Glaze Window Manager.
	#>

	$glazeConfigRootPath = "$env:USERPROFILE\.glzr\GlazeWm"
	$glazeConfigPath = "$glazeConfigRootPath\config.yaml"

	Write-Host -ForegroundColor DarkGray "Installing Glaze Window Manager..."
	Invoke-Expression "winget install --id GlazeWM -e --silent --source winget"
	Write-Host -ForegroundColor DarkGray "Glaze Window Manager installed."

	Write-Host -ForegroundColor DarkGray "Configuring Glaze Window Manager..."

	Write-Host -ForegroundColor DarkGray "Removing existing config.yaml if it exists..."
	If (Test-Path -Path $glazeConfigPath)
	{
		Remove-Item -Path $glazeConfigPath
		Write-Host -ForegroundColor DarkGray "Existing config.yaml removed."
	}

	Write-Host -ForegroundColor DarkGray "Creating path to config.yaml if it doesn't exist..."
	If (-not (Test-Path -Path $glazeConfigRootPath))
	{
		New-Item -ItemType Directory -Path $glazeConfigRootPath | Out-Null
		Write-Host -ForegroundColor DarkGray "Path to config.yaml created."
	}
	Else
	{
		Write-Host -ForegroundColor DarkGray "Path to config.yaml already exists."
	}

	Write-Host -ForegroundColor DarkGray "Creating symlink to config.yaml..."
	New-Item -ItemType SymbolicLink -Path $glazeConfigPath -Target "$repositoryRootPath\workstation\glazewm\config.yaml" | Out-Null
	Write-Host -ForegroundColor DarkGray "Symlink to config.yaml created."

	Write-Host "Glaze Window Manager configured."
}



Install-Git
Enable-OpenSshService
Install-SshKey
Write-Host -NoNewline -ForegroundColor Yellow "Add the SSH key to GitHub, then press Enter to continue..."
Read-Host | Out-Null
Install-GitRepository -RepositoryType "GitHub" -RepositoryOwner $PERSONAL_GITHUB_USERNAME -RepositoryName "workstation"
Install-GitRepository -RepositoryType "GitHub" -RepositoryOwner $PERSONAL_GITHUB_USERNAME -RepositoryName "notes"

Install-VSCode
Install-SymLinkToEditorSettings -EditorType "VSCode"
Install-EditorKeybindings -EditorType "VSCode"
Install-EditorExtensions -EditorType "VSCode"

Write-Host -ForegroundColor DarkGray "Checking if Cursor is installed..."
If (Test-Path -Path "$env:USERPROFILE\AppData\Local\Programs\Cursor")
{
	Write-Host -ForegroundColor DarkGray "Cursor is installed. Installing Cursor settings..."
	# Install-SymLinkToEditorSettings -EditorType "Cursor"
	# Install-EditorKeybindings -EditorType "Cursor"
	# Install-EditorExtensions -EditorType "Cursor"
}
Else
{
	Write-Host -ForegroundColor DarkGray "Cursor is not installed. Skipping Cursor configuration..."
}

Install-GlazeWindowManager

Write-Host -ForegroundColor Green "`n[CONFIGURATION COMPLETE]"