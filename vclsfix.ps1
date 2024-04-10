function vclsFix ($vcServer, $vcUser, $vcPass, $hostUser, $hostPass){

    $vm = ""
    $vCLSvm = ""
    foreach ($vc in $vcServer){
        
        connectVI -vmhost $vc -vmUser $vcUser -vmPassword $vcPass -numTries 10
        logger "Setting permissions for vCLS manipulation"
        $newPrivs = $(get-VIRole -name Admin).ExtensionData.Privilege | Where-Object {$_ -match "VirtualMachine.Config"}
        $newPrivs | ForEach-Object {Set-VIRole -Role vCLSadmin -AddPrivilege (Get-VIPrivilege -id $_)}
        logger "Finding vCLS VM"
        $vms = get-vm -name vCLS* | Where-Object {$_.PowerState -match "PoweredOff"}
        if ($vms -ne $null){
                 do {
                        foreach($vm in $vms) {
                            $vCLSvm = get-vm -name vCLS* | Where-Object {$_.PowerState -match "PoweredOff"}
                            logger "Waiting for EVC mode to be set by vCenter - 20 attempts before moving on"
                            $evcChkCnt = 0
                            
                            do {

                                $evcSet = $(Get-VM $vCLSvm | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty Runtime | Select-Object -ExpandProperty FeatureMask).Count
                                logger "Featuremask count for $vCLSvm is currently $evcSet"
                                Start-Sleep 10
                                $evcChkCnt++

                            } until ($evcSet -gt 0 -or $evcChkCnt -eq 20)

                            logger "Setting HW version 14 and disabling EVC mode on vCLS VM"
                            $vCLSvm | Set-VM -Version v14 -Confirm:$false
                            $vCLSvm.ExtensionData.ApplyEvcModeVM_Task($null,$true)
                            $poweredOn = $false
                            do {
                                logger "Waiting for VM to power on"   
                                $thisvCLSvm = get-vm -name $vCLSvm.Name
                                if ($thisvCLSvm.PowerState -match "PoweredOn") { $poweredOn = $true }
                                Start-Sleep 10
                            } until ($poweredOn)
                            #$vCLSvm | Start-VM
                            logger "Waiting for additional vCLS VM to be created"
                            Start-Sleep 30
                            logger "Finding additional vCLS VM's"
                            $vm = get-vm -name vCLS* | Where-Object {$_.PowerState -match "PoweredOff"}
                        }
                    } while ($vm)
        } else {
            logger "vCLS VM's have all been created/configured and started on $vc"
        }
        
        disconnect-viserver * -Confirm:$false -Force | Out-Null
    }
}
