param (
    [string] $server,
    [Parameter(Mandatory)][string] $username,
    [Parameter(Mandatory)][string] $password,
    [string] $repository = 'ripcordsoftware',
    [string] $image = 'flannel',
    [string] $localTag = 'local',
    [string] $tag = 'windowsservercore-20h2'
)

$ErrorActionPreference = 'Stop'

docker login -u $username -p $password $server
if (!$?) {
    Write-Error 'Unable to login to the repository'
}

[string] $localImage = "${image}:${localtag}"
[string] $remoteImage = "${repository}/${image}:${tag}"
if ($server) {
    $remoteImage = "${server}/${remoteImage}"
}

docker tag $localImage $remoteImage
if (!$?) {
    Write-Error "Unable to tag '${localImage}' as '${remoteImage}'"
}

docker push $remoteImage
if (!$?) {
    Write-Error "Unable to push '${remoteImage}' to the repository"
}
