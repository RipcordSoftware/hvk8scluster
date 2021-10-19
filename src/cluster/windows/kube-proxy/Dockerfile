# escape=`

ARG WINVER=20h2
FROM "mcr.microsoft.com/powershell:lts-nanoserver-$WINVER"

SHELL ["pwsh", "-command"]
USER ContainerAdministrator

ARG winsVersion="0.0.4"
ARG yqVersion="2.4.1"
WORKDIR /utils/
RUN $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; `
    Invoke-WebRequest -UseBasicParsing -Uri https://github.com/rancher/wins/releases/download/v${env:winsVersion}/wins.exe -OutFile wins.exe; `
    Invoke-WebRequest -UseBasicParsing -Uri https://github.com/mikefarah/yq/releases/download/${env:yqVersion}/yq_windows_amd64.exe -OutFile yq.exe; `
    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name 'Path' -Value \"${env:PATH};${pwd};\"

ARG k8sVersion="1.22.2"
WORKDIR /k/kube-proxy/
RUN $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; `
    Invoke-WebRequest -UseBasicParsing -Uri https://dl.k8s.io/v${env:k8sVersion}/bin/windows/amd64/kube-proxy.exe -OutFile kube-proxy.exe

WORKDIR /
