# SCRIPT INFO:
<#
---------------------------------------------------------------------------------------
- This is follow-up to draft_LibraryPermissons. Using the outputed global variable of
  unique permissions for files and folders
---------------------------------------------------------------------------------------
#>



Function GetLibraryPermission
{
    Param
    ( [string]$libName,
      $objInput  
    )

    $lib = Get-PnPList -Identity $libName -Includes RoleAssignments, HasUniqueRoleAssignments
    $ctx = Get-PnPContext
    $ctx.load($lib)
    $ctx.ExecuteQuery()

    foreach($ra in $lib.RoleAssignments)
    {
        Get-PnPProperty -ClientObject $ra -Property RoleDefinitionBindings, Member
        
        if($ra.roledefinitionBindings.Name.count -gt 1)
        {
            $role = GetRoleString($ra.roledefinitionBindings.Name)
            $hidden = GetHiddenRoleTypeString($ra.roledefinitionBindings.Hidden)
        }
        else
        {
            $role = $ra.roledefinitionBindings.Name
            $hidden = $ra.roledefinitionBindings.Hidden
        }

        $item = New-Object PSObject
        $item | Add-Member -type NoteProperty -Name 'Name' -Value $libName
        $item | Add-Member -type NoteProperty -Name 'Path' -Value $libName
        $item | Add-Member -type NoteProperty -Name 'Entity' -Value "Library"
        $item | Add-Member -type NoteProperty -Name 'Title' -Value $ra.member.title
        $item | Add-Member -type NoteProperty -Name 'Role' -Value $role
        $item | Add-Member -type NoteProperty -Name 'Hidden' -Value $hidden
        $objInput.value += $item
    }
}


Function GetFolderPermission
{
    Param
    (
        [string]$itPath,
        [string]$itName,
        [string]$itEntity,
        $objInput
    )

    $urlFld = "/"+$itPath
    $fld = Get-PnPFolder -Url $urlFld -Includes ListItemAllFields.RoleAssignments, ListItemAllFields.HasUniqueRoleAssignments
    $ctx = Get-PnPContext
    $ctx.Load($fld)
    $ctx.ExecuteQuery()

    <#
        $result.value += New-Object psobject -Property @{
            UrlName = $urlName
            Fullname = $fullName
        }   #>   
           
    # role assignment block
    foreach($ra in $fld.ListItemAllFields.RoleAssignments)
    {
        Get-PnPProperty -ClientObject $ra -Property RoleDefinitionBindings, Member
        
        if($ra.roledefinitionBindings.Name.count -gt 1)
        {
            $role = GetRoleString($ra.roledefinitionBindings.Name)
            $hidden = GetHiddenRoleTypeString($ra.roledefinitionBindings.Hidden)
        }
        else
        {
            $role = $ra.roledefinitionBindings.Name
            $hidden = $ra.roledefinitionBindings.Hidden
        }

        $item = New-Object PSObject
        $item | Add-Member -type NoteProperty -Name 'Name' -Value $itemName
        $item | Add-Member -type NoteProperty -Name 'Path' -Value $itemPath
        $item | Add-Member -type NoteProperty -Name 'Entity' -Value $urlName.Entity
        $item | Add-Member -type NoteProperty -Name 'Title' -Value $ra.member.title
        $item | Add-Member -type NoteProperty -Name 'Role' -Value $role
        $item | Add-Member -type NoteProperty -Name 'Hidden' -Value $hidden
        $objInput.value += $item
    }
}

Function GetFilePermission
{
    Param
    (
        [string]$itPath,
        [string]$itName,
        [string]$itEntity,
        $objInput
    )
    
    $file = Get-PnPFile -url $itPath -AsListItem
    Get-PnPProperty -ClientObject $file -Property HasUniqueRoleAssignments, RoleAssignments

    foreach($ra in $file.RoleAssignments)
    {
        Get-PnPProperty -ClientObject $ra -Property RoleDefinitionBindings, Member

        if($ra.roledefinitionBindings.Name.count -gt 1)
        {
            $role = GetRoleString($ra.roledefinitionBindings.Name)
            $hidden = GetHiddenRoleTypeString($ra.roledefinitionBindings.Hidden)
        }
        else
        {
            $role = $ra.roledefinitionBindings.Name
            $hidden = $ra.roledefinitionBindings.Hidden
        }

        $item = New-Object PSObject
        $item | Add-Member -type NoteProperty -Name 'Name' -Value $itName
        $item | Add-Member -type NoteProperty -Name 'Path' -Value $itPath
        $item | Add-Member -type NoteProperty -Name 'Entity' -Value $itEntity
        $item | Add-Member -type NoteProperty -Name 'Title' -Value $ra.member.title
        $item | Add-Member -type NoteProperty -Name 'Role' -Value $role
        $item | Add-Member -type NoteProperty -Name 'Hidden' -Value $hidden
        $objInput.value += $item
    }
}

function GetRoleString($objRole)
{
    $objRole.ForEach{$strRole += $_ + ", "}
    $strRole = $strRole.remove($strRole.lastindexof(","))
    return $strRole   
}#endfunction

function GetHiddenRoleTypeString($objHidden)
{
    $objHidden.ForEach{$strHidden += [string]$_ + ", "}
    $strHidden = $strHidden.remove($strHidden.lastindexof(","))
    return $strHidden
}

######################################
# PROCESS START

$outputFolder = "D:\xSYD\1_Projects\PowerShell\Infobase\Output\"

$result = @()

Foreach($urlName in $globalObj)
{
    if($urlName.Entity -eq "Library")
    {
        GetLibraryPermission -libName $urlname.UrlName -objInput ([ref]$result)    
    }
    else
    {
        $itemName = $urlName.urlname.Substring($urlName.urlname.LastIndexOf("/") + 1)
        $itemPath = $urlName.urlName
        if($urlName.entity -eq "Folder")
        {
            GetFolderPermission -itPath $itemPath -itName $itemName -itEntity $urlName.entity -objInput ([ref]$result)
        }
        else
        {
            GetFilePermission -itPath $itemPath -itName $itemName -itEntity $urlName.entity -objInput ([ref]$result)
        }
    }
}
$result | export-csv "D:\xSYD\1_Projects\PowerShell\Infobase\Output\cse_Concept and Function Responsibles_library_unique_permissions_v01.csv" -NoTypeInformation
#$result | export-csv D:\xSYD\1_Projects\PowerShell\Infobase\Output\phtest_testLib_unique_permissions_v01.csv -NoTypeInformation

write-host -ForegroundColor red "Unique permissions:"
$result | Format-Table

[uint16]$userInput = 0

do {
    $userInput = Read-Host -Prompt "Do you want to export to CSV file? 1-Yes, 2-No" -ErrorAction SilentlyContinue 
} while ($userInput -ne 1 -and $userInput -ne 2)

if ($userInput -eq 1) {
    do {
        $outputFilename = Read-Host -Prompt "Enter the filename e.g. myOutput.csv (Exit=skip export)"

        if(![string]::IsNullOrWhiteSpace($outputFilename) -and $outputFilename -like "*.csv"){
            # do the export
            $outputFullname = $outputFolder+$outputFilename
            $result | export-csv -path $outputFullname  -Delimiter "~" -NoTypeInformation
            Write-Host "Result exported to: $outputFullname" -ForegroundColor Cyan
            $exportDone = $true
        }else {
            # if not Exit perform Do loop
            if($outputFilename -ne "Exit"){
                write-host "Bad CSV name or other issue...try again."
                $exportDone = $false
            }else{break;}
        }
    } while (!$exportDone)
}
Write-Host "Process complete!" -ForegroundColor Cyan
