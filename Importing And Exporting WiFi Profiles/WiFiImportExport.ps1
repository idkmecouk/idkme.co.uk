$WiFiZipName="WifiProfiles.zip"

#$CurrentDir=$(Get-Location | select Path -ExpandProperty Path)
$CurrentDir=$($PSScriptRoot)

if(!$args[0]){
    $Option = Read-Host "Import(1) or Export (2)"
}else{
    $Option = $args[0]
}
switch($Option){
    1{
        Write-host "Import"
        if(Test-Path $WiFiZipName){
            Write-Host "Zip Found!"
            Expand-Archive -Path $WiFiZipName -Force
            $ExportPath="$CurrentDir\WifiProfiles\WiFiExport"
            foreach($file in Get-ChildItem $ExportPath){
                Write-Host $file
                netsh wlan add profile filename="$ExportPath\$file"
            }
            Remove-Item WifiProfiles -Recurse
            Remove-Item $WiFiZipName
        }else{
            Write-Host "Can't find $WiFiZipName"
        }
    }
    2{
        Write-host "Export"
        New-Item -Name "WiFiExport" -Path $CurrentDir -ItemType Directory -ErrorAction SilentlyContinue
        $CMD=$(netsh wlan export profile key=clear folder="$CurrentDir\WiFiExport")
        Compress-Archive -Path "WiFiExport" -DestinationPath $WiFiZipName
        Remove-Item WiFiExport -Recurse
    }
}
