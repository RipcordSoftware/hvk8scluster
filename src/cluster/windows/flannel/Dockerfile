# escape=`

ARG WINVER=20h2
FROM "mcr.microsoft.com/powershell:lts-windowsservercore-$WINVER" as core

FROM "mcr.microsoft.com/powershell:lts-nanoserver-$WINVER"

COPY --from=core /windows/system32/netapi32.dll /windows/system32/netapi32.dll

SHELL ["pwsh", "-command"]
USER ContainerAdministrator

ARG winsVersion="0.0.4"
ARG yqVersion="2.4.1"
WORKDIR /utils/
RUN $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; `
    Invoke-WebRequest -UseBasicParsing -Uri https://github.com/rancher/wins/releases/download/v${env:winsVersion}/wins.exe -OutFile wins.exe; `
    Invoke-WebRequest -UseBasicParsing -Uri https://github.com/mikefarah/yq/releases/download/${env:yqVersion}/yq_windows_amd64.exe -OutFile yq.exe; `
    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name 'Path' -Value \"${env:PATH};${pwd};\"

ARG cniVersion="0.8.7"
WORKDIR /cni/
RUN $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; `
    Invoke-WebRequest -UseBasicParsing -Uri https://github.com/containernetworking/plugins/releases/download/v${env:cniVersion}/cni-plugins-windows-amd64-v${env:cniVersion}.tgz -OutFile cni.tgz; `
    tar -xmf cni.tgz; `
    rm cni.tgz

ARG flannelVersion="0.15.0"
WORKDIR /k/flannel/
RUN $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; `
    Invoke-WebRequest -UseBasicParsing -Uri https://github.com/coreos/flannel/releases/download/v${env:flannelVersion}/flanneld.exe -OutFile flanneld.exe; `
    Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/windows/hns.psm1 -OutFile hns.psm1
COPY setup.exe ./

WORKDIR /
