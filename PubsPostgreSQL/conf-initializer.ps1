$ProjectFolder = 'D:\Spare\PubsAndFlyway\PubsPostgreSQL' #your project folder
$Server = 'localhost' #the name or instance of SQL Server
$Database = 'pubs'; #The name of the development database that you are using
$UserID = 'postgres' # your userid 
$port = '5432' # the port that the service is on
$RDBMS = 'PostgreSQL' # needed in case you need to keep separate credentials for different RDBMS on the same server 
$Credentials = if (!([string]::IsNullOrEmpty($UserID))) #then it is using Credentials
{
    # we see if we've got these stored already
    $SqlEncryptedPasswordFile = "$env:USERPROFILE\$($UserID)-$($Server)-$($RDBMS).xml"
    # test to see if we know about the password in a secure string stored in the user area
    if (Test-Path -path $SqlEncryptedPasswordFile -PathType leaf)
    {
        #has already got this set for this login so fetch it
        $SqlCredentials = Import-CliXml $SqlEncryptedPasswordFile
    }
    else #then we have to ask the user for it (once only)
    {
        # hasn't got this set for this login
        $aborted = $false #in case the user doesn't want to enter the password
        $SqlCredentials = get-credential -Credential $UserID
        # Save in the user area 
        if ($SqlCredentials -ne $null) #in case the user aborted
        {
            $SqlCredentials | Export-CliXml -Path $SqlEncryptedPasswordFile
        <# Export-Clixml only exports encrypted credentials on Windows.
        otherwise it just offers some obfuscation but does not provide encryption. #>
        }
        else { $aborted = $True }
    }
    if (!($Aborted))
    {
        @("-user=$($SqlCredentials.UserName)",
          "-password=$($SqlCredentials.GetNetworkCredential().password)")
    }
    else
    { $null }
}
else
{ $Null }
 
cd $ProjectFolder #make this powerShell's current working directory
# write the config file. This is a once-off if this is based in your user directory
#as credentials will be protected by NTFS security. Later on, we'll have a better way
# but then there's more code. 
$config = "flyway.url=jdbc:postgresql://$($Server):$port/$Database 
flyway.schemas=dbo,people
flyway.locations=filesystem:$ProjectFolder\Scripts"
<# you can write out the config file at runtime like this, as a UTF8 file #>
[IO.File]::WriteAllLines("$ProjectFolder\flyway.conf", $config)