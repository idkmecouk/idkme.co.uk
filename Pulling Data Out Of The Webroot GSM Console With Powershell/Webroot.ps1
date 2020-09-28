<#
        .SYNOPSIS
        This will pull data from the Webroot GSM console.
            
        .DESCRIPTION
        The script will pull company, licence counts and status info out of the GSM console.
		
		.NOTES
        Author: **
        Date: 28/09/20
		
		In order to set the CWCompID field please enter the ConnectWise RecID foreach company 
		in the following format in the site comments section. YOu can keep any existing info in 
		the comments as long as the this is in the correct format.
		|cwm-id=123456|
		or
		random comment|cwm-id=123456|more random comment
#>

if(!(Test-Path "SuperSecrets.xml")){ #Check the secrets have been setup...
	write-host "Please use SecretsSetup.ps1 to set me up."
	exit 1
}
try{ #Check we can import them.
	$SuperSecrets = Import-Clixml "SuperSecrets.xml"
}Catch{
    $ErrorMessage = $_.Exception.Message
	write-host "Error Importing Secrets! Please use the SecretsSetup.ps1 again."
	write-host ""
	write-host $ErrorMessage
	exit 1
}

try{ #Try to decrypt all our secrets.
	$Secrets = @{
		WebrootUsername = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SuperSecrets.WebrootUsername)))
		WebrootPassword = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SuperSecrets.WebrootPassword)))
		Api_ClientID = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SuperSecrets.Api_ClientID)))
		Api_Secret = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SuperSecrets.Api_Secret)))
		GSM_KeyCode = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SuperSecrets.GSM_KeyCode)))
	}
}Catch{
    $ErrorMessage = $_.Exception.Message
	write-host "Error decrypting secrets! Please use the SecretsSetup.ps1 again."
	write-host ""
	write-host $ErrorMessage
	exit 1
}

$BaseURL = "https://unityapi.webrootcloudav.com"

function CheckResponce(){ #This is just a place holder incase i need to add rate limiting etc...
	Param(
    [parameter(Mandatory=$true)]
    $Responce
	)
	if($Responce.StatusCode -ne 200){
		write-host "Got non 200 status code ($($Responce.StatusCode))"
	}else{
		return $Responce
	}
}

function GetAccessToken(){
	Param(
    [parameter(Mandatory=$true)]
    [string]
    $Username,
	[parameter(Mandatory=$true)]
    [string]
    $Password,
	[parameter(Mandatory=$true)]
    [string]
    $Api_ClientID,
	[parameter(Mandatory=$true)]
    [string]
    $Api_Secret
	)
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$AuthHeader = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$Api_ClientID"+":"+"$Api_Secret"))
	$headers.Add("Authorization", "Basic $AuthHeader")
	$headers.Add("Content-Type", "application/x-www-form-urlencoded")
	$Password = [System.Web.HttpUtility]::UrlEncode($Password)
	$body = "username=$Username&password=$Password&grant_type=password&scope=*"
	$response = Invoke-WebRequest "$BaseURL/auth/token" -Method 'POST' -Headers $headers -Body $body
	return CheckResponce -Responce $response
}

function RefreshAccessToken(){
	Param(
	[parameter(Mandatory=$true)]
    [string]
    $Api_ClientID,
	[parameter(Mandatory=$true)]
    [string]
    $Api_Secret,
	[parameter(Mandatory=$true)]
    [string]
    $RefreshToken
	)
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$AuthHeader = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$Api_ClientID"+":"+"$Api_Secret"))
	$headers.Add("Authorization", "Basic $AuthHeader")
	$headers.Add("Content-Type", "application/x-www-form-urlencoded")
	$body = "grant_type=refresh_token&scope=*&refresh_token=$RefreshToken"
	$response = Invoke-WebRequest "$BaseURL/auth/token" -Method 'POST' -Headers $headers -Body $body -ErrorAction SilentlyContinue
	return CheckResponce -Responce $response
}

