param (
    [int] $nodeCount = 3,
    [int] $nodeMemoryMB = 4096,
    [int] $masterMemoryMB = 2048,
    [string] $vmTemplateName = 'hvk8s-template',
    [string] $sshUser = "hvk8s",
    [string] $sshPrivateKeyPath,
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $updateVm,
    [switch] $skipVmProvisioning,
    [switch] $skipLbProvisioning,
    [switch] $ignoreKeyPermissions,
    [switch] $disableVmTemplate,
    [switch] $flannel
)

$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/scripts/hvk8s/config.ps1"
. "${PSScriptRoot}/scripts/modules/ssh.ps1"
. "${PSScriptRoot}/scripts/modules/vm.ps1"
. "${PSScriptRoot}/scripts/modules/cluster.ps1"
. "${PSScriptRoot}/scripts/modules/backgroundprocess.ps1"

if (!$global:rs.Vm::IsInstalled()) {
    Write-Error "Hyper-V is not installed or the service isn't running, please install manually or using the provided scripts"
}

if (!$global:rs.Vm::IsAdministrator()) {
    Write-Error "You require Administrator rights or membership of the 'Hyper-V Administrator' group"
}

if (!$sshPrivateKeyPath) {
    $sshPrivateKeyPath = $global:rs.Ssh::DiscoverPrivateKeyPath($global:rs.Config::RepoRoot)
}

# define the cluster
[object] $master = @{ vmName = "hvk8s-master"; hostname = "hvk8s-master"; ip = $global:rs.Config::Vm.Master.Ip; node = $false; memoryMB = $masterMemoryMB }
[object] $cluster = @( $master )

if ($nodeCount -gt 0) {
    $cluster += @(1 .. $nodeCount) | ForEach-Object {
        [int] $nodeId = $_
        [string] $hostIp = $global:rs.Config::Vm.Master.Ip -replace '[0-9]$',"${nodeId}"
        @{ vmName = "hvk8s-node${nodeId}"; hostname = "hvk8s-node${nodeId}"; ip = ${hostIp}; node = $true; memoryMB = $nodeMemoryMB }
    }
}

# check the read/write permissions on the private key file
if (!$ignoreKeyPermissions -and !$global:rs.Ssh::CheckKeyFilePermissions($sshPrivateKeyPath)) {
    Write-Error "The permissions on the private key file '$sshPrivateKeyPath' are too open, OpenSSH requires these are limited to the current user only. Alternately specify -ignoreKeyPermissions on the command line."
}

# check the template is available unless we are in non-template mode
if (!$disableVmTemplate -and $vmTemplateName -and !$global:rs.Vm::GetExportedVmConfigPath($vmTemplateName)) {
    Write-Error "Unable to find VM template '${vmTemplateName}', you must create the template file or specify -disableVmTemplate"
}

# give the background processes access to the app args
$global:rs.BackgroundProcess::SetInitialVars($MyInvocation)

# check the DHCP server is available
$global:rs.BackgroundProcess::SpinWait("Checking the DHCP server is available...", {
    [object] $dhcpServer = $global:rs.Vm::GetVM($rs.Config::Vm.Dhcp.Name)
    if (!$dhcpServer -or !$global:rs.Ssh::TestSsh($rs.Config::Vm.Dhcp.Ip)) {
        Write-Error "Unable to find the DHCP/DNS server, is it running?"
    }
})

# reset the DHCP server
$global:rs.BackgroundProcess::SpinWait("Resetting the DHCP server...", {
    $global:rs.Ssh::InvokeRemoteCommand($global:rs.Config::Vm.Dhcp.Ip, './remote-commands/reset-dnsmasq-state.sh', $sshUser, $sshPrivateKeyPath) | Out-Null
})

