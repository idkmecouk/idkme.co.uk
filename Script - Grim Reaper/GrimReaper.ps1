param (
  [parameter(Mandatory=$false)][string]$ProfilesRoot = $(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -Name "ProfilesDirectory" | Select ProfilesDirectory -ExpandProperty ProfilesDirectory),
  [parameter(Mandatory=$false)][int]$Days = -365
)

$ExcludeUsers=@("Administrator",".NET v4.5",".NET v4.5 Classic") #array to exclude users.


if([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")){ #Checks we are running this as an ADMIN.
    Write-Host "Admin! YEY"
}else{
    Write-Host "Run Me As ADMIN!!!!"
    exit 1
}

$DC = ($ENV:LOGONSERVER).replace("\\","") #Uses the logon server as the DC to get user info from.
Write-host "Domain Contoler:"$DC
if(Test-WSMan -ComputerName $DC -ErrorAction Ignore){ #Tests connection to DC.
    Write-Host "Can Successfully To DC!"
}else{
    Write-Host "Can't Talk To $DC!"
    exit 1
}

$CurrentUser = "$($env:UserDomain)\$($env:UserName)" #Gets current user so we can use this to grant perms later on.
$ProfilesList=$(Get-ChildItem $ProfilesRoot) #Gets all folders in profiles root.

#table setup to show table view output.
$table = New-Object system.Data.DataTable “TestTable”
$col1 = New-Object system.Data.DataColumn Profile,([string])
$col2 = New-Object system.Data.DataColumn Enabled,([string])
$col3 = New-Object system.Data.DataColumn LastLogonDate,([string])
$col4 = New-Object system.Data.DataColumn CustomPermissionsDetected,([string])
$col5 = New-Object system.Data.DataColumn SID,([string])
$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)

#$ADUsers=$(Get-ADUser -Filter * -Properties Enabled,LastLogonDate)
$ADUser=$(Invoke-Command -ComputerName $DC -ScriptBlock {Get-ADUser -Filter * -Properties Enabled,LastLogonDate,SID}) #For small ammounts of users it's faster to get them all now.

write-host "Users not logged in in last $Days"
foreach($Profile in $ProfilesList){ #Foreach folder in profiles root.
    if(!($ExcludeUsers -contains $Profile)){ #Skip the excluded users.
        $ProfileName=""
        $ProfileName = $Profile.Name
        #$UserInfo=$(Invoke-Command -ComputerName $DC -ArgumentList $ProfileName -ScriptBlock {Try{Get-ADUser -Identity $args[0] -Properties Enabled,LastLogonDate | select Name,Enabled,LastLogonDate}catch{}}) #get AD info for user.
        $UserInfo=($ADUser | Where-Object {$_.SamAccountName -eq $ProfileName}) #tries to find AD user matching same name as folder.
        <#if($UserInfo){
            Write-host $Profile $UserInfo.Enabled
        }#>
        
		#logic to test if user was found in AD.
        $FOUND = $TRUE
        Try{
            Get-Variable $UserInfo.Enabled | Out-Null
        }Catch{
            $FOUND = $FALSE
        }

        if($FOUND -and !$UserInfo.Enabled){ #if user was found and they are NOT enabled...
            if($UserInfo.LastLogonDate -le (get-date).AddDays($Days)){ #was users last login date less than x days from today.

                $PermCount=$TRUE
                if(((Get-Acl $Profile.FullName).access | Measure-Object | Select Count -ExpandProperty Count) -eq 3){ #Usually when perms are default there is only 3. Seems to work.
                    $PermCount=$FALSE
                }

                $row = $table.NewRow() #Adds data to table.
                $row.Profile = $Profile.FullName
                $row.Enabled = $UserInfo.Enabled
                $row.CustomPermissionsDetected = $PermCount
                $row.LastLogonDate = $UserInfo.LastLogonDate
                $row.SID = $UserInfo.SID
                $table.Rows.Add($row)  
            }
        }
    }
}

$table | format-table -AutoSize #shows the table.

$confirmation = Read-Host "Do you want to delete the accounts above? (y/n):"
if ($confirmation -eq 'y') {
  $confirmation1 = Read-Host "Are you sure? (y/n):"
    if ($confirmation1 -eq 'y') {
      foreach($Item in $table){ #foreach row in table...
        $Profile=$Item.Profile
		write-host "Goodbye $($Item.Profile)"
        #$confirmation2 = Read-Host "Remove $Profile (y/n):"
        #if ($confirmation2 -eq 'y') {
            #Remove-Item -Recurse -Force $Profile
            #Write-Host $Item.Profile
			
			#takes ownership of profile so can delete it.
            Start-Process "cmd.exe" "/c Takeown /r /f ""$Profile"" /a /D Y" -Wait
            Start-Process "cmd.exe" "/c icacls ""$Profile"" /grant ""$($CurrentUser):(F)""" -Wait
            Start-Process "cmd.exe" "/c del /F/Q/S ""$Profile""" -Wait
            Start-Process "cmd.exe" "/c RMDIR /Q/S ""$Profile""" -Wait
			#removes users SID from registry.
            Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$Profile.SID" -Recurse -ErrorAction SilentlyContinue
            #del /F/Q/S "$Profile"
            #RMDIR /Q/S "$Profile"
			if(Test-Path $Profile){ #checks users profile was deleted.
				write-host "ERROR - $Profile STILL EXISTS!"
				break
			}
        #}
      }
    }
}else{
	$table | export-csv "UsersToBePurged.csv" -NoClobber #exports to csv list of users wants to delete.
}