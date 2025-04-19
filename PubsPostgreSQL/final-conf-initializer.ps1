# Set-Alias Flyway  'C:\ProgramData\chocolatey\lib\flyway.commandline\tools\flyway-7.8.1\flyway.cmd' -Scope local
$ProjectFolder = 'D:\Spare\PubsAndFlyway\PubsPostgreSQL' #your project folder
$Server = 'localhost' #the name or instance of SQL Server
$Database = 'pubs'; #The name of the development database that you are using
$UserID = 'postgres' # your userid 
$port = '5432' # the port that the service is on
$RDBMS = 'PostgreSQL' # needed in case you need to keep separate credentials for different RDBMS on the same server 
# We get all the arguments as a string array. 
$MyArgs = if (!([string]::IsNullOrEmpty($UserID))) #then it is using SQL Server Credentials
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
        @("-url=jdbc:postgresql://$($Server):$port/$Database", 
        "-locations=filesystem:$ProjectFolder\Scripts", <# the migration folder #>
        "-schemas=dbo,people",
        "-user=$($SqlCredentials.UserName)",
        "-password=$($SqlCredentials.GetNetworkCredential().password)")
    }
    else
    { $null }
}
else
{ @("-url=jdbc:sqlserver://$($Server):$port;databaseName=$Database;integratedSecurity=true".
      "-locations=filesystem:$ProjectFolder\Scripts",
      "-schemas=dbo,people") <# the schemas the database has #>
}

# Start your command here
# flyway $MyArgs clean
# flyway $MyArgs info
flyway $MyArgs migrate

# flyway ($MyArgs + @("-target=2.1.1.2")) migrate
# flyway $MyArgs info
# flyway ($MyArgs + @("-baselineVersion=1.0")) baseline