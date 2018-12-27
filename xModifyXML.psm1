# Not production ready
# Find "to-do" comments below

Enum Ensure
{
    Absent
    Present
}

Enum NodeXPathItems
{
    IsElement
    IsAttribute
    #PredicateExpression
    PredicateParentElement
    PredicateTargetElement
    PredicateTargetAttribute
    PredicateValue
}

[DscResource()]
Class xXmlNode
{
    [DscProperty(Key)]
    [String] $XPath

    [DscProperty(Mandatory)]
    [String] $FilePath

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty()]
    [String] $Value
    
    [xXmlNode] Get()
    {
        If ( $This.Test() -eq $True )
        { $This.Ensure = [Ensure]::Present }
        Else
        { $This.Ensure = [Ensure]::Absent }

        Return $This
    }

    [bool] Test()
    {
        [Array] $Nodes = Get-XmlNode -FilePath $This.FilePath -XPath $This.XPath
            
        If ( $This.Ensure -eq [Ensure]::Present )
        {
            If ( $Nodes.Count -eq 0 )
            { Return $false }
            Else
            {
                If ( $This.Value )
                {
                    ForEach ( $Node in $Nodes )
                    {
                        If (( $Node -is [System.Xml.XmlElement] ) -and ( $Node.InnerXml -ne $This.Value ))
                        { Return $false }
                        ElseIf (( $Node -is [System.Xml.XmlAttribute] ) -and ( $Node.Value -ne $This.Value ))
                        { Return $false }
                        ElseIf (( $Node -isnot [System.Xml.XmlElement] ) -and ( $Node -isnot [System.Xml.XmlAttribute] ))
                        {
                            Write-Error "Unhandled node type: $( $Node.GetType().ToString() )"
                            Return $false
                        }
                        Else
                        { Return $false }
                    }
                }
            }
        }
        Else
        {
            If ( $Nodes.Count -gt 0 )
            { Return $false }
            Else
            { Return $true }
        }

        Return $true
    }

    [void] Set()
    {
        If ( $This.Ensure -eq [Ensure]::Present )
        {
            If ( $This.Value )
            {
                Set-XmlNode -FilePath $This.FilePath -XPath $This.XPath -Value $This.Value
            }
            Else
            {
                Set-XmlNode -FilePath $This.FilePath -XPath $This.XPath
            }
        }
        ElseIf ( $This.Ensure -eq [Ensure]::Absent )
        {
            If ( $This.Value )
            {
                Remove-XmlNode -FilePath $This.FilePath -XPath $This.XPath -Value $This.Value
            }
            Else
            {
                Remove-XmlNode -FilePath $This.FilePath -XPath $This.XPath
            }
        }
    }
}

Function Get-XPathItem
{
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory = $True )]
        [String]
        $NodeXPath,

        [Parameter( Mandatory = $True )]
        [NodeXPathItems]
        $Item
    )

    [RegEx]::Matches( $NodeXPath, $Global:XmlNode_RegEx[$Item.ToString()] ).Value
}

Function Get-XPathItemTypes
{
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory = $True )]
        [String]
        $NodeXPath
    )

    $ItemTypes = New-Object -TypeName System.Collections.ArrayList

    ForEach ( $Type in $Global:XmlNode_RegEx.GetEnumerator() )
    {
        If ( $NodeXPath -match $Type.Value )
        {
            $ItemTypes.Add( $Type.Key ) | Out-Null
        }
    }

    Return $ItemTypes
}

