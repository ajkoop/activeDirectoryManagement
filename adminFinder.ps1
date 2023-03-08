#Purpose: Track AD admin access
#Does: 
  # list out admins and when they were added
  # notifies on additions and removals via email
  
Clear-Host

$secstr = New-Object -TypeName System.Security.SecureString
$password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr

$log = $homebase + '\naps\' +  $(get-date -f yyyy-MM-dd) +'log.txt'

$time = get-date

$homebase = split-path -parent $MyInvocation.MyCommand.Definition

#Create connection to SQL
$uid = "user"
$pwd = "pwd"
$database = "db"
$server = "dbserver"

$connstring = "server=$server;uid=$uid;pwd=$pwd;database=$database;integrated security=false"

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connstring

### FUNCTION TOWN

function Get-Current {

$sqlcmd = New-Object System.Data.SqlClient.SqlCommand

$sqlcmd.CommandText = "SELECT * FROM adminListTable"

$sqlcmd.Connection = $connection

$sqladapter = New-Object System.Data.SqlClient.SqlDataAdapter
$sqladapter.SelectCommand = $sqlcmd
$list = New-Object System.Data.DataSet
$rowcount = $sqladapter.Fill($list) 
$connection.Close()

return $list

}

function Get-Deets {

$sqlcmd = New-Object System.Data.SqlClient.SqlCommand

$sqlcmd.CommandText = "SELECT * FROM adminListTable WHERE STATUS IN ('gone','new')"

$sqlcmd.Connection = $connection

$sqladapter = New-Object System.Data.SqlClient.SqlDataAdapter
$sqladapter.SelectCommand = $sqlcmd
$list = New-Object System.Data.DataSet
$rowcount = $sqladapter.Fill($list) 
$connection.Close()

return $list

}

function Import-SQLPS {
    $Current = Get-Location
    Import-Module sqlps -DisableNameChecking
    Set-Location $Current
}


function Check-Madmen ($status) { 


$table = 'adminListTable'


$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server = $server; Database = $database; uid=$uid;pwd=$pwd"
$SqlConnection.Open()

$sqlCMD = @"

Declare @USER nvarchar(32) 
SET @user = '$($name)'

Declare @STATUS nvarchar(8)
SET @STATUS = '$($status)'

Declare @TIME datetime
SET @Time = '$($time)'

IF EXISTS (select USERNAME from $table where USERNAME = @USER AND status in ('gone','EXILED'))
    UPDATE [DBO].[$table]
    SET [STATUS] = 'NEW'
    WHERE USERNAME = @USER

IF EXISTS (select USERNAME FROM $table where USERNAME = @USER and BON_VOYAGE IS NOT NULL AND STATUS = 'current')
    BEGIN
    UPDATE [dbo].[$table]
    SET [STATUS] = 'NEW' 
    WHERE USERNAME = @USER
    END



IF EXISTS (select USERNAME from $table where USERNAME = @USER and BON_VOYAGE is NULL )
	BEGIN
        
            UPDATE [dbo].[$table]
            SET [STATUS] = @STATUS 
            WHERE USERNAME = @USER

            UPDATE [dbo].[$table]
            SET [LAST_VERIFIED] = @TIME
            WHERE USERNAME = @USER

           
	END
ELSE
	
    IF NOT EXISTS (select USERNAME from $table where USERNAME = @USER)
    BEGIN
        INSERT INTO [dbo].[$table]
            ([USERNAME]
            ,[STATUS]
            ,[DISCOVERED])
            
        VALUES
            (@USER
            ,@STATUS
            ,@TIME)
	END
"@

$dbwrite = $SqlConnection.CreateCommand()
$dbwrite.CommandText = $sqlCMD
$dbwrite.ExecuteNonQuery()



$SqlConnection.close()

}

