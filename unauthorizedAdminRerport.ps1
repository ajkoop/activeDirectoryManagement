 <# 
   Name: Unauthorized Admin Alert (UAA)
   Author: Andrew Koop
   Purpose: Let account admins know that an unauthorized user exists in the local Administrators group on a machine.
#>
Clear-Host
$today = $(get-date -f yyyy-MM-dd)
$homebase = split-path -parent $MyInvocation.MyCommand.Definition
$log = $homebase + '\accountOffboardEmails\' +  $(get-date -f yyyy-MM-dd) +'log.txt'

#Create connection to SQL
$uid = "user"
$pwd = "pwd"
$database = "db"
$server = "intserver"

$connstring = "server=$server;uid=$uid;pwd=$pwd;database=$database;integrated security=false"

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connstring

#UAA view is sourced from an MDM export and import into local integration db
function Get-StaffData {

$sqlcmd = New-Object System.Data.SqlClient.SqlCommand

$sqlcmd.CommandText = "SET NOCOUNT ON; SELECT device,accounts,ip,lastping,username,userpingstatus FROM vUAA"

$sqlcmd.Connection = $connection

$sqladapter = New-Object System.Data.SqlClient.SqlDataAdapter
$sqladapter.SelectCommand = $sqlcmd
$list = New-Object System.Data.DataSet
$rowcount = $sqladapter.Fill($list) 
$connection.Close()

return $list

}


$dataset = Get-StaffData
$rowcount = $dataset.Tables[0].Rows.Count

$data = $dataset.Tables[0]


function Build-HTML
{

   $b = '<html>'
  $b += '<head><title>NETMAN: Unauthorized Admin Users</title></head>'
  $b += '<body class="fixed-header"><iam-portal>'


  $b += '<style> .descript { font-style: italic  }
    table tr:nth-child(odd) { background-color:#dddddd } @supports (-webkit-overflow-scrolling: touch) { .update { display:none } }  @media (min-width: 600px) {
 .portlink {  } .update { background-color:green; color: white; width: 15%; padding: 4px; display: block}  li { display: inline; margin-left: 2px } a, a:visited { text-decoration: none;background-color: #0C3F0A; color: white; padding: 2px } a:hover { background-color: #2E54FF }    </style>'
  if ( $rowcount -gt 0 ) {
 
  $b += '<table width="100%"; border="0"; cellspacing="0"; cellpadding="0" class="tablesorter" id="stuauthdiff">'
    
    $b += '<tr style="width:33%"; id="stumismatch"><h2>MACHINES WITH UNAUTHORIZED ACCOUNTS IN LOCAL ADMINISTRATORS GROUP</h2></tr>'
    $b += '<thead>'
    $b += '<tr style="background-color:blue; color:white"><th>DEVICE</th><th>ACCOUNTS</th><th>IP</th><th>lastping</th>
    <th>username</th><th>userpingstatus*</th></tr>'
    
    $b += '</thead>'
   

$b += '<tbody>'

$b += '<p>* Column indicates whether or not a user was logged-in at most recent run</p>'

foreach ($r in $data.Rows) 
{
    
    $b += "<tr><td>" + $r[0] + "</td><td>"  + $r[1] + "</td><td>" + $r[2] + "</td><td>" + $r[3] +  "</td><td>" + $r[4] + "</td><td>" + $r[5] + "</td> </tr>"
}

  $b += '</table>'
   
$b += '</tbody>'



    
    $b += '</iam-portal></body>'
   
  
    $b += '</html>'

    }

    return $b
 
 


}


$bcc = "array of email addresses"
$testmail = "Dev <dev@mccsc.edu>"

function Send-Message ($s)
{
  
    $to = $testmail
    $from = 'skycheck@mccsc.edu'
    $smtp = 'fqdnsmtpserver'
    $subject = 'MCCSC: UAA' 
    $body = Build-HTML

    Send-MailMessage -To $to -From "Mega Netmannington $from" -cc $bcc -Subject $subject -BodyAsHtml -Body $body -SmtpServer $smtp
}


$emailcheck = Get-Date -Format HH
$dayoweek = (get-date).DayOfWeek

if ( $emailcheck -eq '14' -and $dayoweek -ne 'Saturday' -and $dayoweek -ne 'Sunday') { 

Send-Message 

}

 