Function Get-PredicateState
{
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory = $True )]
        [System.Xml.XmlDocument]
        $XmlDocument,

        [Parameter( Mandatory = $True )]
        [String]
        $ParentXPath,

        [String]
        $ChildName
    )

    $Parents = $XmlDocument.SelectNodes( $ParentXPath )

    If (( $Parents |
        Where-Object {
            ( $_.HasChildNodes -eq $false ) -and # Has no children nodes
            ( $_.HasAttributes -eq $false )      # Has no attributes
        }
    )) # Current node exists and is empty
    {
        Return 'EmptyElement'
    }
    ElseIf (( $Parents |
        Where-Object {
            ( $_.HasChildNodes      -eq $false                  ) -and # Has no children nodes
            ( $_.Attributes.Count   -eq 1                       ) -and # Has only one attribute
            ( $_.Attributes[0].Name -eq $ChildName              ) -and # Is the attribute we're looking for
            ( [String]::IsNullOrEmpty( $_.Attributes[0].Value ) )      # Attribute is empty
        }
    )) # Current node and attribute exist
    {
        Return 'EmptyAttributeValue'
    }
    ElseIf (( $Parents |
        Where-Object {
            ( $_.HasChildNodes               -eq $true      ) -and # Has children nodes
            ( $_.ChildNodes.Count            -eq 1          ) -and # Has only one child element
            ( $_.ChildNodes[0].HasAttributes -eq $false     ) -and # Has no children attributes
            ( $_.ChildNodes[0].HasChildNodes -eq $false     ) -and # Has no children nodes
            ( $_.ChildNodes[0].Name          -eq $ChildName ) -and # Is the element we're looking for
            ( $_.ChildNodes[0].IsEmpty       -eq $null      )      # Child element is empty
        }
    )) # Current element and child element exist
    {
        Return 'EmptyElementValue'
    }
    Else
    {
        Return 'None'
    }
}

Function New-XmlNode
{
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory = $True )]
        [System.Xml.XmlDocument]
        $XmlDocument,

        [Parameter( Mandatory = $True )]
        [System.Xml.XmlNodeType]
        $NodeType,

        [Parameter( Mandatory = $True )]
        [String]
        $NodeName,

        [Parameter( Mandatory = $True )]
        [String]
        $ParentXPath
    )

    Switch ( $NodeType )
    {
        Element
        {
            $XmlDocument.SelectNodes( $ParentXPath ) | ForEach-Object {
                Write-Verbose "Create Element `"$( $_.Name )`""
                $NewNode = $XmlDocument.CreateNode( $NodeType, $NodeName, $Null )
                $_.AppendChild( $NewNode ) | Out-Null
            }
        }
        Attribute
        {
            $XmlDocument.SelectNodes( $ParentXPath ) | ForEach-Object {
                Write-Verbose "Create Attribute `"$( $_.Name )`""
                $NewNode = $XmlDocument.CreateNode( $NodeType, $NodeName, $Null )
                $_.SetAttributeNode( $NewNode ) | Out-Null
            }
        }
        Default
        {
            Write-Warning "Unhandled XML node type: $NodeType"
        }
    }
}

Function Set-XmlNodeValue
{
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory = $True )]
        #[System.Xml.XmlElement]
        #[System.Xml.XmlAttribute]
        $Node,

        [Parameter( Mandatory = $True )]
        [String]
        $Value
    )

    Switch ( $Node.GetType().ToString() )
    {
        System.Xml.XmlElement
        {
            Write-Verbose "Set Element `"$( $Node.Name )`" to `"$Value`""
            $Node.InnerXml = $Value
        }
        System.Xml.XmlAttribute
        {
            Write-Verbose "Set Attribute `"$( $Node.Name )`" to `"$Value`""
            $Node.Value = $Value
        }
        Default
        {
            Write-Warning "Unhandled node type: $( $_.GetType() )"
        }
    }
}

