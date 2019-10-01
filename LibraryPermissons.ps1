

# SCRIPT INFO:
<#
---------------------------------------------------------------------------------------
- Loop through selected Library and returning the path of folder and its permission in
  case the folder has broken inheritance.
- final $globalOjb can be used further to get the members and roles for these unique
  permissions
---------------------------------------------------------------------------------------
#>


#region functions
Function CreateMenu ($obj)
{
    
    $docsLib = Get-PnPList | Where-Object{$_.Basetype -eq "DocumentLibrary" } | select Title, EntityTypeName |  Sort-Object -Property title
    $idx = 0
    for($i=0;$i -lt $docsLib.count;$i++)
    {
        $obj.value += New-Object psobject -Property @{
            idx = $idx++
            title = $docsLib[$i].title
            entity = $docsLib[$i].entitytypename
        }
    }
}


Function GetLibraryPermission
{
    Param( [string]$libName )

    $lib = Get-PnPList -Identity $libName -Includes RoleAssignments, HasUniqueRoleAssignments
    $ctx = Get-PnPContext
    $ctx.load($lib)
    $ctx.ExecuteQuery()
    $blnHasUniqueRole = $lib.HasUniqueRoleAssignments

    if($blnHasUniqueRole)
    {
        $item = New-Object PSObject
        $item | Add-Member -type NoteProperty -Name 'UrlName' -Value $libName
        $item | Add-Member -type NoteProperty -Name 'Fullname' -Value $null
        $item | Add-Member -type NoteProperty -name 'Entity' -value "Library"
        $global:globalObj += $item

        $outMes = "Library has unique permissions. Now checking items inside library..."
        # result output
        write-host $outMes -fore Red
    }
    else
    {
        $outMes = "Library inherits permissions from its parent. Now checking items inside library..."
        # result output
        write-host $outMes -fore Cyan
       
    }

}



Function GetFolderPermission
{
    Param
        (
        [string]$urlName,
        [string]$fullName
        )

    $fld = Get-PnPFolder -Url $urlName -Includes ListItemAllFields.RoleAssignments, ListItemAllFields.HasUniqueRoleAssignments
    $ctx = Get-PnPContext
    $ctx.Load($fld)
    $ctx.ExecuteQuery()
    
    if($fld.ListItemAllFields.HasUniqueRoleAssignments)
    {
        $item = New-Object PSObject
        $item | Add-Member -type NoteProperty -Name 'UrlName' -Value $urlName.Substring(1)
        $item | Add-Member -type NoteProperty -Name 'Fullname' -Value $fullName
        $item | Add-Member -type NoteProperty -name 'Entity' -value "Folder"
        $global:globalObj += $item
    }
}


Function GetFilePermission
{
    Param
    (
        [string]$urlName,
        [string]$fullName
    )
    
    $file = Get-PnPFile -url $urlName -AsListItem
    Get-PnPProperty -ClientObject $file -Property HasUniqueRoleAssignments, RoleAssignments

    if($file.HasUniqueRoleAssignments)
    {
        $item = New-Object PSObject
        $item | Add-Member -type NoteProperty -Name 'UrlName' -Value $urlName
        $item | Add-Member -type NoteProperty -Name 'Fullname' -Value $fullName
        $item | Add-Member -type NoteProperty -name 'Entity' -value "File"
        $global:globalObj += $item
    }
}


function GetFolders()
{
    Param
    (
        [string] $folderUrl
    )

    $folderColl = Get-PnPFolderItem -FolderSiteRelativeUrl $folderUrl -ItemType All 

    if($folderColl.count -eq 0)
    {
        break;
    }
    else
    {
        # loop through the folders
        foreach($folder in $folderColl)
        {
            $newFolderUrl = $folderUrl+"/"+$folder.name
           
            if($folder.gettype().name -eq "Folder")
                # flow for folder
            {
                # exclude the 'somewhat invisible' Forms folder
                if( $newFolderUrl -ne "$folderUrl/Forms")
                {
                    $folderNameAndPath = "$($folder.name) - $newFolderUrl"
                    $script:folderCnt += 1
                    $fldPath = "/"+$newFolderUrl
                    GetFolderPermission -urlName $fldPath -fullName $folderNameAndPath
                }#endif
            }
            else
                # flow for a file
            {
                $script:fileCnt += 1
                $fileNameAndPath = "$($folder.name) - $newFolderUrl"
                GetFilePermission -urlName $newFolderUrl -fullName $fileNameAndPath
            }#endif
            
            # call the function to get the folders inside folder
            if($folder.itemcount -gt 0)
            {
                GetFolders -folderUrl $newFolderUrl
            }#endif
        }#endforeach
    }#endif
}
#endregion function


# SCRIPT BEGINING

Clear-Host
$script:folderCnt = 0
$script:fileCnt = 0
$script:bDisplayMembers = $false

$intro =
@" 
========================================================================
= This script loops through chosen library and output all items (folder,
= files) with unique permissions set.
========================================================================
"@
           
           
$obj = @()
CreateMenu -obj ([ref]$obj)
write-host $intro -fore Cyan
$obj | select idx, Title | Format-Table

try
{
    $choice = Read-Host -Prompt "Make your selection"
    write-host `r
    #[int]$choice -ist [int] 
    [int]$choice = $choice
}
catch
{
    write-host -ForegroundColor Red "Bad input!"
    exit
}


if($choice -ge 0 -and $choice -le $obj.Count)
{
    $folder = $obj[$choice].entity
    if($folder.Contains("_x0020_"))
    {
        $folder = $folder.Replace("_x0020_"," ")
    }
    #Write-Output "Folder is: $folder"
}
else
{
    write-host "Bad input!" -ForegroundColor Red
    exit
}


# MAIN PROCESS
$global:globalObj = @()

# first permission check on library level
GetLibraryPermission -libName $folder

# now check all items
GetFolders -folderUrl $folder
if($globalObj.count -eq 0)
{
    # no broken permissions
    Write-Host "`nGood. `"$folder`" library and its items inherit permissions from the web." -fore Cyan
}
else
{
    if($globalObj.count -gt 1)
    {
        write-host "`nFollowing item(s) in `"$folder`" library have unique permissions:" -fore Red
        $globalObj | select UrlName, Entity | where{$_.entity -ne "Library"} | Format-Table
    }
    else
    {
        Write-Host "`nNo unique permissions found on item level in `"$folder`" library." -fore Cyan
    }
}

# OUTPUT OF ITEMS STATISTIC
$total = $folderCnt + $fileCnt
$stat =
@"
Folder count:  $folderCnt
File count:    $fileCnt
Total items:   $total
"@
Write-Host `n$stat -fore Yellow
#write-host "`nFolder count:`t$folderCnt`nFile count:`t`t$fileCnt`nTotal items:"`t($folderCnt + $fileCnt) -ForegroundColor Yellow
            
   