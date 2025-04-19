$ProjectFolder = 'D:\Spare\PubsAndFlyway\PubsPostgreSQL' #your project folder
$Server = 'localhost' #the name or instance of SQL Server
$Database = 'pubs'; #The name of the development database that you are using
$Password = 'Spursol@1234567' #your password 
$UserID = 'postgres' # your userid 
$port = '5432' # the port that the service is on
cd $ProjectFolder #make this PowerShell's current working directory
# write the config file. This is a once-off if this is based in your user directory
#as credentials will be protected by NTFS security. Later on, we'll have a better way
# but then there's more code. 
$config = "$(if ($UserID -eq '' -or $Password -eq '')
    {
        "flyway.url=jdbc:postgresql://$($Server):$port/$Database 
flyway.locations=filesystem:$ProjectFolder\Scripts
flyway.schemas=dbo,people"
    }
    else
    {
        "flyway.url=jdbc:postgresql://$($Server):$port/$Database 
flyway.user=$UserID
flyway.password=$Password
flyway.schemas=dbo,people
flyway.locations=filesystem:$ProjectFolder\Scripts"
    })"
<# you can write out the config file at runtime like this, as a UTF8 file #>
[IO.File]::WriteAllLines("$ProjectFolder\flyway.conf", $config)