function Check-Gone ($status) { 


$table = 'adminListTable'


$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server = $server; Database = $database; uid=$uid;pwd=$pwd;"
$SqlConnection.Open()

$sqlCMD = @"

Declare @USER nvarchar(32) 
SET @USER = '$($user)'

Declare @STATUS nvarchar(8)
SET @STATUS = '$($status)'

Declare @TIME datetime
SET @TIME = '$($time)'

Declare @BONV datetime
SET @BONV = '$($time)'

IF EXISTS (select USERNAME from $table where USERNAME = @USER )
   BEGIN
        UPDATE [dbo].[$table]
        SET [STATUS] = @STATUS
        WHERE USERNAME = @USER

        UPDATE [dbo].[$table]
        SET [LAST_VERIFIED] = @TIME
        WHERE USERNAME = @USER
   END


IF EXISTS (select USERNAME from $table where USERNAME = @USER AND STATUS = 'gone' AND BON_VOYAGE IS NULL )
   BEGIN
	    UPDATE [DBO].[$table]
        SET [BON_VOYAGE] = @BONV
        WHERE USERNAME = @USER
   END


IF EXISTS (select USERNAME from $table where USERNAME = @USER AND DATEDIFF(minute, BON_VOYAGE, @TIME) > 5 )
   BEGIN
        UPDATE [DBO].[$table]
        SET [STATUS] = 'EXILED'
        WHERE USERNAME = @USER
   END


"@
#write-host $sqlCMD
$dbwrite = $SqlConnection.CreateCommand()
$dbwrite.CommandText = $sqlCMD
$dbwrite.ExecuteNonQuery()



$SqlConnection.close()

}


$madmenpool = Get-Current

$madmen = $madmenpool.Tables.Rows | Select-Object USERNAME
$bingo = $madmen.username
#write-host $bingo

Import-Module ActiveDirectory

$discovery = Get-ADGroupMember -Identity "Domain Admins" | select-object samaccountname

$lilchump = $discovery.samaccountname

foreach ($d in $discovery) { 
$name = $d.samaccountname
write-host $name
if ($bingo -contains $name) { $status = 'current'}
if ($bingo -notcontains $name ) { $status = 'new' }
write-host "status is $status"
Check-Madmen $status
}

foreach ($m in $madmen) { 
$user = $m.username
$stat = $m.status 
if ($user -notin $lilchump) { 
$status = 'gone'
write-host "$user appears to be $status"
Check-Gone $status
} }

$postrun = Get-Deets
$deets = $postrun.Tables[0]


  function Build-HTML
{

   $b = '<html>'
  $b += '<head><title>DOMAIN ADMINS</title></head>'
  $b += '<body class="fixed-header"><iam-portal>'

  $b += '<style> .descript { font-style: italic  }
    table tr:nth-child(odd) { background-color:#dddddd } @supports (-webkit-overflow-scrolling: touch) { .update { display:none } }  @media (min-width: 600px) {
 .portlink {  } .update { background-color:green; color: white; width: 15%; padding: 4px; display: block}  li { display: inline; margin-left: 2px } a, a:visited { text-decoration: none;background-color: #0C3F0A; color: white; padding: 2px } a:hover { background-color: #2E54FF }    </style>'

 
  $b += '<table width="100%"; border="0"; cellspacing="0"; cellpadding="0">'
    
    $b += '<tr style="width:33%"; id="stumismatch"><h2>DOMAIN ADMINS</h2></tr>'
    $b += '<thead>'
    $b += '<tr style="background-color:blue; color:white;text-align: left"><th>USERNAME</th><th>STATUS</th><th>DISCOVERED</th><th>LAST VERIFIED</th><th>REMOVAL</th></tr>'
    $b += '</thead>'
   

### NEW USERS

$b += '<tbody>'

foreach ($r in $deets) 
{
   
    
    $b += "<tr><td>" + $r[0] + "</td><td>" + $r[1] + "</td><td>" +  $r[2] + "</td><td>" + $r[3] + "</td><td>" + $r[4] + "</td></tr>"
   
}

  $b += '</table>'
   
$b += '</tbody>'





    $b += '</body></html>'
     
    return $b

}

$techmail = 'Admin<adminemail@mccsc.edu>'
$bcc = "thosetobecopied@mccsc.edu"


function Send-Message ($s)
{
    $to = $techmail
    
    $from = "<fromaddress@mccsc.edu>"
    
    $smtp = 'fqdnsmtpserv'
    $subject = "Domain Admin Check"

   if($deets.Rows.Count -gt 0 ) {
    $body = Build-HTML
    
Send-MailMessage -To $techmail -From "Mega Netmo $from" -bcc $bcc -Subject $subject -BodyAsHtml -Body $body -SmtpServer $smtp -dno OnFailure
    }
   
 
   
}


Send-Message
