# Usage: Launch an Admin Prompt
# powershell -File .\plgxinstallosq.ps1 -ipath <folder_path> -u <true|false>

param(
    [string]$ipath = $PWD,
    [string]$u = "false"
)


# Globals
$OsquerdFile = 'osqueryd.exe'
$OsqueriFile = 'osqueryi.exe'
$BoostDllFile = 'boost_context-vc140-mt-x32-1_66.dll'
$OsqFlagFile = 'osquery.flags'
$OsqConfFile = 'osquery.conf'
$VcRedistFile = 'vc_redist.x86.exe'

$OsqRoot = "$env:ProgramData\osquery"
$OsqSvc = "osqueryd"

function CreateOsqDirStructure {
    New-Item -Path "$OsqRoot" -ItemType Directory -Force -ErrorAction SilentlyContinue
    New-Item -Path "$OsqRoot\osqueryd" -ItemType Directory -Force -ErrorAction SilentlyContinue
    New-Item -Path "$OsqRoot\log" -ItemType Directory -Force -ErrorAction SilentlyContinue
}


function CopyFilesToOsqInstallPath {

    if (Test-Path -Path $ipath\$OsquerdFile) {
        $dstpath = "$Env:Programdata\osquery\osqueryd\$OsquerdFile"
        Write-Host -ForegroundColor Yellow "[+] Copying osqueryd.exe to default osquery install location."
        Copy-Item -Path "$ipath\$OsquerdFile" -Destination $dstpath -Force
    }
    if (Test-Path -Path $ipath\$BoostDllFile) {
        $dstpath = "$Env:Programdata\osquery\osqueryd\$BoostDllFile"
        Write-Host -ForegroundColor Yellow "[+] Copying $BoostDllFile to default osquery install location."
        Copy-Item -Path "$ipath\$BoostDllFile" -Destination $dstpath -Force
    }

    if (Test-Path -Path $ipath\$OsqueriFile) {
        $dstpath = "$Env:Programdata\osquery\$OsqueriFile"
        Write-Host -ForegroundColor Yellow "[+] Copying osqueryi.exe to default osquery install location."
        Copy-Item -Path "$ipath\$OsqueriFile" -Destination $dstpath -Force
    }
    if (Test-Path -Path $ipath\$BoostDllFile) {
        $dstpath = "$Env:Programdata\osquery\$BoostDllFile"
        Write-Host -ForegroundColor Yellow "[+] Copying $BoostDllFile to default osquery install location."
        Copy-Item -Path "$ipath\$BoostDllFile" -Destination $dstpath -Force
    }

    if (Test-Path -Path $ipath\$OsqFlagFile) {
        $dstpath = "$Env:Programdata\osquery\$OsqFlagFile"
        Write-Host -ForegroundColor Yellow "[+] Copying flagfile to default osquery install location."
        Copy-Item -Path "$ipath\$OsqFlagFile" -Destination $dstpath -Force
    }

    if (Test-Path -Path $ipath\$OsqConfFile) {
        $dstpath = "$Env:Programdata\osquery\$OsqConfFile"
        Write-Host -ForegroundColor Yellow "[+] Copying conf files to default osquery install location."
        Copy-Item -Path "$ipath\$OsqConfFile" -Destination $dstpath -Force
    }
}



function StartOsqueryService {
    $ServiceName = 'osqueryd'

    if (Get-Service "$ServiceName*" -Include $ServiceName) {
        $ServiceObj = Get-Service -Name $ServiceName

        Write-Host -ForegroundColor YELLOW "[+] Starting $ServiceName Service"
        Start-Service -Name $ServiceName

        Start-Sleep(3)
        $ServiceObj.Refresh()
        Write-Host -ForegroundColor YELLOW "[+] $ServiceName Service Status: "$ServiceObj.Status
    }
    else {
        Write-Host -ForegroundColor Red "[-] $ServiceName Doesn't Exits, Retry Again."
        Exit -1
    }
}


