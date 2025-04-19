$Broken = $false
Flyway clean # Drops all objects in the configured schemas
@('1.1.1', '1.1.2', '1.1.3', '1.1.4', '1.1.5') | foreach{
    if (!($Broken))
    {
    $Version = $_; 
     Flyway migrate -target="$Version" # Migrates the database to a particular version
    if (!($? -or ($LASTEXITCODE -eq 1)))
    {
    $Broken=$true
    Write-warning "The migration sequence failed at $Version"
    }
    flyway info 
   }
}