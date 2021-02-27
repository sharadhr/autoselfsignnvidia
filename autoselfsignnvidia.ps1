# Gets the self-extracting driver file name from the command-line.
# Asks for user input for driver exe file path.
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$DriverExePath
)

$DriverExePath = Resolve-Path -Path $DriverExePath

$DriverExeFolder = Split-Path -Path $DriverExePath -Parent
$DriverExePath -match '\d{3}\.\d{2}' | Out-Null
$ExtractPath = Join-Path -Path $DriverExeFolder -ChildPath ($Matches.0)

# Assumes 7-Zip is installed to the default directory, i.e. 'C:\Program Files\7-Zip\7z.exe'
$7zExePath = Join-Path -Path $env:ProgramFiles -ChildPath "7-Zip\7z.exe"

# Runs 7z to extract the driver into a folder named the version number of the specified driver exe.
& $7zExePath "x" $DriverExePath "-o${ExtractPath}"

# Sets the path of the INIs to be modified, and the NVIDIA setup.exe
$INFFullPath = Join-Path -Path $ExtractPath -ChildPath "Display.Driver"
$NVINFPath = Join-Path -Path $INFFullPath -ChildPath "nvdmwi.inf"
$SetupPath = Join-Path -Path $ExtractPath -ChildPath "setup.exe"

# Change working directory to the INIs path
Set-Location -Path $INFFullPath

# Import and edit the nvdmwi.inf file
foreach ($line in [System.IO.File]::ReadLines($NVINFPath)) {

}

$INFFile = Get-Content -Path $NVINFPath | ForEach-Object {
    # Write existing line
    $_

    # If line matches, replace
    if ($_ -match 'NVIDIA_DEV.1EB5.\d926.1028 = "NVIDIA Quadro RTX 5000"') {
        $NewLine = $_
        $NewLine = $NewLine -replace '(\w{4}\.)(\d)926(\.\w{4})', '$1${2}831$3'
        $NewLine
    }

    if ($_ -match '%NVIDIA_DEV\.1EB5\.\d926.1028% = Section\d{3}, PCI\\VEN_10DE&DEV_1EB5&SUBSYS_\d9261028') {
        $NewLine = $_
        $NewLine = $NewLine -replace '(\d)926(\d{4})', '${1}831$2'
        $NewLine = $NewLine -replace '(\w{4}\.)(\d)926(\.\w{4})', '$1${2}831$3'
        $NewLine
    }
}

# Write to the file
$INFFile | Set-Content $NVINFPath -Encoding utf8 -Force

# Delete the nv_disp.cat file
Remove-Item -Path "nv_disp.cat"

# Execute Inf2Cat on this folder
& 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.18362.0\x86\Inf2Cat.exe' /driver:.\ /os:10_RS4_X64 /verbose

# Execute signtool on this folder, but ask for password first
$Password = Read-Host -Prompt "Enter certificate password"
& 'D:\User Libraries\Downloads\cert signing\signtool.exe' sign /f 'D:\User Libraries\Documents\certificates\cert.pfx' /p $Password /t http://timestamp.digicert.com .\nv_disp.cat

# Silently execute the NVIDIA installer
& $SetupPath