Function Add-XmlNode
{
    # Create XML nodes to ensure provided XPath exists
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory = $True,
                    ParameterSetName = "XmlFile" )]
        [System.String]
        $FilePath,

        [Parameter( Mandatory = $True,
                    ParameterSetName = "XmlObject" )]
        [System.Xml.XmlDocument]
        $XmlDocument,

        [Parameter( Mandatory = $True )]
        [System.String]
        $XPath,

        [Switch]
        $Force,

        [Switch]
        $NoSave
    )
    
    Switch ( $PSCmdlet.ParameterSetName )
    {
        XmlFile
        {
            $XmlDocument = New-Object -TypeName System.Xml.XmlDocument
            $XmlDocument.Load( $FilePath )
        }
        XmlObject
        {
            # Nothing to do here
        }
    }

    # Create nodes (and ancestor nodes) if not present
    $NodeNames = $XPath -Split('/') | Where-Object { $_ }
    $NodeIndex = 0

    ForEach ( $NodeName in $NodeNames )
    {
        $NodePath = "/" + ( $NodeNames[0..$NodeIndex] -join '/' )
        $NodeList = $XmlDocument.SelectNodes( $NodePath )

        If (( $Force -eq $True ) -and ( $NodeList.Count -eq 0 ))
        {
            # Get info about parent node
            $ParentIndex = [System.Math]::Max( 0, ( $NodeIndex - 1 ) )
            $ParentPath  = "/$( $NodeNames[0..$ParentIndex] -join '/' )"

            # Set new node's parameters
            Switch ( Get-XPathItemTypes -NodeXPath $NodeName )
            {
                IsElement
                {
                    $ElementPath = $ParentPath, $NodeName -join '/'
                    $NodeList    = $XmlDocument.SelectNodes( $ElementPath )
                    $NodeParams  = @{
                        XmlDocument = $XmlDocument
                        NodeType    = [System.Xml.XmlNodeType]::Element
                        NodeName    = $NodeName
                        ParentXPath = $ParentPath
                    }

                    New-XmlNode @NodeParams
                    Continue
                }
                IsAttribute
                {
                    $NodeParams = @{
                         XmlDocument = $XmlDocument
                         NodeType    = [System.Xml.XmlNodeType]::Attribute
                         NodeName    = $NodeName -replace '@'
                         ParentXPath = $ParentPath
                    }

                    New-XmlNode @NodeParams
                    Continue
                }
                PredicateParentElement
                {
                    $ElementName = Get-XPathItem -NodeXPath $NodeName -Item PredicateParentElement
                    $ElementPath = $ParentPath, $ElementName -join '/'
                    $Elements    = $XmlDocument.SelectNodes( $ElementPath )
                    $StateParams = @{
                        XmlDocument = $XmlDocument
                        ParentXPath = $ParentPath
                        ChildName   = $ElementName
                    }
                    
                    Switch ( Get-PredicateState @StateParams )
                    {
                        EmptyElement
                        {
                            Continue
                        }
                        None
                        {
                            $NodeParams = @{
                                XmlDocument = $XmlDocument
                                NodeType    = [System.Xml.XmlNodeType]::Element
                                NodeName    = $ElementName
                                ParentXPath = $ParentPath
                            }

                            New-XmlNode @NodeParams
                        }
                    }
                }
                PredicateTargetElement
                {
                    # to-do: not tested; copied from case above; needs values changed
                    $ParentName  = Get-XPathItem -NodeXPath $NodeName -Item PredicateParentElement
                    $ElementName = Get-XPathItem -NodeXPath $NodeName -Item PredicateTargetElement
                    $ElementPath = $ParentPath, $ParentName, $ElementName -join '/'
                    $Elements    = $XmlDocument.SelectNodes( $ElementPath )
                    $StateParams = @{
                        XmlDocument = $XmlDocument
                        ParentXPath = $ParentPath, $ParentName -join '/'
                        ChildName   = $ElementName
                    }
                    
                    Switch ( Get-PredicateState @StateParams )
                    {
                        EmptyElement
                        {
                            Continue
                        }
                        None
                        {
                            $NodeParams = @{
                                XmlDocument = $XmlDocument
                                NodeType    = [System.Xml.XmlNodeType]::Element
                                NodeName    = $ElementName
                                ParentXPath = $ParentPath, $ParentName -join '/'
                            }

                            New-XmlNode @NodeParams
                        }
                    }
                }
                PredicateTargetAttribute
                {
                    # to-do: not tested; copied from case above; needs values changed
                    $ParentName     = Get-XPathItem -NodeXPath $NodeName -Item PredicateParentElement
                    $AttributeName  = Get-XPathItem -NodeXPath $NodeName -Item PredicateTargetAttribute
                    $AttributePath  = $ParentPath, $ParentName, "@$AttributeName" -join '/'
                    $Attributes     = $XmlDocument.SelectNodes( $AttributePath )
                    $PredicateState = Get-PredicateState -XmlDocument $XmlDocument -XPath $AttributePath

                    Switch ( $PredicateState )
                    {
                        Attribute
                        {
                            $NodeParams = @{
                                XmlDocument = $XmlDocument
                                NodeType    = [System.Xml.XmlNodeType]::Attribute
                                NodeName    = $AttributeName
                                ParentXPath = $ParentPath, $ParentName -join '/'
                            }

                            New-XmlNode @NodeParams
                        }
                    }
                }
                PredicateValue
                {
                    # to-do: not tested; copied from case above; needs values changed
                    $ParentName     = Get-XPathItem -NodeXPath $NodeName -Item PredicateParentElement
                    $AttributeName  = Get-XPathItem -NodeXPath $NodeName -Item PredicateTargetAttribute
                    $AttributeValue = Get-XPathItem -NodeXPath $NodeName -Item PredicateValue
                    $AttributePath  = $ParentPath, $ParentName, "@$AttributeName" -join '/'
                    $PredicateState = Get-PredicateState -XmlDocument $XmlDocument -XPath $AttributePath

                    If ( $PredicateState -contains 'Value' )
                    {
                        $NodeList = $XmlDocument.SelectNodes( $AttributePath )
                        $NodeList | ForEach-Object { Set-XmlNodeValue -Node $_ -Value $AttributeValue }
                    }
                }
            }
        }
        ElseIf (( $Force = $False ) -and ( $NodeList.Count -eq 0 ))
        {
            Write-Warning "XPath matched no nodes: $NodePath"
            Write-Verbose "Use -Force to create nodes if they don't exist" -Verbose
            Return
        }
        Else
        {
            Write-Verbose "Skip existing XPath: $NodePath"
        }
        
        $NodeIndex++
    } # End ForEach (NodeNames)

    If ( $FilePath -and $NoSave )
    {
        # Don't save to file
    }
    ElseIf ( $FilePath )
    {
        Write-Verbose "Save XML to file: $FilePath"
        $XmlDocument.Save( $FilePath )
    }
}

