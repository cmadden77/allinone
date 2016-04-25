Configuration ConfigureSQLStoragePool
{
  param ($MachineName, $numberOfDisksInPool, $numberOfDisksInPool )

  Node $MachineName
  {
  Script SQLStoragePool {
    SetScript = {  

 # following is a script that creates the log files pool
    function configure-LogDiskStripingScript
        {
    param ([Int] $numberOfDisksInPool)
    
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
    
    Update-HostStorageCache

    $uninitializedDisks = Get-PhysicalDisk -CanPool $true | Sort-Object deviceid
    
    $virtualDiskJobs = @()
    
    $poolDisks = $uninitializedDisks | Select-Object -Skip 0 -First $numberOfDisksInPool 
        
    $poolName = "SQL Log Files"
    $newPool = New-StoragePool -FriendlyName $poolName -StorageSubSystemFriendlyName "Storage Spaces*" -PhysicalDisks $poolDisks
        
    $virtualDiskJobs += New-VirtualDisk -StoragePoolFriendlyName $poolName  -FriendlyName $poolName -ResiliencySettingName Simple -ProvisioningType Fixed `
        -NumberOfDataCopies 1 -UseMaximumSize -AsJob
    
    Receive-Job -Job $virtualDiskJobs -Wait
    Wait-Job -Job $virtualDiskJobs                        
    Remove-Job -Job $virtualDiskJobs
    
    # Initialize and format the virtual disks on the pools
    $vDisk = Get-VirtualDisk $poolName
    $pDisk = Initialize-Disk -UniqueId $vDisk.UniqueId -PassThru -PartitionStyle GPT
    # Check availability of drive letter and remap dvd drive if needed
    $dvdDrive = Get-WmiObject win32_logicaldisk -filter 'DriveType=5'
    if ($dvdDrive.DeviceId -eq "F:")
    {
        $a = mountvol $dvdDrive.DeviceID /l
        mountvol $dvdDrive.DeviceID /d
        $a = $a.Trim()
        mountvol "Z:" $a
    }
    # Create partition and format
    $partition = New-Partition -DiskNumber $pDisk.Number -DriveLetter "F" -UseMaximumSize
    $formatted =  Format-Volume -DriveLetter $partition.DriveLetter -AllocationUnitSize 65536 -FileSystem NTFS -NewFileSystemLabel $poolName  –Force -Confirm:$false
    #$formatted = Get-VirtualDisk $poolName | Clear-Disk | Initialize-Disk -PassThru -PartitionStyle GPT | New-Partition -DriveLetter "F" -UseMaximumSize | Format-Volume -FileSystem NTFS -FileSystemLabel $poolName -AllocationUnitSize 65536 –Force -Confirm:$false
        
    # Dive time to the storage service to pick up the changes
    Start-Sleep -Seconds 120

    Test-Path "F:"
    $acl = Get-Acl -Path "F:"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl "F:" $acl
    }        


# following is a script that creates the data files pool
   function configure-DataDiskStripingScript
                                                                                                                        {
    param ([Int] $numberOfDisksInPool)
    
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned

    Update-HostStorageCache
    
    $uninitializedDisks = Get-PhysicalDisk -CanPool $True | Sort-Object deviceid
    
    $virtualDiskJobs = @()
    
    $poolDisks = $uninitializedDisks | Select-Object -Skip 0 -First $numberOfDisksInPool 
        
    $poolName = "SQL Data Files"
    $newPool = New-StoragePool -FriendlyName $poolName -StorageSubSystemFriendlyName "Storage Spaces*" -PhysicalDisks $poolDisks
        
    $virtualDiskJobs += New-VirtualDisk -StoragePoolFriendlyName $poolName  -FriendlyName $poolName -ResiliencySettingName Simple -ProvisioningType Fixed -NumberOfDataCopies 1 -UseMaximumSize -AsJob
    
    Receive-Job -Job $virtualDiskJobs -Wait
    Wait-Job -Job $virtualDiskJobs                        
    Remove-Job -Job $virtualDiskJobs
    
    # Initialize and format the virtual disks on the pools
    $vDisk = Get-VirtualDisk $poolName
    $pDisk = Initialize-Disk -UniqueId $vDisk.UniqueId -PassThru -PartitionStyle GPT
    # Check availability of drive letter and remap dvd drive if needed
    $dvdDrive = Get-WmiObject win32_logicaldisk -filter 'DriveType=5'
    if ($dvdDrive.DeviceId -eq "G:")
    {
        $a = mountvol $dvdDrive.DeviceID /l
        mountvol $dvdDrive.DeviceID /d
        $a = $a.Trim()
        mountvol "Y:" $a
    }
    # Create partition and format
    $partition = New-Partition -DiskNumber $pDisk.Number -DriveLetter "G" -UseMaximumSize
    $formatted =  Format-Volume -DriveLetter $partition.DriveLetter -AllocationUnitSize 65536 -FileSystem NTFS -NewFileSystemLabel $poolName  –Force -Confirm:$false
    #$formatted = Get-VirtualDisk $poolName | Clear-Disk | Initialize-Disk -PassThru -PartitionStyle GPT | New-Partition -DriveLetter "G" -UseMaximumSize | Format-Volume -FileSystem NTFS -FileSystemLabel $poolName -AllocationUnitSize 65536 –Force -Confirm:$false
        
    # Dive time to the storage service to pick up the changes
    Start-Sleep -Seconds 120

    Test-Path "G:"
    $acl = Get-Acl -Path "G:"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl "G:" $acl
    } 

configure-LogDiskStripingScript $numberOfDisksInLogPool
configure-DataDiskStripingScript $numberOfDisksInDataPool
            }
        }
    }
}