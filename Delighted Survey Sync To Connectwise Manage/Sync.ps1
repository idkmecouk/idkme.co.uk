[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
$DelightedApiKey = ""
$CWServer = "https://eu.myconnectwise.net/v2020_2/apis/3.0"
$CWClientId = ""
$CWCompany = ""
$pubkey = ""
$privatekey = ""
 
$CWAuthHeader = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$CWCompany+$pubkey"+":"+"$privatekey"))
$DelightedAuthHeader = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$DelightedApiKey"+":"))
 
 
Start-Transcript -Path "Transcript.log"
 
 
function GetDelightSurvey(){ #Returns an array of surveys entered since $updated_at
 Param(
    [parameter(Mandatory=$false)]
    [String]
    $updated_at 
    )
 
 $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
 $headers.Add("Authorization", "Basic $DelightedAuthHeader")
 if($updated_at){
 $response = Invoke-RestMethod "https://api.delighted.com/v1/survey_responses.json?updated_since=$updated_at" -Method 'GET' -Headers $headers -Body $body
 }else{
 $response = Invoke-RestMethod 'https://api.delighted.com/v1/survey_responses.json' -Method 'GET' -Headers $headers -Body $body
 }
 #$response | ConvertTo-Json | ConvertFrom-Json
 return $response
}
 
function AlreadySurveyed(){ #returns an array to check if $TicketNum has already had a survey
 Param(
    [parameter(Mandatory=$true)]
    [String]
    $TicketNum 
    )
 
 $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
 $headers.Add("clientId", $CWClientId)
 $headers.Add("Authorization", "Basic $CWAuthHeader")
 $response = Invoke-RestMethod "$CWServer/service/tickets/$TicketNum" -Method 'GET' -Headers $headers -Body $body
 #$response = $response | ConvertTo-Json | ConvertFrom-Json
 
 $CSAT_Rating = ($response.customFields | where-object{$_.caption -eq "CSAT Rating"}).value
 $OwnerID = $response.owner.id
 #$OwnerID = 155
 if($OwnerID){
 $response2 = Invoke-RestMethod "$CWServer/system/members/$OwnerID" -Method 'GET' -Headers $headers -Body $body
 }
 
 #$CSAT_Comment = ($response.customFields | where-object{$_.caption -eq "CSAT Comment"}).value
 
 if($CSAT_Rating){
 return @{'AlreadySurveyed' = $true;'CSAT_Rating' = $CSAT_Rating;'OwnerEmail' = $response2.officeEmail;'Subject' = $response.summary;'CompanyName' = $response.company.name} #already has rating
 }else{
 return @{'AlreadySurveyed' = $false;'CSAT_Rating' = $CSAT_Rating;'OwnerEmail' = $response2.officeEmail;'Subject' = $response.summary;'CompanyName' = $response.company.name} #No rating
 }
}
 
function AddCSAT(){ #Adds a CSAT to $TicketNum
 Param(
    [parameter(Mandatory=$true)]
    [int]
    $TicketNum,
 [parameter(Mandatory=$true)]
    [int]
    $CSAT_Rating,[parameter(Mandatory=$true)]
    [String]
    $CSAT_Comment = ""
    )
 
 $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
 $headers.Add("clientId", $CWClientId)
 $headers.Add("Authorization", "Basic $CWAuthHeader")
 $headers.Add("Content-Type", "application/json")
 $body = "[{`"op`": `"replace`",`"path`": `"customFields`",`"value`": [{`"id`":5,`"value`":`"$CSAT_Rating`"},{`"id`":6,`"value`":`"$CSAT_Comment`"}]}]"
 $response = Invoke-RestMethod "$CWServer/service/tickets/$TicketNum" -Method 'PATCH' -Headers $headers -Body $body
}
 
function Main(){
 if(Test-Path "last_run.txt"){ #if we have a last_run then use that as the base for getting surveys.
 $LastRun = get-content "last_run.txt"
 $SurveyArray = GetDelightSurvey -updated_at $LastRun
 }else{
 $SurveyArray = GetDelightSurvey
 }
 
 
 $SurveyArray
 
 foreach($Survey in $SurveyArray){ #Foreach survey in the delighted responce...
 $SurveyScore = $Survey.score
 $SurveyComment = $Survey.comment
 if(!($SurveyComment)){
 $SurveyComment = "N/A"
 }
 
 $SurveyTicketNum = $Survey.person_properties.Ticket
 $SurveyUpdatedAt = $Survey.updated_at
 
 try{
 $SurveyTicketNum = [int]$SurveyTicketNum
 $SurveyScore = [int]$SurveyScore
 
 $AlreadySurveyed = AlreadySurveyed -TicketNum $SurveyTicketNum
 #$AlreadySurveyed.AlreadySurveyed = $false
 $CompanyName = $AlreadySurveyed.CompanyName
 
 if($AlreadySurveyed.AlreadySurveyed){
 write-host "$SurveyTicketNum already has a survey"
 if($SurveyScore -gt $AlreadySurveyed.CSAT_Rating){ #If we already have a rating but the current rating is worse than new one then update rating with the better one
 write-host "Updating with better score."
 AddCSAT -TicketNum $SurveyTicketNum -CSAT_Rating $SurveyScore -CSAT_Comment $SurveyComment
 
 }
 }else{
 AddCSAT -TicketNum $SurveyTicketNum -CSAT_Rating $SurveyScore -CSAT_Comment $SurveyComment
 }
 }catch{
 write-host "Not int:$SurveyTicketNum"
 }
 }
 
 $SurveyUpdatedAt | out-file -FilePath "last_run.txt"
}
 
Main
 
Stop-Transcript