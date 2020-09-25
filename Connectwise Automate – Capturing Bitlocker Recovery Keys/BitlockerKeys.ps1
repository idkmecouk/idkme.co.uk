if (Get-Module -ListAvailable -Name BitLocker) {
    Import-Module BitLocker -DisableNameChecking
}else{
    write-host "Bitlocker PS Module not found. Exiting..."
    exit 1
}

$BitlockerVolumes = Get-BitLockerVolume | Where-Object {$_.VolumeStatus -eq "EncryptionInProgress" -or $_.VolumeStatus -eq "FullyEncrypted"}
$OUT = ""
if($BitlockerVolumes.Count -ne 0){
    foreach($Volume in $BitlockerVolumes){
        $MointPoint = $Volume.MountPoint
        if($Volume.ProtectionStatus -eq "On"){
            $Keys = $Volume.KeyProtector | where-object {$_.KeyProtectorType -eq "RecoveryPassword"}
            if($Keys.Count -ne 0){
                foreach($Key in $Keys){
                    $ID = $Key.KeyProtectorId
                    $RP = $Key.RecoveryPassword
                    $OUT += "$ID=$RP|"
                }
            }else{
                $OUT += "$MointPoint=NO_KEYS|"
            }
        }else{
            $OUT += "$MointPoint=ProtectionStatus:OFF|"
        }
    }
    write-host $OUT
}else{
    write-host "NONE FOUND"
}