<#
        .SYNOPSIS
        This will protect all the secrets.
            
        .DESCRIPTION
        This will keep everything we want to keep secret as long as the current windows user account is not compromised.
		Due to how powershell secure strings work the only user who can decrypt whatever has been encrypted is theuser 
		who execupted this script to encrypt the details in the first place. If the password for that user chnages everything
		that was encrypted becomes invalid and must be re-encrypted.
            
        .PARAMETER WebrootUsername
        A user we can use to get tokens.
        Example: admin@example.com
		Console->Admins
            
        .PARAMETER WebrootPassword
        The plain text password for that user. Regardless of 2FA status.
		Example: secretpassword1234
		Console->Admins
		
        .PARAMETER Api_ClientID
        The ClientID created when getting an API key from GSM console.
		Example: client_jgudvrhY@example.com
		Console->Settings->Api Access
		
        .PARAMETER Api_Secret
        The Secret created when getting an API key from GSM console.
		Example: "QouPDR5*jUx&UAk"
		Console->Settings->Api Access
		
        .PARAMETER GSM_KeyCode
        Your GSM KeyCode
		Example: "AAAA-BBBB-CCCC-DDDD-EEEE"
		Console->Settings->Account Infomation
		
		.EXAMPLE
        .\SecretsSetup.ps1 -WebrootUsername "admin@example.com" -WebrootPassword "secretpassword1234" -Api_ClientID "client_jgudvrhY@example.com" -Api_Secret "QouPDR5*jUx&UAk" -GSM_KeyCode "AAAA-BBBB-CCCC-DDDD-EEEE"
		
		.EXAMPLE
        $Creds = @{
            WebrootUsername = "admin@example.com"
            WebrootPassword = "secretpassword1234"
            Api_ClientID = "client_jgudvrhY@example.com"
            Api_Secret = "QouPDR5*jUx&UAk"
            GSM_KeyCode = "AAAA-BBBB-CCCC-DDDD-EEEE"
        }
        .\SecretsSetup.ps1 @Creds
		
		.NOTES
        Author: **
        Date: 28/09/20
#>

Param(
    [parameter(Mandatory=$true)]
    [string]
    $WebrootUsername,
	[parameter(Mandatory=$true)]
    [string]
    $WebrootPassword,
	[parameter(Mandatory=$true)]
    [string]
    $Api_ClientID,
	[parameter(Mandatory=$true)]
    [string]
    $Api_Secret,
	[parameter(Mandatory=$true)]
    [string]
    $GSM_KeyCode
)

$Secrets = @{
	WebrootUsername = $WebrootUsername | ConvertTo-SecureString -AsPlainText -Force
	WebrootPassword = $WebrootPassword | ConvertTo-SecureString -AsPlainText -Force
	Api_ClientID = $Api_ClientID | ConvertTo-SecureString -AsPlainText -Force
    Api_Secret = $Api_Secret | ConvertTo-SecureString -AsPlainText -Force
	GSM_KeyCode = $GSM_KeyCode | ConvertTo-SecureString -AsPlainText -Force
}

#$SuperSecrets = $Secrets | ConvertTo-SecureString -AsPlainText -Force
#$Secrets = "Gone"
$Secrets | Export-Clixml "SuperSecrets.xml" -Force

