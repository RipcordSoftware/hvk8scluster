# escape=`

ARG BASE="mcr.microsoft.com/powershell:lts-windowsservercore-20h2"
ARG winsVersion="0.0.4"
ARG yqVersion="2.4.1"
ARG cniVersion="0.8.7"
ARG flannelVersion="0.13.0"

FROM $BASE
ARG winsVersion
ARG yqVersion
ARG cniVersion
ARG flannelVersion

SHELL ["powershell", "-command"]

WORKDIR /utils/
RUN $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; `
    Invoke-WebRequest -UseBasicParsing -Uri https://github.com/rancher/wins/releases/download/v${env:winsVersion}/wins.exe -OutFile wins.exe; `
    Invoke-WebRequest -UseBasicParsing -Uri https://github.com/mikefarah/yq/releases/download/${env:yqVersion}/yq_windows_amd64.exe -OutFile yq.exe

WORKDIR /cni/
RUN $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; `
    Invoke-WebRequest -UseBasicParsing -Uri https://github.com/containernetworking/plugins/releases/download/v${env:cniVersion}/cni-plugins-windows-amd64-v${env:cniVersion}.tgz -OutFile cni.tgz; `
    tar -xmf cni.tgz; `
    rm cni.tgz

WORKDIR /k/flannel/
RUN $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; `
    Invoke-WebRequest -UseBasicParsing -Uri https://github.com/coreos/flannel/releases/download/v${env:flannelVersion}/flanneld.exe -OutFile flanneld.exe; `
    Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/windows/hns.psm1 -OutFile hns.psm1
COPY setup.exe ./

WORKDIR /
USER ContainerAdministrator