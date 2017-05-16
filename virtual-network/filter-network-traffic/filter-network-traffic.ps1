# Variables for common values
$rgName='MyResourceGroup'
$location='eastus'

# Create user object
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create a resource group.
New-AzureRmResourceGroup -Name $rgName -Location $location

# Create a virtual network, a front-end subnet, and a back-end subnet.
$fesubnet = New-AzureRmVirtualNetworkSubnetConfig -Name 'MySubnet-FrontEnd' -AddressPrefix 10.0.1.0/24
$besubnet = New-AzureRmVirtualNetworkSubnetConfig -Name 'MySubnet-BackEnd' -AddressPrefix 10.0.2.0/24

$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name MyVnet -AddressPrefix 10.0.0.0/16 `
  -Location $location -Subnet $fesubnet, $besubnet

# Create NSG rules to allow HTTP & HTTPS traffic inbound.
$rule1 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-HTTP-ALL -Description "Allow HTTP" `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
  -SourceAddressPrefix Internet -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 80

$rule2 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-HTTPS-All -Description "Allow HTTPS" `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 `
  -SourceAddressPrefix Internet -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 80

# Create an NSG rule to allow SSH traffic in from the Internet to the front-end subnet.
$rule3 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-SSH-All -Description "Allow SSH" `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 300 `
  -SourceAddressPrefix Internet -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 22

# Create a network security group (NSG) for the front-end subnet.
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RgName -Location $location `
  -Name "MyNsg-FrontEnd" -SecurityRules $rule1,$rule2,$rule3

# Associate the front-end NSG to the front-end subnet.
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name MySubnet-FrontEnd `
  -AddressPrefix 10.0.1.0/24 -NetworkSecurityGroup $nsg

# Create an NSG rule to block all outbound traffic from the back-end subnet to the Internet (inbound blocked by default).

$rule1 = New-AzureRmNetworkSecurityRuleConfig -Name Deny-Internet-All -Description "Deny all Internet" `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
  -SourceAddressPrefix Internet -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange *

# Create a network security group for the back-end subnet.
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RgName -Location $location `
  -Name "MyNsg-BackEnd" -SecurityRules $rule1

# Associate the back-end NSG to the back-end subnet.
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'MySubnet-backEnd' `
  -AddressPrefix 10.0.2.0/24 -NetworkSecurityGroup $nsg

# Create a public IP address for the VM front-end network interface.
$publicipvm = New-AzureRmPublicIpAddress -ResourceGroupName $rgName -Name 'MyPublicIp-FrontEnd' `
  -location $location -AllocationMethod Dynamic

# Create a network interface for the VM attached to the front-end subnet.
$nicVMfe = New-AzureRmNetworkInterface -ResourceGroupName $rgName -Location $location `
  -Name MyNic-FrontEnd -PublicIpAddress $publicipvm -Subnet $vnet.Subnets[0]

# Create a network interface for the VM attached to the back-end subnet.
$nicVMbe = New-AzureRmNetworkInterface -ResourceGroupName $rgName -Location $location `
  -Name MyNic-BackEnd -Subnet $vnet.Subnets[1]

# Create the VM with both the FrontEnd and BackEnd NICs.
$vmConfig = New-AzureRmVMConfig -VMName myVM2 -VMSize Standard_DS2 | `
  Set-AzureRmVMOperatingSystem -Windows -ComputerName myVM2 -Credential $cred | `
  Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
  -Skus 2016-Datacenter -Version latest
    
$vmconfig = Add-AzureRmVMNetworkInterface -VM $vmConfig -id $nicVMfe.Id -Primary
$vmconfig = Add-AzureRmVMNetworkInterface -VM $vmConfig -id $nicVMbe.Id

# Create a virtual machine
$vm = New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vmConfig
