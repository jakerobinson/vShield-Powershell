# vShield Powershell cmdlets
# by Jake Robinson
# Twitter: @jakerobinson
# github.com/jakerobinson
# 
# THESE ARE STILL IN DEVELOPMENT
#
# For help try: get-help <cmdlet>



 ######################################################
# Get-vSERules
 ######################################################
function Get-vSERules
{
    <#
        .SYNOPSIS
        Connects to vShield Manager and retrieves vShield Edge Firewall Rules.

        .DESCRIPTION
        Get-vSERules connects to vShield Manager and retrieves the vShield Edge firewall Rules.

        .PARAMETER vsm
        URL of the vShield Manager (https://myVSM)
        
        .PARAMETER portGroup
        The portgroup that the vSE is protecting
        
        .PARAMETER credential
        Login for the vShield Manager
        
        .PARAMETER rawXML
        Switch to allow the return of rawXML, default returns PSObject


        .EXAMPLE
        
        Prints firewall rules to screen:
        
        $vsm = "https://MyVSM"
        $portgroup = Get-VirtualPortGroup -distributed -name "MyPortgroup"
        $credential = get-credential
        
        Get-vSERules $vsm $portgroup $credential
    #>


    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,Position=0)]
        [ValidatePattern('^(http|https)')]
        [alias("vsmURL")]
        [System.URI]$vsm,
        
        [parameter(Position=1)]
        [alias("pg")]
        $portGroup,
        
        [parameter(Position=2)]
        [alias("cred")]
        [System.Management.Automation.PSCredential]$credential = (get-credential),
        
        [parameter(Mandatory=$false)]
        [alias("xml")]
        [switch]$rawXML
        
    )
    PROCESS
    {
    
        if (!$portGroup)
        {
            $portGroups = Get-VirtualPortGroup -Distributed
            $selected = Open-ListDialog ($portGroups | %{$_.name}) "Select a dvPortgroup" "Select a dvPortgroup:"
            $portGroup = $portGroups | where {$_.name -eq $selected}
        }
        
        $fwRuleSet = @()
        $responseObj = new-object PSObject
        try
        {
            $request = [System.Net.WebRequest]::Create("$($vsm)/api/1.0/network/$($portGroup.key)/firewall/rules");
            $request.credentials = [System.Net.NetworkCredential]$credential
            $request.Method="GET"

            $response = $request.GetResponse()
            $responseStream = $response.getResponseStream()
            $streamReader = new-object System.IO.StreamReader($responseStream)
            [string]$result = $streamReader.ReadtoEnd()
            [xml]$xmldata = $result
            if ($rawXML)
            {
                return $xmldata
            }
            $fwRules = $xmldata.VShieldEdgeConfig.FirewallConfig.FirewallRule

            foreach ($fwRule in $fwRules)
            {
                $fwRuleObj = New-Object PSObject
    
                if ($fwRule.sourceIpAddress.IpRange)
                {
                    $rangeStart = $fwRule.sourceIpAddress.IpRange.rangeStart
                    $rangeEnd = $fwRule.sourceIpAddress.IpRange.rangeEnd
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "sStartIP" -value $rangeStart
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "sEndIP" -value $rangeEnd

                }
                else 
                {
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "sStartIP" -value $fwRule.sourceIpAddress.ipAddress
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "sEndIP" -value " "
                }
                
                if ($fwRule.sourcePort.portRange)
                {
                    $rangeStart = $fwRule.sourcePort.portRange.rangeStart
                    $rangeEnd = $fwRule.sourcePort.portRange.rangeEnd
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "sStartPort" -value $rangeStart
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "sEndPort" -value $rangeEnd
                }
                else 
                {
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "sStartPort" -value $fwRule.sourcePort.port
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "sEndPort" -value " "
                }

                if ($fwRule.destinationIpAddress.IpRange)
                {
                    $rangeStart = $fwRule.destinationIpAddress.IpRange.rangeStart
                    $rangeEnd = $fwRule.destinationIpAddress.IpRange.rangeEnd
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "dStartIP" -value $rangeStart
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "dEndIP" -value $rangeEnd
                }
                else 
                {
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "dStartIP" -value $fwRule.destinationIpAddress.ipAddress
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "dEndIP" -value " "
                }

                if ($fwRule.destinationPort.portRange)
                {
                    $rangeStart = $fwRule.destinationPort.portRange.rangeStart
                    $rangeEnd = $fwRule.destinationPort.portRange.rangeEnd
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "dStartPort" -value $rangeStart
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "dEndPort" -value $rangeEnd
                }
                else 
                {
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "dStartPort" -value $fwRule.destinationPort.port
                    add-member -membertype NoteProperty -inputobject $fwRuleObj -name "dEndPort" -value " "
                }

                add-member -membertype NoteProperty -inputobject $fwRuleObj -name "protocol" -value $fwRule.protocol
                add-member -membertype NoteProperty -inputobject $fwRuleObj -name "direction" -value $fwRule.direction
                add-member -membertype NoteProperty -inputobject $fwRuleObj -name "action" -value $fwRule.action
                add-member -membertype NoteProperty -inputobject $fwRuleObj -name "ruleId" -value $fwRule.ruleId

                $fwRuleSet += $fwRuleObj
            }    
        }
        catch [Net.WebException]
        {
            return(write-host -ForegroundColor red $_.exception.message)
        }

        $streamReader.close()
        $response.close()

        return $fwRuleSet
    
        
    } 
}

 ######################################################
