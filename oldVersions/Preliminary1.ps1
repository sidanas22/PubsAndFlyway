﻿<# Principles:
one 'resource' directory with all the scripting tools we need for the project
each branch needs its own place for reports, source and scripts
Each branch must maintain its own copy of the database to preserve isolation
Each branch 'working directory' should be the same structure.
All data is based on the Current working directory.
Use flyway.conf where possible #>
cd 
<# first check that flyway is installed properly #>
$FlywayCommand = (Get-Command "Flyway" -ErrorAction SilentlyContinue)
if ($null -eq $FlywayCommand)
{
	write-error "This script requires Flyway to be installed and available on a PATH or via an alias" -ErrorAction Stop
}
if ($FlywayCommand.CommandType -eq 'Application' -and
	($FlywayCommand.Version -gt [version]'0.0.0.0' -and $FlywayCommand.Version -lt [version]'0.8.1.0'))
{
	write-error "Your Flyway Version is too outdated to work" -ErrorAction Stop
}
#look for the common resources directory for all assets such as modules that are shared

$dir = $pwd.Path; $ii = 10; # $ii merely prevents runaway looping.
$Branch = Split-Path -Path $pwd.Path -leaf;
while ($dir -ne '' -and -not (Test-Path "$dir\$ResourcesPath" -PathType Container
	) -and $ii -gt 0)
{
	$Project = split-path -path $dir -leaf
	$dir = Split-Path $Dir;
	$ii = $ii - 1;
}
$structure=if ($ii -eq 8) {'classic'} else {'branch'} 
if ($dir -eq '') { throw "no resources directory found" }
#Read in shared resources
dir "$Dir\$ResourcesPath\*.ps1" | foreach{ . "$($_.FullName)" }

<#
pick up any changed locations that the user wants. If nothing exists, then create the file with the default settings in place
#>
 If (!(Test-Path -Path "$pwd\DirectoryNames.json" -PathType Leaf))
    {@{
	'migrationsPath' = if ($structure -eq 'classic') {'Scripts'} else {'Migrations'}; 
        #where the migration scripts are stored-branch structure default to Migrations
	'resourcesPath' = 'resources'; #the directory that stores the project-wide resources
	'sourcePath' = 'Source'; #where the source of any branch version is stored
	'scriptsPath' = 'Scripts'; #where the various scripts of any branch version is stored #>
	'DataPath' = 'Data'; #where the data for any branch version is stored #>
	'VersionsPath' = 'Versions'; #where data for all the versions is stored #>
    'Reportdirectory'='Documents\GitHub\'<# path to the directory where data about migration is stored #>
    } |convertto-json > "$pwd\DirectoryNames.json"
    }
$FileLocations=[IO.File]::ReadAllText("$pwd\DirectoryNames.json")|convertfrom-json

$MigrationsPath= if ([string]::IsNullOrEmpty($FileLocations.MigrationsPath)) 
        {'migrations'} else {"$($FileLocations.MigrationsPath)"}
$ResourcesPath= if ([string]::IsNullOrEmpty($FileLocations.ResourcePath)) 
        {'resources'} else {"$($FileLocations.ResourcesPath)"}
$sourcePath= if ([string]::IsNullOrEmpty($FileLocations.SourcePath))
        {'source'} else {"$($FileLocations.sourcePath)"}
$ScriptsPath= if ([string]::IsNullOrEmpty($FileLocations.ScriptsPath)) 
        {'scripts'} else {"$($FileLocations.ScriptsPath)"}
$dataPath= if ([string]::IsNullOrEmpty($FileLocations.DataPath)) 
        {'data'} else {"$($FileLocations.DataPath)"}
#$ReportLocation is used for the  classic version
$VersionsPath= if ([string]::IsNullOrEmpty($FileLocations.VersionsPath)) 
        {'Versions'} else {"$($FileLocations.VersionsPath)"}
