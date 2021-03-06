# jmeter-cluster

ARM Template to deploy an Apache JMeter Cluster in Azure

This template was created based on [elasticsearch-jmeter in Azure/azure-quickstart-templates](https://github.com/Azure/azure-quickstart-templates/tree/master/elasticsearch-jmeter)

This template will deploy a JMeter environment into a new virtual network. One master node and multiple subordinate nodes are deployed into a new subnet called jmeter, with the address prefix 10.0.4.0/24.

## Instructions

To deploy, you must have an existing Virtual Network deployed

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Froberto-mardeni%2Fjmeter-cluster%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Froberto-mardeni%2Fjmeter-cluster%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>
