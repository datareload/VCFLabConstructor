param ($vcServer,$vcUser,$vcPass)

    $vm = ""
    $vCLSvm = ""
    foreach ($vc in $vcServer){
        
        connect-viserver -server $vc -User $vcUser -password $vcPass
        write-host "Setting permissions for vCLS manipulation"
        $newPrivs = $(get-VIRole -name Admin).ExtensionData.Privilege | where {$_ -match "VirtualMachine.Config"}
        $newPrivs | foreach {Set-VIRole -Role vCLSadmin -AddPrivilege (Get-VIPrivilege -id $_)}
        write-host "Finding vCLS VM"
        $vms = get-vm -name vCLS* | Where-Object {$_.PowerState -match "PoweredOff"}
        if ($vms -ne $null){
                 do {
                        foreach($vm in $vms) {
                            $vCLSvm = get-vm -name vCLS* | Where-Object {$_.PowerState -match "PoweredOff"}
                            write-host "Setting HW version 14 and disabling EVC mode on vCLS VM"
                            $vCLSvm | Set-VM -Version v14 -Confirm:$false
                            $vCLSvm.ExtensionData.ApplyEvcModeVM_Task($null,$true)
                            $poweredOn = $false
                            do {
                                write-host "Waiting for VM to power on"   
                                $thisvCLSvm = get-vm -name $vCLSvm.Name
                                if ($thisvCLSvm.PowerState -match "PoweredOn") { $poweredOn = $true }
                                sleep 5
                            } until ($poweredOn)
                            #$vCLSvm | Start-VM
                            write-host "Waiting for additional vCLS VM to be created"
                            sleep 30
                            write-host "Finding additional vCLS VM's"
                            $vm = get-vm -name vCLS* | Where-Object {$_.PowerState -match "PoweredOff"}
                        }
                    } while ($vm)
        } else {
            write-host "vCLS VM's have all been created/configured and started on $vc"
        }
        
        disconnect-viserver * -Confirm:$false -Force | Out-Null
    }
