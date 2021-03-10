param (
    [string] $version = '1804',
    [switch] $skipDownload
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if (!$skipDownload) {
    Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-${version} -OutFile ~\Downloads\Ubuntu-${version}.appx -UseBasicParsing
}

Add-AppxPackage ~\Downloads\Ubuntu-${version}.appx

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

[string] $tempDistroPath = "$($env:TEMP)\hvk8s\wsl\ubuntu${version}"
New-item -Path $tempDistroPath -ItemType Directory -Force
Copy-Item -Path "$($ubuntu.InstallLocation)\ubuntu${version}.exe" -Destination $tempDistroPath -Force
Copy-Item -Path "$($ubuntu.InstallLocation)\install.tar.gz" -Destination $tempDistroPath -Force

[string] $tempFile = New-TemporaryFile
"hvk8s`nhvk8s`nhvk8s`nexit`n" | Out-File -Encoding ascii -NoNewline -FilePath $tempFile

Start-Process -RedirectStandardInput $tempFile -FilePath "${tempDistroPath}\ubuntu${version}.exe" -Wait -NoNewWindow
