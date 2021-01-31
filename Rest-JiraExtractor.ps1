
# Set Variables region
[String]$domain             = "CompanyJiraDomain"
[String]$inputPath          = "PathToIssueList"
[String]$workingDirectory   = "LocalWorkingDirectory"
[String]$Destination        = "RemoteDestination"
[String]$user               = 'jira_user'
[String]$pass               = 'jira_pw'

# Build out Fixed Variables
$objectArray                = @()
$pair                       = "$($user):$($pass)"
$encodedCreds               = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue             = "Basic $encodedCreds"
$IssueList                  = (Get-Content -Path $inputPath).trim()
 
# Create Workingdirectory
if (!(test-path $workingDirectory)) {
    new-item -path $workingDirectory -ItemType Directory
}

# Iterate through each Jira Issue ID in input list and retrieve JSON Data
foreach ($item in $IssueList) {
   
    $Headers = @{
        Authorization = $basicAuthValue
    }
   
    $jsonData = "https://jira.$($domain).net/rest/api/2/issue/$($item)/?fields=attachment"
    $res = Invoke-restmethod -uri $jsonData -headers $Headers -method GET 

    $userObj = @{
        userName = $res.fields.attachment.author.name
        userMail = $res.fields.attachment.author.emailAddress
        image    = $res.fields.attachment.content
        filename = $res.fields.attachment.filename
        issueKey = $res.key
    }
   
    $objectArray += $userObj

}

# Iterate through each userObject and download attachements to local directory [Migration Prep]
foreach ($data in $objectArray) {
    foreach ($d in $data) {
        $Headers = @{
            Authorization = $basicAuthValue
        }
        
        # Make folder directory per issue
        $newdir = $workingDirectory + $d.issueKey
        if (!(test-path $newdir)) {
            new-item -path $newdir -ItemType Directory
        }

        $outFile = $workingDirectory + $d.issueKey + "/" + $d.filename
        Invoke-restmethod -uri $d.image -headers $Headers -method GET -outFile $outFile 
    }
}

# Grab each issue folder and iterate through each attachement and upload content to remote location [hehehe, foreachforeachforeachforeeaaach] :D
$folders = (Get-ChildItem -Path $workingDirectory)
foreach ($folder in $folders) {
    foreach ($attachment in Get-ChildItem -path $folder.FullName) {
        foreach ($data in $objectArray) {
            foreach ($d in $data) {
                if ($d.issueKey -eq $folder) {
                    $FinalDestination = "$($destination)?=$($d.issueKey)-$($d.filename)&$($d.userName)&$($d.userEmail)&$($d.filename)"
                    Invoke-RestMethod -uri $FinalDestination -method PUT -InFile $attachment.FullName -ContentType 'image/jpeg' -UseDefaultCredentials
                }
            }
        }
    }
}

