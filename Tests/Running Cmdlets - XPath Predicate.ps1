Import-Module ".\xModifyXML.psm1"

$Params = @{
    FilePath = ".\Web.config"
    XPath    = "/configuration/system.webServer/modules/elem[@attr='a']/@id"
    Verbose  = $True
    ErrorAction = 'Stop'
}

Get-XmlNode @Params
Add-XmlNode @Params -Force
Set-XmlNode @Params -Force -Value 'ValueName'
Remove-XmlNode @Params