Function Set-XmlNode
{
    # Create or modify XML node from provided XPath
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory = $True,
                    ParameterSetName = "XmlFile" )]
        [System.String]
        $FilePath,

        [Parameter( Mandatory = $True,
                    ParameterSetName = "XmlObject" )]
        [System.Xml.XmlDocument]
        $XmlDocument,

        [Parameter( Mandatory = $True )]
        [System.String]
        $XPath,

        [Parameter( Mandatory = $True )]
        [System.String]
        $Value,

        [Switch]
        $Force
    )

    Switch ( $PSCmdlet.ParameterSetName )
    {
        XmlFile
        {
            $XmlDocument = New-Object -TypeName System.Xml.XmlDocument
            $XmlDocument.Load( $FilePath )
        }
        XmlObject
        {
            # Nothing to do here
        }
    }

    $NodeList = $XmlDocument.SelectNodes( $XPath )

    If (( $Force -eq $True ) -and ( $NodeList.Count -eq 0 ))
    {
        $NodeParams =
        @{
            XmlDocument = $XmlDocument
            XPath       = $XPath
            Force       = $Force
            NoSave      = $True
            #Value       = $Value
        }

        Add-XmlNode @NodeParams
        
        $NodeList = $XmlDocument.SelectNodes( $XPath )
    } # End If ($Force and no nodes exist)
    ElseIf  (( $Force -eq $False ) -and ( $NodeList.Count -eq 0 ))
    {
        Write-Warning "XPath matched no nodes: $NodePath"
        Write-Verbose "Use -Force to create nodes if they don't exist" -Verbose
        Return
    }
    
    $NodeList | ForEach-Object {

        $NodeParams = @{
            Node  = $_
            value = $Value
        }

        Set-XmlNodeValue @NodeParams
    }

    If ( $FilePath )
    {
        Write-Verbose "Save XML to file: $FilePath"
        $XmlDocument.Save( $FilePath )
    }
}

