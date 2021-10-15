# kube-proxy for Windows Server Core 2019 (20h2)

## Why?
Windows container images require a close match to the host operating system. The [sig-windows-tools][1] [kube-proxy][2] image
targets `nanoserver-1809` which doesn't run under `20h2`. Additionally `nanoserver-20h2` won't allow calls to
`Set-ItemProperty`.

## Requires
* Docker (Windows Containers)

## Usage
Build the image with `build.ps1` and publish with `publish.ps1`.

> NB. the base Windows Server image is large, pulling this image is slow.

## Credits
[sig-windows-tools][1] for:
* Dockerfile (inspiration)

[1]: https://github.com/kubernetes-sigs/sig-windows-tools
[2]: https://github.com/kubernetes/kube-proxy
