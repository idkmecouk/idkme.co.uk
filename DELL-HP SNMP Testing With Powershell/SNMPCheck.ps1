function Init-Snmp([string]$Hostname, [string]$Community = "public") {
    $comSnmp = New-Object -ComObject olePrn.OleSNMP
    $comSnmp.Open($Hostname, $Community)
    return $comSnmp
}

function Prepare-Oid([string]$Oid) {
    if( -not $Oid.StartsWith(".") ) {
        $Oid = ".$Oid"
    }
    return $Oid.Trim()
}

function Get-SnmpWalk() {
    [cmdletbinding()] Param(
        [Parameter(Position=0, Mandatory=$true)][string]$Hostname,
        [Parameter(Position=1, Mandatory=$true)][string]$Oid,
        [Parameter(Position=2, Mandatory=$false)][string]$Community = "public"
    )
    try { 
        $comSnmp = Init-Snmp -Hostname $Hostname -Community $Community
        $result = $comSnmp.GetTree((Prepare-Oid -Oid $Oid))
        $comSnmp.Close()
    }
    catch {
        $result = @()
    }
    $OutputTable = New-Object system.Data.DataTable “TestTable”
    $col0 = New-Object system.Data.DataColumn Oid,([string])
    $col1 = New-Object system.Data.DataColumn Value,([string])
    $OutputTable.columns.add($col0)
    $OutputTable.columns.add($col1)

    for($a = 0; $a -lt $result.Count / 2; $a++) {
        $row = $OutputTable.NewRow()
		$row.Oid = ".$($comSnmp.OIDFromString($($result[0, $a])) -join ".")"
		$row.Value = "$($result[1, $a])"
        $OutputTable.Rows.Add($row)	
    }
    return $OutputTable
}

$A = Get-Item -Path HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities | Select-Object Property
$Community = $A | Select-Object Property -ExpandProperty Property

