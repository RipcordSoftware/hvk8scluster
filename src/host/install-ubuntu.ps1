param (
    [string] $user = 'hvk8s',
    [string] $password = 'hvk8s',
    [string] $version = '1804',
    [switch] $skipDownload,
    [switch] $skipStore
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

[string] $downloadDir = "~\Downloads"
[string] $archivePath = "${downloadDir}\Ubuntu-${version}.appx"
[string] $tempDistroDir = "$($env:TEMP)\hvk8s\wsl\ubuntu${version}"
[string] $archiveZipPath = "${tempDistroDir}\Ubuntu-${version}.zip"

if (!$skipDownload) {
    Write-Host "Downloading the Linux distribution package..."
    Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-${version} -OutFile $archivePath -UseBasicParsing | Out-Null
}

New-item -Path $tempDistroDir -ItemType Directory -Force | Out-Null

if ($skipStore) {
    Write-Host "Unpacking the distribution package..."
    Copy-Item -Path $archivePath -Destination $archiveZipPath | Out-Null
    Expand-Archive -Path $archiveZipPath -DestinationPath $tempDistroDir -Force | Out-Null
}
else {
    Write-Host "Registering the package as an application..."

    Add-AppxPackage $archivePath

    # get the path to the package so we can run it for the first time
    [object] $packages = Get-AppxPackage
    [object] $ubuntu = $packages |
        Where-Object { $_ -and $_.InstallLocation } |
        Where-Object {
            [string] $manifestPath = Join-Path -Path $_.InstallLocation -ChildPath "AppxManifest.xml"
            if (Test-Path $manifestPath) {
                [object] $doc = [System.Xml.XmlDocument]::new()
                [object] $tr = [System.Xml.XmlTextReader]::new($manifestPath)
                try {
                    $tr.Namespaces = $false
                    $doc.Load($tr)
                } finally {
                    $tr.Close()
                }

                [object] $node = $doc.DocumentElement.SelectSingleNode("/Package/Applications/Application[@Id='ubuntu${version}']")
                return $node
            }
        } | Select-Object -First 1

    Copy-Item -Path "$($ubuntu.InstallLocation)\ubuntu${version}.exe" -Destination $tempDistroDir -Force | Out-Null
    Copy-Item -Path "$($ubuntu.InstallLocation)\install.tar.gz" -Destination $tempDistroDir -Force | Out-Null
}

[string] $tempFile = New-TemporaryFile
try {
    "${user}`n${password}`n${password}`nexit`n" | Out-File -Encoding ascii -NoNewline -FilePath $tempFile

    Write-Host "Running the distribution for the first time..."
    Start-Process -RedirectStandardInput $tempFile -FilePath "${tempDistroDir}\ubuntu${version}.exe" -Wait -NoNewWindow
} finally {
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue | Out-Null
}