$Reportdirectory= if ([string]::IsNullOrEmpty($FileLocations.Reportdirectory)) 
        {'Documents\GitHub\'} else {"$($FileLocations.Reportdirectory)"}
#$ReportLocation is used for the branch version
$ReportLocation="$pwd\$VersionsPath"# part of path from user area to project artefacts folder location 

<# We now know the project name ($project) and the name of the branch (Branch), and have installed all the resources

Now we check that the directories and files that we need are there #>
@(@{ path = "$($pwd.Path)"; desc = 'project directory'; type = 'container' },
	@{ path = "$($pwd.Path)\$MigrationsPath"; desc = 'migration Scripts Location'; type = 'container' },
	@{ path = "$($pwd.Path)\flyway.conf"; desc = 'flyway.conf file'; type = 'leaf' }
) | foreach{
	if (-not (Test-Path $_.path -PathType $_.type))
	{ throw "Sorry, but I couldn't find a $($_.desc) at the $($pwd.Path) location" }
}

# now we get the password if necessary. To do this we need to know the server and userid
# possibly even the database name too
# The config items are case-sensitive camelcase so beware if you aren't used to this


#ForEach ($Key in $FlywayValues.Keys) 
#    {$Output.$Key = If ($dbDetails.ContainsKey($Key)) {@($Output.$Key) + $Hashtable.$Key} Else  {$Hashtable.$Key}}

#cd S:\work\Github\FlywayTeamwork\Pubs\Branches\develop


$FlywayContent = (Get-Content "flyway.conf") + (Get-content "$env:userProfile\flyway.conf") |
where { ($_ -notlike '#*') -and ("$($_)".Trim() -notlike '') } |
ConvertFrom-StringData
# use this information for our own local data
if (!([string]::IsNullOrEmpty($FlywayContent.'flyway.url')))
{
	$FlywayURLRegex =
	'jdbc:(?<RDBMS>[\w]{1,20})://(?<server>[\w\-\.]{1,40})(?<port>:[\d]{1,4}|)(;.*databaseName=|/)(?<database>[\w]{1,20})';
	$FlywaySimplerURLRegex = 'jdbc:(?<RDBMS>[\w]{1,20}):(?<database>[\w:\\]{1,80})';
	#this FLYWAY_URL contains the current database, port and server so
	# it is worth grabbing
	$ConnectionInfo = $FlywayContent.'flyway.url' #get the environment variable
	
	if ($ConnectionInfo -imatch $FlywayURLRegex) #This copes with having no port.
	{
		#we can extract all the info we need
		$RDBMS = $matches['RDBMS'];
		$port = $matches['port'];
		$database = $matches['database'];
		$server = $matches['server'];
	}
	elseif ($ConnectionInfo -imatch $FlywaySimplerURLRegex)
	{
		#no server or port
		$RDBMS = $matches['RDBMS'];
		$database = $matches['database'];
		$server = 'LocalHost';
	}
	else #whatever your default
	{
		$RDBMS = 'sqlserver';
		$server = 'LocalHost';
	}
}

# the SQL files need to have consistent encoding, preferably utf-8 unless you set config 

$DBDetails = @{
    'RDBMS'= $RDBMS; 
	'server' = $server; #The Server name
    'directoryStructure'=$structure
	'database' = $database; #The Database
	'migrationsPath' = $migrationsPath; #where the migration scripts are stored- default to Migrations
	'resourcesPath' = $resourcesPath; #the directory that stores the project-wide resources
	'sourcePath' = $sourcePath; #where the source of any branch version is stored
	'scriptsPath' = $scriptsPath; #where the various scripts of any branch version is stored #>
	'dataPath' = $DataPath; #where the data for any branch version is stored #>
    'versionsPath'=$VersionsPath;
    'reportDirectory'=$Reportdirectory;
    'reportLocation'=$ReportLocation; # part of path from user area to project artefacts folder location 
	'Port' = $port
	'uid' = $FlywayContent.'flyway.user'; #The User ID. you only need this if there is no domain authentication or secrets store #>
	'pwd' = ''; # The password. This gets filled in if you request it
	'version' = ''; # TheCurrent Version. This gets filled in if you request it
	'flywayTable' = 'dbo.flyway_schema_history';
	'branch' = $branch;
	'schemas' = 'dbo,classic,people';
	'project' = $project; #Just the simple name of the project
	'projectDescription' = $FlywayContent.'flyway.placeholders.projectDescription' #A sample project to demonstrate Flyway Teams, using the old Pubs database'
	'projectFolder' = $FlywayContent.'flyway.locations'.Replace('filesystem:',''); #parent the scripts directory
	'resources' = "$Dir\$Resources"
	'warnings' = @{ }; # Just leave this be. Filled in for your information                                                                                                                                                                                                          
	'problems' = @{ }; # Just leave this be. Filled in for your information                                                                                                                                                                                                           
	'writeLocations' = @{ }; # Just leave this be. Filled in for your information
}
$DBDetails.pwd = "$(GetorSetPassword $FlywayContent.'flyway.user' $server $RDBMS)"

$FlywayContent |
foreach{
	$what = $_;
	$variable = $_.Keys;
	$Variable = $variable -ireplace '(flyway\.placeholders\.|flyway\.)(?<variable>.*)', '${variable}'
	$value = $what."$($_.Keys)"
	$dbDetails."$variable" = $value;
	
}


#now add in any values passed as environment variables
try{
$EnvVars=@{};
@(  'env:FP__*',
    'env:Flyway_*')|
    Get-ChildItem | 
        foreach{$envVars."$($_.Key)" = $_.Value}
$envVars |
 foreach{
	if ($_.name -imatch '(FP__flyway_(?<Variable>[\w]*)__|FP__(?<Variable>[\w]*)__|FLYWAY_(?<Variable>[\w]*))')
	{
		$FlywayName = $matches['Variable'];
		if ($FlywayName -imatch 'PLACEHOLDERS_') { $FlywayName = $FlywayName -replace 'PLACEHOLDERS_' }
		if ($FlywayName -imatch '\w*_\w*' -or $FlywayName -cmatch '(?m:^)[A-Z]')
		{
			$FlywayName = $FlywayName.ToLower().Split() | foreach -Begin { $ii = $false; $res = '' }{
				$res += if ($ii) { (Get-Culture).TextInfo.ToTitleCase($_) }
				else { $_; $ii = $true };
			} -End { $res }
		}
		@{ $FlywayName = $_.Value }
		
	}
} | foreach{ $dbDetails."$($_.Keys)" = $_."$($_.Keys)" }
}
catch
    { 
    write-warning "$($PSItem.Exception.Message) getting environment variables at line $($_.InvocationInfo.ScriptLineNumber)"
    }
$defaultSchema = if ([string]::IsNullOrEmpty($DBDetails.'defaultSchema')) {'dbo'} else {"$($DBDetails.'defaultSchema')"}
$defaultTable = if ([string]::IsNullOrEmpty($DBDetails.'table')) {'flyway_schema_history'} else {"$($DBDetails.'table')"}
$DBDetails.'flywayTable'="$($defaultSchema).$($defaultTable)"