# Set-vSERules
 ######################################################    
function Set-vSERules
{
    <#
        .SYNOPSIS
        Sets vShield Edge Firewall rules


        .DESCRIPTION
        Sets vShield Edge Firewall rules. Warning, using this will overwrite any rules already in the vSE. Please use Get-vSERules to first download the ruleset.
        
        
        Currently supports CSV input with the following Columns
        
        sStartIP     (source Start IP)
        sEndIP       (source End IP)
        sStartPort   (source Start Port)
        sEndPort     (source End Port)
        dStartIP     (dest Start IP)
        dEndIP       (dest End IP)
        dStartPort   (dest Start Port)
        dEndPort     (dest End Port)
        protocol     (protocol)
        direction    (direction)
        action       (action)

        .PARAMETER vsm
        URL of the vShield Manager (https://myVSM)
        
        .PARAMETER portGroup
        The portgroup that the vSE is protecting
        
        .PARAMETER credential
        Login for the vShield Manager
        
        .PARAMETER path
        Login for the vShield Manager


        .EXAMPLE
        
        Imports firewall rules from pre-poplulated CSV
        
        $vsm = "https://MyVSM"
        $portgroup = Get-VirtualPortGroup -distributed -name "MyPortgroup"
        $credential = get-credential
        $csv = "C:\users\MyUser\Desktop\myvSERules.csv"
        
        Set-vSERules $vsm $portgroup $credential $csv
    #>


    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,Position=0)]
        [ValidatePattern('^(http|https)')]
        [alias("vsmURL")]
        [System.URI]$vsm,
        
        [parameter(Position=1)]
        [alias("pg")]
        $portGroup,
        
        [parameter(Mandatory=$true,Position=2)]
        [alias("cred")]
        [System.Management.Automation.PSCredential]$credential = (get-credential),
        
        [parameter(Position=3)]
        [alias("path")]
        [String]$csvPath,
        
        [parameter(Mandatory=$false)]
        [switch]$noclobber
    )
    PROCESS
    {
        write-host "Beginning Set-vSERules..."
        
        if (!$csvPath)
        {
            write-host "Opening select File Dialog..."
            $csvPath = Select-FileDialog -Title "Select the rules file to import" -Directory "F:\" -Filter "CSV file (*.csv)|*.csv"
        }
        if (!$portGroup)
        {
            write-host "Getting dvPortgroup List..."
            $portGroups = Get-VirtualPortGroup -Distributed
            write-host "Opening dvPortgroup Selection Dialog..."
            $selected = Open-ListDialog ($portGroups | %{$_.name}) "Select a dvPortgroup" "Select a dvPortgroup:"
            $portGroup = $portGroups | where {$_.name -eq $selected}
        }
        
        if (!(Test-Path $csvPath)){throw "Something is wrong with your CSV path."}
        
        $fwRuleSet = @()
        if ($noclobber)
        {
            write-host "No Clobber Set."
            $fwRuleSet += Get-vSERules $vsm $portGroup $credential
        }
        
        write-host "Importing CSV..."
        $fwRuleSet += Import-Csv $csvPath
        
        write-host "Building XML..."
        $rulesXML = New-Object xml
        $vShieldEdgeConfig = $rulesXML.createElement("VShieldEdgeConfig")
        $firewallConfig = $rulesXML.createElement("FirewallConfig")
        $rulesXML.AppendChild($firewallConfig)
    
        foreach ($fwRule in $fwRuleSet)
        {
            # Create XML children
            $firewallRule = $rulesXML.createElement("FirewallRule")
            $protocol = $rulesXML.createElement("protocol")
            $sourceIpAddress = $rulesXML.createElement("sourceIpAddress")
            $sourcePort = $rulesXML.createElement("sourcePort")
            $destinationIpAddress = $rulesXML.createElement("destinationIpAddress")
            $destinationPort = $rulesXML.createElement("destinationPort")
            $direction = $rulesXML.createElement("direction")
            $action = $rulesXML.createElement("action")
            
            $protocol.InnerText = $fwRule.protocol
            $firewallRule.AppendChild($protocol)
            if ($fwRule.protocol -eq "icmp")
            {
                $icmpType = $rulesXML.CreateElement("icmpType")
                $icmpType.InnerText = "any"
                $firewallRule.AppendChild($icmpType)
            }
                        
            # Source IP
            if (!($fwRule.sEndIP) -or $fwRule.sStartIP -eq $fwRule.sEndIP)
            {
                $ipAddress = $rulesXML.createElement("ipAddress")
                # API bug http://communities.vmware.com/thread/305577
                if ($fwRule.sStartIP -eq "*")
                {
                    $ipAddress.InnerText = "any"
                }
                else
                {
                    $ipAddress.InnerText = $fwRule.sStartIP
                }
                $sourceIpAddress.appendChild($ipAddress)
            }
            else
            {
                $ipRange = $rulesXML.createElement("IpRange")
                $rangeStart = $rulesXML.createElement("rangeStart")
                $rangeEnd = $rulesXML.createElement("rangeEnd")
                $rangeStart.InnerText = $fwRule.sStartIP
                $rangeEnd.InnerText = $fwRule.sEndIP
                $ipRange.appendChild($rangeStart)
                $ipRange.appendChild($rangeEnd)
                $sourceIpAddress.appendChild($ipRange)
            }
            
            # Source Port
            if (!($fwRule.sEndPort) -or $fwRule.sStartPort -eq $fwRule.sEndPort)
            {
                $port = $rulesXML.createElement("port")
                $port.InnerText = $fwRule.sStartPort
                $sourcePort.appendChild($port)
            }
            else
            {
                $portRange = $rulesXML.createElement("PortRange")
                $rangeStart = $rulesXML.createElement("rangeStart")
                $rangeEnd = $rulesXML.createElement("rangeEnd")
                $rangeStart.InnerText = $fwRule.sStartPort
                $rangeEnd.InnerText = $fwRule.sEndPort
                $portRange.appendChild($rangeStart)
                $portRange.appendChild($rangeEnd)
                $sourcePort.appendChild($portRange)
            }
            
            # destination IP
            if (!($fwRule.dEndIP) -or $fwRule.dStartIP -eq $fwRule.dEndIP)
            {
                $ipAddress = $rulesXML.createElement("ipAddress")
                if ($fwRule.dStartIP -eq "*")
                {
                    $ipAddress.InnerText = "any"
                }
                else
                {
                    $ipAddress.InnerText = $fwRule.dStartIP
                }
                $destinationIpAddress.appendChild($ipAddress)
            }
            else
            {
                $ipRange = $rulesXML.createElement("IpRange")
                $rangeStart = $rulesXML.createElement("rangeStart")
                $rangeEnd = $rulesXML.createElement("rangeEnd")
                $rangeStart.InnerText = $fwRule.dStartIP
                $rangeEnd.InnerText = $fwRule.dEndIP
                $ipRange.appendChild($rangeStart)
                $ipRange.appendChild($rangeEnd)
                $destinationIpAddress.appendChild($ipRange)
            }
            
            # Destination Port
            if (!($fwRule.dEndPort) -or $fwRule.dStartPort -eq $fwRule.dEndPort)
            {
                $port = $rulesXML.createElement("port")
                $port.InnerText = $fwRule.dStartPort
                $destinationPort.appendChild($port)
            }
            else
            {
                $portRange = $rulesXML.createElement("PortRange")
                $rangeStart = $rulesXML.createElement("rangeStart")
                $rangeEnd = $rulesXML.createElement("rangeEnd")
                $rangeStart.InnerText = $fwRule.sStartPort
                $rangeEnd.InnerText = $fwRule.sEndPort
                $portRange.appendChild($rangeStart)
                $portRange.appendChild($rangeEnd)
                $destinationPort.appendChild($portRange)
            }
            

            $direction.InnerText = $fwRule.direction
            $action.InnerText = $fwRule.action
            
            $firewallRule.AppendChild($sourceIpAddress)
            $firewallRule.AppendChild($sourcePort)
            $firewallRule.AppendChild($destinationIpAddress)
            $firewallRule.AppendChild($destinationPort)
            $firewallRule.AppendChild($direction)
            $firewallRule.AppendChild($action)
            
            #leaving ICMP type as ANY right now...

            $firewallConfig.AppendChild($firewallRule)
            $vShieldEdgeConfig.AppendChild($firewallConfig)
            $rulesXML.AppendChild($vShieldEdgeConfig)
        }
        
        write-host "Connecting to vSM..."
        try
        {

            
            $request = [System.Net.WebRequest]::Create("$($vsm)/api/1.0/network/$($portGroup.key)/firewall/rules");
            $request.credentials = [System.Net.NetworkCredential]$credential
            $request.Method="POST"
            $xmlEnc = [System.Text.Encoding]::UTF8.GetBytes($rulesXML.InnerXML)
            $request.ContentType = "application/xml; charset=UTF-8"
            $request.ContentLength = $xmlEnc.length
            $requestStream = $request.GetRequestStream()
            $requestStream.write($xmlEnc, 0, $xmlEnc.Length)
            $requestStream.Close()
    
            $response = $request.GetResponse()
            $responseStream = $response.getResponseStream()
            $streamReader = new-object System.IO.StreamReader($responseStream)
            [string]$result = $streamReader.ReadtoEnd()
        }
        catch [Net.WebException]
        {
            return(write-host -ForegroundColor red $_.exception.message)
        }
        $streamReader.close()
        $response.close()
        
        return $result
    } 
}