Function Get-XmlNode
{
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory = $True,
                    ParameterSetName = "XmlFile" )]
        [System.String]
        $FilePath,

        [Parameter( Mandatory = $True,
                    ParameterSetName = "XmlObject" )]
        [System.Xml.XmlDocument]
        $XmlDocument,

        [Parameter( Mandatory = $True )]
        [System.String]
        $XPath
    )

    Switch ( $PSCmdlet.ParameterSetName )
    {
        XmlFile
        {
            $XmlDocument = New-Object -TypeName System.Xml.XmlDocument
            $XmlDocument.Load( $FilePath )
        }
        XmlObject
        {
            # Nothing to do here
        }
    }

    $NodeList = $XmlDocument.SelectNodes( $XPath )

    If ( $NodeList.Count -eq 0 )
    {
        Write-Warning "XPath matched no nodes: $XPath"
    }
    Else
    {
        ForEach ( $Node in $NodeList )
        {
            $Node
        }
    }
}

Function Remove-XmlNode
{
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory = $True,
                    ParameterSetName = "XmlFile" )]
        [System.String]
        $FilePath,

        [Parameter( Mandatory = $True,
                    ParameterSetName = "XmlObject" )]
        [System.Xml.XmlDocument]
        $XmlDocument,

        [Parameter( Mandatory = $True )]
        [System.String]
        $XPath
    )

    Switch ( $PSCmdlet.ParameterSetName )
    {
        XmlFile
        {
            $XmlDocument = New-Object -TypeName System.Xml.XmlDocument
            $XmlDocument.Load( $FilePath )
        }
        XmlObject
        {
            # Nothing to do here
        }
    }

    $NodeList = $XmlDocument.SelectNodes( $XPath )

    If ( $NodeList.Count -eq 0 )
    {
        Write-Warning "XPath matched no nodes: $XPath"
    }
    Else
    {
        ForEach ( $Node in $NodeList )
        {
            Switch ( $Node.GetType().ToString() )
            {
                System.Xml.XmlElement
                {
                    Write-Verbose "Remove Element `"$Node`""
                    $Node.ParentNode.RemoveChild( $Node )
                }
                System.Xml.XmlAttribute
                {
                    Write-Verbose "Remove Attribute `"$( $Node.Name )`""
                    $Node.OwnerElement.RemoveAttribute( $Node.Name )
                }
                Default
                {
                    Write-Warning "Unhandled node type: $( $Node.GetType() )"
                }
            }
        }
    }

    If ( $FilePath )
    {
        Write-Verbose "Save XML to file: $FilePath"
        $XmlDocument.Save( $FilePath )
    }
}

$Global:XmlNode_ValidName = "[A-Za-z][A-Za-z0-9_.:\-]"
$Global:XmlNode_RegEx =
@{
    IsElement                = "(?<=^)$Global:XmlNode_ValidName*$"
    IsAttribute              = "(?<=^@)$Global:XmlNode_ValidName*$"
    #PredicateExpression      = "\[[^]]+\]"
    PredicateParentElement   = "^[^@]$Global:XmlNode_ValidName*(?=\[)"
    PredicateTargetElement   = "(?<=\[)$Global:XmlNode_ValidName*"
    PredicateTargetAttribute = "(?<=\[@)$Global:XmlNode_ValidName*"
    PredicateValue           = "(?<==['`"]).+(?=['`"]\])"
}

Export-ModuleMember -Function Get-XmlNode,
                              Set-XmlNode,
                              Add-XmlNode,
                              Remove-XmlNode