function StopOsqueryService {

    $ServiceName = 'osqueryd'
    $ServiceObj = Get-Service -Name $ServiceName

    if ($ServiceObj.Status -eq 'Running') {
        Stop-Service $ServiceName  -ErrorAction SilentlyContinue
        Write-Host -ForegroundColor Yellow '[+] Osqueryd Service Status: '  $ServiceObj.status
        Write-Host -ForegroundColor Yellow '[+] Osqueryd Service Stop Initiated...Wait for service to stop'

        Start-Sleep -Seconds 10
        $ServiceObj.Refresh()
    }

    # fetch osqueryd and extension process object to terminate forcefully if they survive
    $OsquerydProc = Get-Process osqueryd -ErrorAction SilentlyContinue

    if ($ServiceObj.Status -ne 'Stopped' -Or $OsquerydProc) {
        Write-Host -ForegroundColor Yellow '[+] Force kill osqueryd process if still exist'

        if ($OsquerydProc) {
            Stop-Process -Name 'osqueryd' -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host -ForegroundColor Yellow '[+] Osqueryd Service Stopped'
}

# Adapted from http://www.jonathanmedd.net/2014/01/testing-for-admin-privileges-in-powershell.html
function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator"
    )
}

function Usage() {
    Write-Host ""
    Write-Host -ForegroundColor YELLOW  "======================== USAGE ========================"
    Write-Host "From Admin Powershell Prompt with permission to execute script"
    Write-Host ".\plgxinstallosq.ps1 -ipath <folder_path> -u <true|false>"
    Write-Host "NOTE: Folder with valid files to replace, If none then CWD is used"
    Write-Host -ForegroundColor YELLOW  "======================================================="
    Write-Host ""
}

function CreateOsqueryService {
    New-Service -Name "$OsqSvc" -BinaryPathName "$OsqRoot\osqueryd\osqueryd.exe --flagfile=C:\ProgramData\osquery\osquery.flags" -DisplayName "Osquery Daemon Service" -StartupType Automatic -Description "Osquery Daemon Service."

    $Cmd = "sc.exe config $OsqSvc start= delayed-auto"
    $Output = Invoke-Expression -Command $Cmd -ErrorAction Stop
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[-] Failed to set $OsqSvc to delayed start. More details: $Output" -foregroundcolor red
    }
    else {
        Write-Host "[+] Successfully changed $Service service to delayed start" -foregroundcolor green
    }    
}

function DeleteOsqueryService {
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='$OsqSvc'"
    $service.delete()
    # Remove-Service -Name "$OsqSvc"
}

function RemovePrevOsquery {
    StopOsqueryService
    DeleteOsqueryService
    Start-Sleep(5)
}

function CheckPrevOsqInstall {
    $ServiceName = 'osqueryd'

    if (Get-Service "$ServiceName*" -Include $ServiceName) {
        Write-Host -ForegroundColor YELLOW "[+] $ServiceName Service already exists. Prev Instance of osquery found"
        if ($u.Equals("true")) {
            Write-Host -ForegroundColor Yellow "[+] Cleanup Prev Osquery Install before proceeeding further"
            RemovePrevOsquery
        }
        else {
            Write-Host -ForegroundColor Red "[-] Cleanup Prev Osquery Install before proceeeding further"
            Usage
            Exit -1
        }
    }
}

function InstallVcRedistRuntime {
    if (Test-Path -Path $ipath\$VcRedistFile) {
        $Cmd = "$ipath\vc_redist.x86 /install /passive /norestart"
        Write-Host $Cmd
        $Output = Invoke-Expression -Command $Cmd -ErrorAction Stop
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[-] Failed to install VC Redistributables, Please Install Manualy. More details: $Output" -ForegroundColor Red
        }
        else {
            Write-Host "[+] Successfully installed VC Redistributables" -ForegroundColor Green
        }
        Start-Sleep(5)
    }
    else {
        Write-Host "[-] Failed to find $VcRedistFile for installation, Please Check Manually that VC Redsitributables are installed"
    }
}


function InstallOsquery {
    CheckPrevOsqInstall
    CreateOsqDirStructure
    CopyFilesToOsqInstallPath
    InstallVcRedistRuntime
    CreateOsqueryService
    StartOsqueryService
}

function Main() {
    Write-Host -ForegroundColor YELLOW  "============ Polylogyx Helper Script to install osquery. ============"

    Write-Host "[+] Verifying script is running with Admin privileges" -ForegroundColor Yellow
    if (-not (Test-IsAdmin)) {
        Write-Host "[-] ERROR: Please run this script with Admin privileges!" -ForegroundColor Red
        Usage
        Exit -1
    }

    InstallOsquery
    Write-Host -ForegroundColor Green '[+] Osquery Installed SuccessFully, Please Check osqueryd services.'
    Write-Host -ForegroundColor Yellow "========================================================================"
}


$startTime = Get-Date
$null = Main
$endTime = Get-Date
Write-Host "[+] Total time taken:  $(($endTime - $startTime).TotalSeconds) seconds."