###############################
# Select-FileDialog Function  #
# Created by Hugo Peeters     #
# http://www.peetersonline.nl #
###############################

function Select-FileDialog
{
	param([string]$Title,[string]$Directory,[string]$Filter="All Files (*.*)|*.*")
	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
	$objForm = New-Object System.Windows.Forms.OpenFileDialog
    $objForm.ShowHelp = $true
	$objForm.InitialDirectory = $Directory
	$objForm.Filter = $Filter
	$objForm.Title = $Title
	$Show = $objForm.ShowDialog()
	If ($Show -eq "OK")
	{
		Return $objForm.FileName
	}
	Else
	{
		Return $false
	}
}


###############################
# Open-ListDialog             #
#                             #
#                             #
###############################
function Open-ListDialog
{
    param
    (
        $list,
        [String]$formText,
        [String]$labelText
    )
    
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
    
    $objForm = New-Object System.Windows.Forms.Form 
    $objForm.Text = $formText
    $objForm.Size = New-Object System.Drawing.Size(300,200) 
    $objForm.StartPosition = "CenterScreen"

    $objForm.KeyPreview = $True
    $objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
        {$x=$objListBox.SelectedItem;$objForm.Close()}})
    $objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
        {$objForm.Close()}})

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Size(75,120)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = "OK"
    $OKButton.Add_Click({$x=$objListBox.SelectedItem;$objForm.Close()})
    $objForm.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Size(150,120)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = "Cancel"
    $CancelButton.Add_Click({$objForm.Close()})
    $objForm.Controls.Add($CancelButton)

    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(10,20) 
    $objLabel.Size = New-Object System.Drawing.Size(280,20) 
    $objLabel.Text = $labelText
    $objForm.Controls.Add($objLabel) 

    $objListBox = New-Object System.Windows.Forms.ListBox 
    $objListBox.Location = New-Object System.Drawing.Size(10,40) 
    $objListBox.Size = New-Object System.Drawing.Size(260,20) 
    $objListBox.Height = 80
    
    $list | ForEach-Object {[void] $objListBox.Items.Add($_)}

    $objForm.Controls.Add($objListBox) 

    $objForm.Topmost = $True

    $objForm.Add_Shown({$objForm.Activate()})
    [void] $objForm.ShowDialog()

    return $x
    
}