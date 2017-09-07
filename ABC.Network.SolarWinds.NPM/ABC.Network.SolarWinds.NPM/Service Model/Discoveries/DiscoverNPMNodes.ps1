param($sourceId,$managedEntityId,$NPMRegPath)

$api           = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

$Global:Error.Clear()
$ErrorActionPreference = 'Continue'

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

$api.LogScriptEvent('ABC.Network.SolarWindws.NPM DiscoverNPMNodes.ps1',5000,4,"DiscoverNPMNodes Started - Source $($sourceId) managEnt $($managedEntityId) discoveryItem $discoveryItem registry Key $NPMRegPath " )

$NPMRegPath               = 'HKLM:\' + $NPMRegPath
$npmServerProtocoll       = Get-ItemProperty -Path $NPMRegPath | Select-Object -ExpandProperty NPMServerProtocoll
$npmServerName            = Get-ItemProperty -Path $NPMRegPath | Select-Object -ExpandProperty NPMServerName
$npmServerPort            = Get-ItemProperty -Path $NPMRegPath | Select-Object -ExpandProperty NPMServerPort
$npmInformationServiceURL = Get-ItemProperty -Path $NPMRegPath | Select-Object -ExpandProperty NPMInformationServiceURL
$npmQryUsr                = Get-ItemProperty -Path $NPMRegPath | Select-Object -ExpandProperty NPMQryUsr
$npmQryPwd                = Get-ItemProperty -Path $NPMRegPath | Select-Object -ExpandProperty NPMQryPwd

#region discoverServerRuntimeInfo 

$npmQryPwdHsh   = [System.Text.Encoding]::UTF8.GetBytes($npmQryPwd) | %{ [System.Convert]::ToString($_,2).PadLeft(8,'0') }
$npmQryPwdHshst = $npmQryPwdHsh -join '-'

$displayName = 'RuntimeInfo-' + $npmServerName			
$instance = $discoveryData.CreateClassInstance("$MPElement[Name='ABC.Network.SolarWinds.NPM.ServerRuntimeInfo']$")			
$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.ServerRuntimeInfo']/NPMQryPwd$",$npmQryPwdHshst)
$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.ServerRuntimeInfo']/NPMQryUsr$",$npmQryUsr)
$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
$discoveryData.AddInstance($instance)		

#endregion discoverServerRuntimeInfo


# Below discovery of Nodes

$npmSecPwd  = ConvertTo-SecureString $npmQryPwd -AsPlainText -Force
$npmCreds   = New-Object System.Management.Automation.PSCredential ($npmQryUsr, $npmSecPwd)

$qrySQL     = 'SELECT+NodeID,NodeCaption,NodeGroup,AgentIP,Community,SysName,SysDescr,SysContact,SysLocation,SystemOID,'
$qrySQL    += 'Vendor,MachineType,LastBoot,OSImage,OSVersion,ConfigTypes,LoginStatus,City+FROM+NCM.Nodes'

$npmFullUrl = $npmServerProtocoll + '://' + $npmServerName + ':' + $npmServerPort + '/' + $npmInformationServiceURL + 'query=' + $qrySQL

$api.LogScriptEvent('ABC.Network.SolarWindws.NPM DiscoverNPMNodes.ps1',5001,4,"DiscoverNPMNodes Qry URL: $npmFullUrl  with User: $npmQryUsr found pwd in $npmQryPwdPath " )

$npmQryRsp  = Invoke-RestMethod -Method Get -Uri $npmFullUrl -Credential $npmCreds -UseBasicParsing 

