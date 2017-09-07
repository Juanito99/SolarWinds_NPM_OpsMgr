param($sourceId,$managedEntityId,$MonitorItem,$Threshold)

$api           = New-Object -ComObject 'MOM.ScriptAPI'

$Global:Error.Clear()
$ErrorActionPreference = 'Continue'

$testedAt = "Tested on: $(Get-Date -Format u) / $(([TimeZoneInfo]::Local).DisplayName)"

#region PREWORK Disabling the certificate validations
add-type -TypeDefinition @"
	using System.Net;
	using System.Security.Cryptography.X509Certificates;
	public class TrustAllCertsPolicy : ICertificatePolicy {
		public bool CheckValidationResult(
			ServicePoint srvPoint, X509Certificate certificate,
			WebRequest request, int certificateProblem) {
			return true;
		}
	}
"@
[Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy
#endregion PREWORK

$classNPMMonSrv               = Get-SCOMClass -Name 'ABC.Network.SolarWinds.NPM.MonitoringServer'
$classNPMMonSrvInstances      = Get-SCOMClassInstance -Class $classNPMMonSrv

$classNPMRunTimeInfo          = Get-SCOMClass -Name 'ABC.Network.SolarWinds.NPM.ServerRuntimeInfo'
$classNPMRunTimeInfoInstances = Get-SCOMClassInstance -Class $classNPMRunTimeInfo

$NPMServerName            = $classNPMMonSrvInstances.'[ABC.Network.SolarWinds.NPM.MonitoringServer].NPMServerName'.Value
$NPMInformationServiceURL = $classNPMMonSrvInstances.'[ABC.Network.SolarWinds.NPM.MonitoringServer].NPMInformationServiceURL'.Value
$NPMServerPort            = $classNPMMonSrvInstances.'[ABC.Network.SolarWinds.NPM.MonitoringServer].NPMServerPort'.Value
$NPMServerProtocoll       = $classNPMMonSrvInstances.'[ABC.Network.SolarWinds.NPM.MonitoringServer].NPMServerProtocoll'.Value

$NPMQryUsr = $classNPMRunTimeInfoInstances.'[ABC.Network.SolarWinds.NPM.ServerRuntimeInfo].NPMQryUsr'.Value
$NPMQryPwd = $classNPMRunTimeInfoInstances.'[ABC.Network.SolarWinds.NPM.ServerRuntimeInfo].NPMQryPwd'.Value

$pwdTmpRw = $NPMQryPwd -split '-'
$pwdTmp   = $pwdTmpRw | %{ [System.Text.Encoding]::UTF8.GetString([System.Convert]::ToInt32($_,2)) }

$pwdClear = [string]::Empty
$pwdTmp   | ForEach-Object { $pwdClear += $_ }


$api.LogScriptEvent('ABC.Network.SolarWindws.NPM MonitorNPMNodes.ps1',6000,4,"MonitorNPMNodes Started - Source $($sourceId) managEnt $($managedEntityId) MonitorItem $MonitorItem NPMServer $NPMServerName" )

switch ($MonitorItem) {
	'router' {
		$qrySQL  = "SELECT+NodeID,NodeCaption,AgentIP,Status,SysContact,SysLocation,"
		$qrySQL += "MachineType,LastBoot,City+FROM+NCM.Nodes+WHERE+NodeCaption+LIKE+'%VPN%'+OR+NodeCaption+LIKE+'%GW%'+OR+NodeCaption+LIKE+'%MPLS%'"
		break
	}
	'switch' {
		$qrySQL  = "SELECT+NodeID,NodeCaption,AgentIP,Status,SysContact,SysLocation,"
		$qrySQL += "MachineType,LastBoot,City+FROM+NCM.Nodes+WHERE+NodeCaption+LIKE+'%sw%'"
		break
	}
	'coreswitch' {
		$qrySQL  = "SELECT+NodeID,NodeCaption,AgentIP,Status,SysContact,SysLocation,"
		$qrySQL += "MachineType,LastBoot,City+FROM+NCM.Nodes+WHERE+NodeCaption+LIKE+'%cs%'"
		break
	}
	'firewall' {
		$qrySQL  = "SELECT+NodeID,NodeCaption,AgentIP,Status,SysContact,SysLocation,"
		$qrySQL += "MachineType,LastBoot,City+FROM+NCM.Nodes+WHERE+NodeCaption+LIKE+'%fw%'"
		break
	}
	'arubacontroller' {
		$qrySQL  = "SELECT+NodeID,NodeCaption,AgentIP,Status,SysContact,SysLocation,"
		$qrySQL += "MachineType,LastBoot,City+FROM+NCM.Nodes+WHERE+NodeCaption+LIKE+'%aruba%'"
		break
	}
	'otherdevice' {
		$qrySQL  = "SELECT+NodeID,NodeCaption,AgentIP,Status,SysContact,SysLocation,"
		$qrySQL += "MachineType,LastBoot,City+FROM+NCM.Nodes+WHERE(NodeCaption+NOT+LIKE+'%SW%'+AND+"
		$qrySQL += "NodeCaption+NOT+LIKE+'%MPLS%'+AND+NodeCaption+NOT+LIKE+'%cs%'+AND+"
		$qrySQL += "NodeCaption+NOT+LIKE+'%aruba%'+AND+NodeCaption+NOT+LIKE+'%VPN%'+AND+"
		$qrySQL += "NodeCaption+NOT+LIKE+'%fw%'"
		break
	}

}

$npmSecPwd  = ConvertTo-SecureString $pwdClear -AsPlainText -Force
$npmCreds   = New-Object System.Management.Automation.PSCredential ($NPMQryUsr, $npmSecPwd)

$npmFullUrl = $NPMServerProtocoll + '://' + $NPMServerName + ':' + $NPMServerPort + '/' + $NPMInformationServiceURL + 'query=' + $qrySQL

$api.LogScriptEvent('ABC.Network.SolarWindws.NPM MonitorNPMNodes.ps1',6001,4,"MonitorNPMNodes Qry URL: $npmFullUrl  with User: $npmQryUsr" )

$npmQryRsp  = Invoke-RestMethod -Method Get -Uri $npmFullUrl -Credential $npmCreds -UseBasicParsing 

$npmQryRsp.results | ForEach-Object {

	$nNodeID      = $_.NodeID
	$nNodeCaption = $_.NodeCaption	
	$nAgentIP     = $_.AgentIP
	$nStatus      = $_.Status	
	$nSysContact  = $_.SysContact
	$nSysLocation = $_.SysLocation
	$nMachineType = $_.MachineType	
	$nLastBoot    = $_.LastBoot	
	$nCity        = $_.City

	if ([String]::IsNullOrEmpty($nNodeID))      {continue}
	if ([String]::IsNullOrEmpty($nNodeCaption)) {$nNodeCaption = '.'}	
	if ([String]::IsNullOrEmpty($nAgentIP))     {$nAgentIP = '.'}	
	if ([String]::IsNullOrEmpty($nStatus))      {$nStatus = '.'}	
	if ([String]::IsNullOrEmpty($nSysContact))  {$nSysContact = '.'}
	if ([String]::IsNullOrEmpty($nSysLocation)) {$nSysLocation = '.'}
	if ([String]::IsNullOrEmpty($nMachineType)) {$nMachineType = '.'}
	if ([String]::IsNullOrEmpty($nLastBoot))    {$nLastBoot = '.'}
	if ([String]::IsNullOrEmpty($nCity))        {$nCity = '.'}
	
	if($nStatus -eq '1') {
		$state = 'Success'
	} else {
		$state = 'Failure'
	}

	$supplement = " NodeIP: $($nAgentIP)`n Status: $($nStatus)`n Contact: $($nSysContact)`n Location: $($nSysLocation)`n City: $($nCity)`n LastBoot: $($nLastBoot)"

	$bag = $api.CreatePropertybag()					
	$bag.AddValue("Key",$nNodeID)
	$bag.AddValue("NodeCaption",$nNodeCaption)		
	$bag.AddValue("State",$state)				
	$bag.AddValue("Supplement",$supplement)		
	$bag.AddValue("TestedAt",$testedAt)			
	$bag


} #END $npmQryRsp.results | ForEach-Object 
