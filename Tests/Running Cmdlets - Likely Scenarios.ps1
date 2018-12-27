Import-Module "C:\Users\Greg\Documents\GIT\greg-powershell\Desired State Configuration\xModifyXML\xModifyXML.psm1" -Force

$CommonParams = @{
    FilePath    = Get-ChildItem "C:\Users\Greg\Documents\GIT\greg-powershell\Desired State Configuration\xModifyXML\Tests\Test.xml"
    Force       = $True
    ErrorAction = 'Stop'
    Verbose     = $True
}

# Element
Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/sideElem"
Set-XmlNode @CommonParams -XPath "/rootElem/parent.elem1/parent-elem2/sideElem2" -Value "Some Text"
(Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/sideElem2").'#text' -eq "Some Text"

# Attribute
Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/sideElem/@name"
Set-XmlNode @CommonParams -XPath "/rootElem/parent.elem1/parent-elem2/sideElem/@name" -Value "zero"
(Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/sideElem/@name").'#text' -eq "zero"

# PredicateParentElement[*]
Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/elem/subElem[@name]"
Set-XmlNode @CommonParams -XPath "/rootElem/parent.elem1/parent-elem2/elem/subElem[@name]" -Value "seven"
(Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/elem/subElem[@name]").'#text' -eq "seven"

# @PredicateParentAttribute[*]
## I don't think this is possible, skipping for now
#Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/@elem[*]"
#Set-XmlNode @CommonParams -XPath "/rootElem/parent.elem1/parent-elem2/@elem2Attr[sideElem]" -Value "Value"

# *[PredicateTargetElement=*]
Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/elem[subElem]"
Set-XmlNode @CommonParams -XPath "/rootElem/parent.elem1/parent-elem2/elem[subElem2]/@name" -Value "five"
(Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/elem[subElem]").'#text' -eq "five" # STILL FALSE

# *[@PredicateTargetAttribute=*]
Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/elem[@color]"
Set-XmlNode @CommonParams -XPath "/rootElem/parent.elem1/parent-elem2/elem[@color]/@name" -Value "!" # SKIPS ALL
(Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/elem[@color]").'#text' | %{ $_ -eq "!" }

# *[*='PredicateValue']
Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/elem[@attr='a']"
Set-XmlNode @CommonParams -XPath "/rootElem/parent.elem1/parent-elem2/elem[@attr='a']/@name" -Value "one"
(Get-XmlNode -FilePath $CommonParams.FilePath -XPath "/rootElem/parent.elem1/parent-elem2/elem[@attr='a']") -eq "!"