function CreateNewCreds(){
	Param(
	[parameter(Mandatory=$false)]
    $response
	)
	if($response){
		$AccessTokenArray = $response.Content | ConvertFrom-Json
	}else{
		$AccessTokenArray = (GetAccessToken -Username $Secrets.WebrootUsername -Password $Secrets.WebrootPassword -Api_ClientID $Secrets.Api_ClientID -Api_Secret $Secrets.Api_Secret).Content | ConvertFrom-Json
	}
	$AccessToken = $AccessTokenArray.access_token
	$RefreshToken = $AccessTokenArray.refresh_token
	$AccessTokenExpTime = (Get-Date).AddSeconds($AccessTokenArray.expires_in)
	$RefreshTokenExpTime = (Get-Date).AddDays(14)

	$CredObject = @{
		AccessToken = $AccessToken | ConvertTo-SecureString -AsPlainText -Force
		RefreshToken = $RefreshToken | ConvertTo-SecureString -AsPlainText -Force
		AccessTokenExpTime = $AccessTokenExpTime
		RefreshTokenExpTime = $RefreshTokenExpTime
	}

	$CredObject | Export-Clixml "CredObject.xml" -Force
}

function GetWebrootSites(){
	Param(
	[parameter(Mandatory=$true)]
    $GSMKey,
	[parameter(Mandatory=$true)]
    [string]
    $RefreshToken
	)
	
	#write-host $RefreshToken
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add("Authorization", "Bearer $RefreshToken")
	$response = Invoke-WebRequest "$BaseURL/service/api/console/gsm/$GSMKey/sites" -Method 'GET' -Headers $headers
	return CheckResponce -Responce $response
}

function CheckForCWCompID(){
	Param(
	[parameter(Mandatory=$true)]
    $GSMComment
	)
	#write-host "Comment|$GSMComment|"
	$Needel = "cwm-id="
	if($GSMComment -match $Needel){
		$GSMComment = $GSMComment.SubString($GSMComment.IndexOf($Needel)+$Needel.Length)
		$GSMComment = $GSMComment.SubString(0,$GSMComment.IndexOf("|"))
	}else{
		return 0 #covers us incase we have just random numbers in the comment field.
	}
	
	if($GSMComment -match '^[0-9]+$'){ #check that our company id is actuall a number..
		return $GSMComment
	}else{
		return 0
	}
}

function Main(){
	if(Test-Path "CredObject.xml"){
		#We may have valid creds already?
		$CredObject = Import-Clixml "CredObject.xml"
		
		#Check refresh token.
		if((New-TimeSpan -Start (Get-Date) -End $CredObject.RefreshTokenExpTime).TotalMinutes -lt 2){
			#write-host "Need new Refresh Token!"
			CreateNewCreds
			$CredObject = Import-Clixml "CredObject.xml"
		}else{
			#Check our token..
			if((New-TimeSpan -Start (Get-Date) -End $CredObject.AccessTokenExpTime).TotalMinutes -lt 2){
				$A = RefreshAccessToken -Api_ClientID $Secrets.Api_ClientID -Api_Secret $Secrets.Api_Secret -RefreshToken ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredObject.RefreshToken)))
				CreateNewCreds -response $A
				#$A.Content  | ConvertFrom-Json
				$CredObject = Import-Clixml "CredObject.xml"
			}
		}
		#$CredObject.RefreshToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredObject.RefreshToken))
		$CredObject.AccessToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredObject.AccessToken))
		
		$response = GetWebrootSites -GSMKey $Secrets.GSM_KeyCode -RefreshToken $($CredObject.AccessToken)
		$CustomerArray = ($response.Content | ConvertFrom-Json).Sites
		
		$table = New-Object system.Data.DataTable “TestTable”
		$col1 = New-Object system.Data.DataColumn CustomerName,([string])
		$col2 = New-Object system.Data.DataColumn TotalDevices,([int])
		$col3 = New-Object system.Data.DataColumn TotalLicenses,([int])
		$col4 = New-Object system.Data.DataColumn Status,([bool])
		$col5 = New-Object system.Data.DataColumn CWCompID,([string])
		
		$table.columns.add($col1)
		$table.columns.add($col2)
		$table.columns.add($col3)
		$table.columns.add($col4)
		$table.columns.add($col5)
		
		
		foreach($Customer in $CustomerArray){
			$row = $table.NewRow()
			$row.CustomerName = $Customer.SiteName
			$row.TotalDevices = $Customer.TotalEndpoints
			$row.TotalLicenses = $Customer.DevicesAllowed
			if($Customer.Deactivated -eq "False" -and $Customer.Suspended -eq "False"){
				$row.Status = $false
			}else{
				$row.Status = $true
			}
			$row.CWCompID = CheckForCWCompID -GSMComment ($Customer.CompanyComments)
			$table.Rows.Add($row) 	
		}
		#$table | sort-object CustomerName | ft
		return $table
		
	}else{
		CreateNewCreds
		Main
	}
}

Main