$npmQryRsp.results | ForEach-Object {

	$nNodeID      = $_.NodeID
	$nNodeCaption = $_.NodeCaption
	$nNodeGroup   = $_.NodeGroup
	$nAgentIP     = $_.AgentIP
	$nCommunity   = $_.Community
	$nSysName     = $_.SysName
	$nSysDescr    = $_.SysDescr
	$nSysContact  = $_.SysContact
	$nSysLocation = $_.SysLocation
	$nSystemOID   = $_.SystemOID
	$nMachineType = $_.MachineType
	$nVendor      = $_.Vendor
	$nLastBoot    = $_.LastBoot
	$nOsImage     = $_.OSImage
	$nOsVersion   = $_.OSVersion
	$nConfigTypes = $_.ConfigTypes
	$nLoginStatus = $_.LoginStatus
	$nCity        = $_.City

	if ([String]::IsNullOrEmpty($nNodeID))      {continue}
	if ([String]::IsNullOrEmpty($nNodeCaption)) {$nNodeCaption = '.'}
	if ([String]::IsNullOrEmpty($nNodeGroup))   {$nNodeGroup = '.'}
	if ([String]::IsNullOrEmpty($nAgentIP))     {$nAgentIP = '.'}
	if ([String]::IsNullOrEmpty($nCommunity))   {$nCommunity = '.'}
	if ([String]::IsNullOrEmpty($nSysName))     {$nSysName = '.'}
	if ([String]::IsNullOrEmpty($nSysDescr))    {$nSysDescr = '.'}
	if ([String]::IsNullOrEmpty($nSysContact))  {$nSysContact = '.'}
	if ([String]::IsNullOrEmpty($nSysLocation)) {$nSysLocation = '.'}
	if ([String]::IsNullOrEmpty($nSystemOID))   {$nSystemOID = '.'}
	if ([String]::IsNullOrEmpty($nMachineType)) {$nMachineType = '.'}
	if ([String]::IsNullOrEmpty($nVendor))      {$nVendor = '.'}
	if ([String]::IsNullOrEmpty($nLastBoot))    {$nLastBoot = '.'}
	if ([String]::IsNullOrEmpty($nOsImage))     {$nOsImage = '.'}
	if ([String]::IsNullOrEmpty($nOsVersion))   {$nOsVersion = '.'}
	if ([String]::IsNullOrEmpty($nConfigTypes)) {$nConfigTypes = '.'}
	if ([String]::IsNullOrEmpty($nLoginStatus)) {$nLoginStatus = '.'}
	if ([String]::IsNullOrEmpty($nCity))        {$nCity = '.'}

	switch -regex ($nNodeCaption) {
		'[a-zA-Z-_0-9\.]*VPN|[a-zA-Z-_0-9\.]*GW|[a-zA-Z\-_0-9\.]*MPLS' {
			$displayName = 'Router-' + $nNodeCaption			
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='ABC.Network.SolarWinds.NPM.Router']$")			
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeID$",$nNodeID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeCaption$",$nNodeCaption)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeGroup$",$nNodeGroup)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/AgentIP$",$nAgentIP)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Community$",$nCommunity)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysName$",$nSysName)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysDescr$",$nSysDescr)	
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysContact$",$nSysContact)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysLocation$",$nSysLocation)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SystemOID$",$nSystemOID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Vendor$",$nVendor)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/MachineType$",$nMachineType)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LastBoot$",$nLastBoot)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSImage$",$nOsImage)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSVersion$",$nOsVersion)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/ConfigTypes$",$nConfigTypes)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LoginStatus$",$nLoginStatus)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/City$",$nCity)			
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)		
			
		  break
		}
		'[a-zA-Z\-_0-9\.]{5,5}sw|SW' {
		  $displayName = 'Switch-' + $nNodeCaption
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='ABC.Network.SolarWinds.NPM.Switch']$")			
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeID$",$nNodeID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeCaption$",$nNodeCaption)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeGroup$",$nNodeGroup)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/AgentIP$",$nAgentIP)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Community$",$nCommunity)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysName$",$nSysName)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysDescr$",$nSysDescr)	
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysContact$",$nSysContact)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysLocation$",$nSysLocation)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SystemOID$",$nSystemOID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Vendor$",$nVendor)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/MachineType$",$nMachineType)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LastBoot$",$nLastBoot)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSImage$",$nOsImage)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSVersion$",$nOsVersion)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/ConfigTypes$",$nConfigTypes)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LoginStatus$",$nLoginStatus)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/City$",$nCity)			
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)		
		  break
		}
		'[a-zA-Z\-_0-9]{5}CS|cs' {
			$displayName = 'CoreSwitch-' + $nNodeCaption			
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='ABC.Network.SolarWinds.NPM.CoreSwitch']$")			
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeID$",$nNodeID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeCaption$",$nNodeCaption)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeGroup$",$nNodeGroup)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/AgentIP$",$nAgentIP)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Community$",$nCommunity)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysName$",$nSysName)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysDescr$",$nSysDescr)	
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysContact$",$nSysContact)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysLocation$",$nSysLocation)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SystemOID$",$nSystemOID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Vendor$",$nVendor)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/MachineType$",$nMachineType)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LastBoot$",$nLastBoot)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSImage$",$nOsImage)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSVersion$",$nOsVersion)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/ConfigTypes$",$nConfigTypes)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LoginStatus$",$nLoginStatus)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/City$",$nCity)		
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)					
		  break
		}
		'[a-zA-Z\-_0-9\.]{5,5}fw|FW' {
			$displayName = 'FireWall-' + $nNodeCaption			
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='ABC.Network.SolarWinds.NPM.FireWall']$")			
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeID$",$nNodeID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeCaption$",$nNodeCaption)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeGroup$",$nNodeGroup)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/AgentIP$",$nAgentIP)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Community$",$nCommunity)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysName$",$nSysName)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysDescr$",$nSysDescr)	
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysContact$",$nSysContact)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysLocation$",$nSysLocation)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SystemOID$",$nSystemOID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Vendor$",$nVendor)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/MachineType$",$nMachineType)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LastBoot$",$nLastBoot)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSImage$",$nOsImage)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSVersion$",$nOsVersion)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/ConfigTypes$",$nConfigTypes)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LoginStatus$",$nLoginStatus)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/City$",$nCity)	
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)	
			$discoveryData.AddInstance($instance)					
		  break
		}
		'(?i)[a-zA-Z\-_0-9\.]{5,5}ARUBA' {
			$displayName = 'ArubaController-' + $nNodeCaption			
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='ABC.Network.SolarWinds.NPM.ArubaController']$")			
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeID$",$nNodeID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeCaption$",$nNodeCaption)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeGroup$",$nNodeGroup)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/AgentIP$",$nAgentIP)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Community$",$nCommunity)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysName$",$nSysName)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysDescr$",$nSysDescr)	
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysContact$",$nSysContact)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysLocation$",$nSysLocation)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SystemOID$",$nSystemOID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Vendor$",$nVendor)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/MachineType$",$nMachineType)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LastBoot$",$nLastBoot)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSImage$",$nOsImage)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSVersion$",$nOsVersion)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/ConfigTypes$",$nConfigTypes)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LoginStatus$",$nLoginStatus)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/City$",$nCity)	
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)	
			$discoveryData.AddInstance($instance)					
		  break
		}
		default {		  
			$displayName = 'OtherDevice-' + $nNodeCaption			
			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='ABC.Network.SolarWinds.NPM.OtherDevice']$")			
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeID$",$nNodeID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeCaption$",$nNodeCaption)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/NodeGroup$",$nNodeGroup)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/AgentIP$",$nAgentIP)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Community$",$nCommunity)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysName$",$nSysName)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysDescr$",$nSysDescr)	
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysContact$",$nSysContact)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SysLocation$",$nSysLocation)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/SystemOID$",$nSystemOID)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/Vendor$",$nVendor)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/MachineType$",$nMachineType)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LastBoot$",$nLastBoot)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSImage$",$nOsImage)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/OSVersion$",$nOsVersion)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/ConfigTypes$",$nConfigTypes)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/LoginStatus$",$nLoginStatus)
			$instance.AddProperty("$MPElement[Name='ABC.Network.SolarWinds.NPM.Node']/City$",$nCity)				
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)					
		}
	}

} #END $npmQryRsp.results | ForEach-Object 

$discoveryData