$Manufacturer = ((Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer).ToUpper()
$OIDS = ""

if($Manufacturer -in ("HP","HEWLETT-PACKARD")){
write-host "HP"
$OIDS = @"
Monitor Name,Enabled,Type,OID,Comparor,DataIn
Drive Array System Status,TRUE,GET,1.3.6.1.4.1.232.3.1.3,1,2
System CPU Fan Status,TRUE,GET,1.3.6.1.4.1.232.6.2.6.5,7,\"1,2\"
System Power Supply Status,TRUE,SUB,1.3.6.1.4.1.232.6.2.9.3.1.5,1,1
System Temperature Status,TRUE,GET,1.3.6.1.4.1.232.6.2.6.3,7,\"1,2\"
System Memory Status,TRUE,GET,1.3.6.1.4.1.232.6.2.14.4,1,2
Overall System Status,TRUE,GET,1.3.6.1.4.1.232.6.1.3,1,2
"@
$OIDSAdv = @"
Monitor Name,Enabled,Type,OID,Comparor,DataIn
Drive Array Logical Drive Status,FALSE,SUB,1.3.6.1.4.1.232.3.2.5.1.1.6,1,2
Drive Array Smart Status,FALSE,SUB,1.3.6.1.4.1.232.3.2.5.1.1.57,1,2
Drive Array Accelerator Status,FALSE,SUB,1.3.6.1.4.1.232.3.2.2.2.1.2,1,3
Drive Array Control Board Status,FALSE,GET,1.3.6.1.4.1.232.3.2.2.1.1.10,1,2
Drive Array Accelerator Temp,FALSE,SUB,1.3.6.1.4.1.232.3.2.2.1.1.32,6,0
"@
}
if($Manufacturer -in ("DELL","DELL INC.")){
write-host "DELL"
$OIDS = @"
Monitor Name,Enabled,Type,OID,Comparor,DataIn
Drive Array System Status,TRUE,GET,1.3.6.1.4.1.674.10893.1.20.2,1,3
System Power Supply Status,TRUE,SUB,1.3.6.1.4.1.674.10892.1.600.12.1.5.1,1,3
System Temperature Status,TRUE,GET,1.3.6.1.4.1.674.10892.1.200.10.1.24,1,3
System Memory Status,TRUE,GET,1.3.6.1.4.1.674.10892.1.400.20.1.4,1,3
Overall System Status,TRUE,GET,1.3.6.1.4.1.674.10892.1.200.10.1.2,1,3
"@
$OIDSAdv = @"
Monitor Name,Enabled,Type,OID,Comparor,DataIn
Drive Array Logical Drive Status,FALSE,SUB,1.3.6.1.4.1.674.10893.1.20.130.4.1.24,1,3
Drive Array Smart Status,FALSE,SUB,1.3.6.1.4.1.674.10893.1.20.130.4.1.31,1,1
Drive Array Component Status,FALSE,SUB,1.3.6.1.4.1.674.10893.1.20.130.1.1.38,1,3
"@
}

$OutputTable = New-Object system.Data.DataTable “TestTable”
$col0 = New-Object system.Data.DataColumn Name,([string])
$col1 = New-Object system.Data.DataColumn Oid,([string])
$col2 = New-Object system.Data.DataColumn Value,([string])
$col3 = New-Object system.Data.DataColumn Status,([string])
#$col4 = New-Object system.Data.DataColumn URL,([string])
$OutputTable.columns.add($col0)
$OutputTable.columns.add($col1)
$OutputTable.columns.add($col2)
$OutputTable.columns.add($col3)
#$OutputTable.columns.add($col4)

foreach($OID in $OIDS | convertFrom-csv){
    #write-host $($OID."Monitor Name")
    $Results = Get-SnmpWalk -Hostname "127.0.0.1" -Oid $($OID.OID) -Community $Community
    foreach($Result in $Results){
        $row = $OutputTable.NewRow()
        $row.Name = $($OID."Monitor Name")
	    $row.Oid = $Result.Oid
	    $row.Value = $Result.value
        $Status = "ABC"

        if($Manufacturer -in ("HP","HEWLETT-PACKARD")){
            switch ($Result.value)
            {
                1 {$Status = "OTHER"}
                2 {$Status = "OK"}
                3 {$Status = "DEGRADED"}
                4 {$Status = "FAILED"}
            }
        }
        if($Manufacturer -in ("DELL","DELL INC.")){
            switch ($Result.value)
            {
                1 {$Status = "CRITICAL"}
                2 {$Status = "WARNING"}
                3 {$Status = "NORMAL"}
                4 {$Status = "UNKNOWN"}
            }
        }
        $row.Status = $Status
        #$row.URL = "http://oidref.com/$($OID.OID)"

        $OutputTable.Rows.Add($row)	
    }
}

$row = $OutputTable.NewRow()
$row.Name = "-"
$row.Oid = "-"
$row.Value = "-"
$row.Status = "-"
#$row.URL = "-"
$OutputTable.Rows.Add($row)

foreach($OID in $OIDSAdv | convertFrom-csv){
    #write-host $($OID."Monitor Name")
    $Results = Get-SnmpWalk -Hostname "127.0.0.1" -Oid $($OID.OID) -Community $Community
    foreach($Result in $Results){
        $row = $OutputTable.NewRow()
        $row.Name = $($OID."Monitor Name")
	    $row.Oid = $Result.Oid
	    $row.Value = $Result.value
        $Status = "NO VAL"

        if($Manufacturer -in ("HP","HEWLETT-PACKARD")){
            switch ($Result.value)
            {
                1 {$Status = "OTHER"}
                2 {$Status = "OK"}
                3 {$Status = "DEGRADED"}
                4 {$Status = "FAILED"}
            }
        }
        if($Manufacturer -in ("DELL","DELL INC.")){
            switch ($Result.value)
            {
                1 {$Status = "CRITICAL"}
                2 {$Status = "WARNING"}
                3 {$Status = "NORMAL"}
                4 {$Status = "UNKNOWN"}
            }
        }
        $row.Status = $Status
        #$row.URL = "http://oidref.com/$($OID.OID)"

        $OutputTable.Rows.Add($row)	
    }
}

$OutputTable