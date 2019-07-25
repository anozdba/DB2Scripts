# 
# script to compare the number of instances of a process with counts defined in
# c:\processLimits.txt
#

# gather the instance counts for all of the processes on a machine

$processList=Get-WmiObject win32_process | select ProcessName

$processCount = @{}
foreach ($process in $processList) {
  $processCount[$process.processName] = $processCount[$process.processName] + 1
}

# read inthe ol file from the server

$limitList=get-content 'c:\processLimitCount.txt'

# compare the instance count with the control file.
# Return 0 if all ok and 1 ifproblems in river city

$returnString = 0
foreach ($limit in $limitList) {
  if ( $processCount[$limit.substring(0,$limit.indexof("|"))] -ne $limit.substring($limit.indexof("|")+1) ) {
    $returnString = 1
  }
}

write-output $("Statistic: " + $returnString)