# provision the VMs on Hyper-V
if (!$skipVmProvisioning) {
    $cluster | ForEach-Object {
        [object] $vm = $_
        [string] $vmName = $vm.vmName
        if (!$disableVmTemplate -and $vmTemplateName) {
            $global:rs.BackgroundProcess::SpinWait("Cloning '${vmTemplateName}' to '${vmName}'...", { param ($vm)
                .\clone-k8s-vm.ps1 `
                    -vmTemplateName $vmTemplateName -vmName $vm.vmName -vmIp $vm.ip -vmMemoryMB $vm.memoryMB `
                    -removeVhd:$removeVhd -removeVm:$removeVm -updateVm:$updateVm
            }, @{ vm = $vm })
        } else {
            $global:rs.BackgroundProcess::SpinWait("Creating '${vmName}'...", { param ($vm)
                .\install-k8s-vm.ps1 `
                    -vmName $vm.vmName -vmIp $vm.ip -vmMemoryMB $vm.memoryMB `
                    -removeVhd:$removeVhd -removeVm:$removeVm -updateVm:$updateVm
            }, @{ vm = $vm })
        }
    }

    # configure the VM networking
    $cluster | ForEach-Object {
        [object] $vm = $_
        [string] $vmName = $vm.vmName
        [string] $ip = $null

        [string] $ip = $global:rs.BackgroundProcess::SpinWait("Waiting for VM IP address for '${vmName}'...", { param ($vm)
            [string] $ip = $null
            while (!$ip) {
                $ip = $global:rs.Vm::WaitForIpv4($vm.vmName, $false)
            }
            return $ip
        }, @{ vm = $vm })

        if ($ip) {
            $global:rs.BackgroundProcess::SpinWait("Waiting for active SSH on '${ip}'...", { param ($ip)
                $global:rs.Ssh::WaitForSsh($ip, $false)
            }, @{ ip = $ip })

            $global:rs.BackgroundProcess::SpinWait("Discovered '${vmName}' on '${ip}'", { param ($vm, $ip)
                $global:rs.Cluster::SetHostName($ip, $vm.hostname, $sshUser, $sshPrivateKeyPath)
            }, @{ vm = $vm; ip = $ip})
        }
    }
}

# initialize the master
$cluster | Where-Object { !$_.node } | ForEach-Object {
    [object] $vm = $_

    $global:rs.BackgroundProcess::SpinWait("Waiting for active SSH on '$($vm.ip)'...", { param ($vm)
        $global:rs.Ssh::WaitForSsh($vm.ip, $false)
    }, @{ vm = $vm })

    $global:rs.BackgroundProcess::SpinWait("Initializing cluster master '$($vm.hostname)'...", { param ($vm)
        $global:rs.Cluster::InitializeMaster($vm.ip, $sshUser, $sshPrivateKeyPath)

        if ($flannel) {
            $global:rs.Cluster::InitializeFlannel($vm.ip, $sshUser, $sshPrivateKeyPath)
        } else {
            $global:rs.Cluster::InitializeCalico($vm.ip, $sshUser, $sshPrivateKeyPath)
        }

    }, @{ vm = $vm })
}

# get the cluster join command
[string] $masterIp = $cluster | Where-Object { !$_.node } | ForEach-Object { $_.ip } | Select-Object -First 1
[string] $joinCommand = $global:rs.BackgroundProcess::SpinWait("Get cluster join command...", { param ($ip)
    return $global:rs.Cluster::GetJoinCommand($ip, $sshUser, $sshPrivateKeyPath)
}, @{ ip = $masterIp})

# initialize the nodes
$cluster | Where-Object { $_.node } | ForEach-Object {
    [object] $vm = $_

    $global:rs.BackgroundProcess::SpinWait("Waiting for active SSH on '$($vm.ip)'...", { param ($vm)
        $global:rs.Ssh::WaitForSsh($vm.ip, $false)
    }, @{ vm = $vm })

    $global:rs.BackgroundProcess::SpinWait("Node '$($vm.hostname)' is requesting to join the cluster...", { param ($vm, $joinCommand)
        $global:rs.Cluster::Join($vm.ip, $joinCommand, $sshUser, $sshPrivateKeyPath)
    }, @{ vm = $vm; joinCommand = $joinCommand })
}

if (!$skipLbProvisioning) {
    $global:rs.BackgroundProcess::SpinWait("Installing bitnami-metallb...", {
        $global:rs.Ssh::InvokeRemoteCommand($global:rs.Config::Vm.Master.Ip, './remote-commands/install-bitnami-metallb-chart.sh', $sshUser, $sshPrivateKeyPath)
    })
}
