# SCRIPT INFO:
<#
Purpose:
            Connect to a given site and get the following info.
            - Site name
            - Site Url
            - Unique permissions
            - Associated groups
            - Permission settings
#>


# FUNCTIONS
#region
# foLoop through all the lists and check if the list has unique permissions  
Function GetUniquePermissions($web)  
{  
    $listColl=Get-PnPList -Web $web -Includes HasUniqueRoleAssignments
    write-host -ForegroundColor Yellow "Unique permissions:"      
    foreach($list in $listColl)  
    {    
        if($list.HasUniqueRoleAssignments)  
        {
            write-host $list.Title
        }#endif        
    }#endforeach
    write-host `r      
}#endfunction  
  

function Write-Color([String[]]$Text, [ConsoleColor[]]$Color) 
{
    for ($i = 0; $i -lt $Text.Length; $i++)
    {
        Write-Host $Text[$i] -Foreground $Color[$i] -NoNewLine
    }#endfor
    Write-Host
}#endfunction


function getDefaultAssociatedGroups()
{
    $defaultGroups = @()
    $defOwner = get-pnpgroup -AssociatedOwnerGroup | Select-Object title
    $defMember = Get-PnPGroup -AssociatedMemberGroup | Select-Object title
    $defVisitor = Get-PnPGroup -AssociatedVisitorGroup | Select-Object title

    $item = New-Object psobject
    $item | Add-Member -type NoteProperty -Name "Associated Owner" -value $defOwner.title
    $item | Add-Member -type NoteProperty -Name "Associated Member" -value $defMember.title
    $item | Add-Member -type NoteProperty -Name "Associated Visitor" -value $defVisitor.title
    $defaultGroups += $item

    write-host "Default associated groups:" -ForegroundColor Yellow
    $defaultGroups | Format-Table | Write-Output
}#endfunction


function getRole($groupID)
{
$roleInfo = Get-PnPGroupPermissions -Identity $groupID |Select-Object Name
if($roleInfo.count -gt 1)
    {
    foreach($r in $roleinfo)
        {
        $role = $role + $r.name + ", "
        }#endforeach
    $role = $role.remove($role.lastindexof(", "), 2)
    }
    else
    {
    $role = $roleInfo.name
    }#endif   
return $role   
}#endfunction


function getPermissionSettings()
{

# get permissions groups Id, Title, Ownership
$ctx = Get-PnPContext
$ctx.Load($ctx.Web.RoleAssignments.Groups)
Invoke-PnPQuery -ErrorAction Stop
$groupPermissions = $ctx.Web.RoleAssignments.Groups | Select-Object id, title, ownertitle

# create ArrayList which will include Role columns
[System.Collections.ArrayList]$alPermissions = @()

Clear-Variable item -ErrorAction SilentlyContinue

for($i=0;$i -lt $groupPermissions.count;$i++)
    {
    # put the role info to a string variable
    $roleString = getRole($groupPermissions[$i].id)

    $item = New-Object PSObject
    $item | Add-Member -type NoteProperty -Name 'Id' -Value $groupPermissions[$i].id
    $item | Add-Member -type NoteProperty -Name 'Title' -Value $groupPermissions[$i].title
    $item | Add-Member -type NoteProperty -Name 'OwnerTitle' -Value $groupPermissions[$i].ownertitle
    $item | Add-Member -type NoteProperty -Name 'Role' -Value $roleString
    $alPermissions += $item
    } #endfor

Write-Host "Permissions settings:" -ForegroundColor Yellow
$alPermissions | Write-Output

}
# ------------------------------------------------ #
#endregion



#---------------
# START PROCESS

# Ask & connect to the site
Clear-Host
$siteURL = Read-Host -Prompt "Enter website URL (e.g. https://wse07.siemens.com/content/P0007504). Enter '1' to use the current connection"

if($siteURL -eq "Exit")
{
    Write-Host "Script exited..." -ForegroundColor Green 
    Exit
}
elseif($siteURL.Length -gt 250){
    write-host "ERROR: URL too long" -ForegroundColor Red
    exit
}
ElseIf((($siteURL -notlike 'https://*') -or ($siteURL -notlike '*siemens.com*')) -and ($siteURL -ne 1)){
    write-host "ERROR: Bad URL ->" $siteURL -ForegroundColor Red
    exit
}#endif

if($siteURL -eq 1)
{
    try
    {
        Get-PnPConnection | Out-Null
    }
    catch
    {
        Write-Output $_.Exception.Message
        exit
    }
}
else
{
    Connect-PnPOnline $siteURL -UseWebLogin
}

$rootWeb=Get-PnPWeb      

Write-host "Site name:" -ForegroundColor Yellow
write-host $rootWeb.Title"`r`n"
write-host "Site URL:" -ForegroundColor Yellow
write-host $rootWeb.Url"`r`n"

# Call the functions to get unique rights  
GetUniquePermissions($rootWeb)

# get default associated groups
getDefaultAssociatedGroups

# get groups permissions settings
getPermissionSettings | Format-Table

