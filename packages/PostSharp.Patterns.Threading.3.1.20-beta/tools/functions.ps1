﻿
function PathToUri([string] $path)
{
    return new-object Uri('file://' + $path.Replace("%","%25").Replace("#","%23").Replace("$","%24").Replace("+","%2B").Replace(",","%2C").Replace("=","%3D").Replace("@","%40").Replace("~","%7E").Replace("^","%5E"))
}

function UriToPath([System.Uri] $uri)
{
    return [System.Uri]::UnescapeDataString( $uri.ToString() ).Replace([System.IO.Path]::AltDirectorySeparatorChar, [System.IO.Path]::DirectorySeparatorChar)
}

function GetPostSharpProject($project, [bool] $create)
{
	$xml = [xml] @"
<?xml version="1.0" encoding="utf-8"?>
<Project xmlns="http://schemas.postsharp.org/1.0/configuration">
</Project>
"@

	$projectName = $project.Name
	
	# Set the psproj name to be the Project's name, i.e. 'ConsoleApplication1.psproj'
	$psprojectName = $project.Name + ".psproj"

	# Check if the file previously existed in the project
	$psproj = $project.ProjectItems | where { $_.Name -eq $psprojectName }

	# If this item already exists, load it
	if ($psproj)
	{
	  $psprojectFile = $psproj.Properties.Item("FullPath").Value
	  
	  Write-Host "Opening existing file $psprojectFile"
	  
	  $xml = [xml](Get-Content $psprojectFile)
	} 
	elseif ( $create )
	{
		# Create a file on disk, write XML, and load it into the project.
		$psprojectFile = [System.IO.Path]::ChangeExtension($project.FileName, ".psproj")
		
		Write-Host "Creating file $psprojectFile"
		
		$xml.Save($psprojectFile)
		$project.ProjectItems.AddFromFile($psprojectFile) | Out-Null
		
	}
	else
	{
		Write-Host "$psprojectName not found."
		return $null
	}
	
	return [hashtable] @{ Content = [xml] $xml; FileName = [string] $psprojectFile } 
}

function AddUsing($psproj, [string] $path)
{
	$xml = $psproj.Content
	$originPath = $psproj.FileName
	
	# Make the path to the targets file relative.
	$projectUri = PathToUri $originPath
	$targetUri = PathToUri $path
	$relativePath = UriToPath $projectUri.MakeRelativeUri($targetUri)
    $shortFileName = '*' + [System.IO.Path]::GetFileNameWithoutExtension($path) + '*'
	$PatternsWeaver = $xml.Project.Using | where { $_.File -like $shortFileName}
	
	if ($PatternsWeaver)
	{
		Write-Host "Updating the Using element to $relativePath"
	
		$PatternsWeaver.SetAttribute("File", $relativePath)
	} 
	else 
	{
		Write-Host "Adding a Using element to $relativePath"
	

		$PatternsWeaver = $xml.CreateElement("Using", "http://schemas.postsharp.org/1.0/configuration")
		$PatternsWeaver.SetAttribute("File", $relativePath)

		$previousElement = $xml.Project.Using | Select -Last 1


        if (!$previousElement)
        {
            $previousElement = $xml.Project.SearchPath | Select -Last 1
        }

        if (!$previousElement)
        {
            $previousElement = $xml.Project.Property | Select -Last 1
        }
        
        if ( $previousElement )
        {
        	$xml.Project.InsertAfter($PatternsWeaver, $previousElement)
        }
        else
        {
            $xml.Project.PrependChild($PatternsWeaver)
        }
	}

}

function RemoveUsing($psproj, [string] $path)
{
	$xml = $psproj.Content
	
	Write-Host "Removing the Using element to $path"
	
	$shortFileName = '*' + [System.IO.Path]::GetFileNameWithoutExtension($path) + '*'
		$xml.Project.Using | where { $_.File -like $shortFileName } | foreach {
	  $_.ParentNode.RemoveChild($_)
	}
}

function SetProperty($psproj, [string] $propertyName, [string] $propertyValue, [string] $compareValue )
{
	$xml = $psproj.Content
	
	$firstUsing = $xml.Project.Using | Select-Object -First 1

	$property = $xml.Project.Property | where { $_.Name -eq $propertyName }
	if (!$property -and !$compareValue )
	{
		Write-Host "Creating property $propertyName='$propertyValue'."
	    
		$property = $xml.CreateElement("Property", "http://schemas.postsharp.org/1.0/configuration")
		$property.SetAttribute("Name", $propertyName)
		$property.SetAttribute("Value", $propertyValue)
	 	$xml.Project.InsertBefore($property, $firstUsing)
	}
	elseif ( !$compareValue -or $compareValue -eq $property.GetAttribute("Value") )
	{
		Write-Host "Updating property $propertyName='$propertyValue'."
		
		$property.SetAttribute("Value", $propertyValue)
	}

	
}

function Save($psproj)
{
	$filename = $psproj.FileName
	
	Write-Host "Saving file $filename"

	$xml = $psproj.Content
    $xml.Save($psproj.FileName)
}

function CommentOut([System.Xml.XmlNode] $xml)
{
	Write-Host "Commenting out $xml"
	$fragment = $xml.OwnerDocument.CreateDocumentFragment()
	$fragment.InnerXml = "<!--" + $xml.OuterXml + "-->"
	$xml.ParentNode.InsertAfter( $fragment, $xml )
	$xml.ParentNode.RemoveChild( $xml )
}

# SIG # Begin signature block
# MIId/AYJKoZIhvcNAQcCoIId7TCCHekCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQULTLPHPhNo+H+Xuj9XEI79HMU
# m5qgghjsMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggTTMIIDu6ADAgECAhAY2tGeJn3ou0ohWM3MaztKMA0GCSqGSIb3DQEBBQUAMIHK
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsT
# FlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOjA4BgNVBAsTMShjKSAyMDA2IFZlcmlT
# aWduLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxRTBDBgNVBAMTPFZl
# cmlTaWduIENsYXNzIDMgUHVibGljIFByaW1hcnkgQ2VydGlmaWNhdGlvbiBBdXRo
# b3JpdHkgLSBHNTAeFw0wNjExMDgwMDAwMDBaFw0zNjA3MTYyMzU5NTlaMIHKMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZl
# cmlTaWduIFRydXN0IE5ldHdvcmsxOjA4BgNVBAsTMShjKSAyMDA2IFZlcmlTaWdu
# LCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxRTBDBgNVBAMTPFZlcmlT
# aWduIENsYXNzIDMgUHVibGljIFByaW1hcnkgQ2VydGlmaWNhdGlvbiBBdXRob3Jp
# dHkgLSBHNTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK8kCAgpejWe
# YAyq50s7Ttx8vDxFHLsr4P4pAvlXCKNkhRUn9fGtyDGJXSLoKqqmQrOP+LlVt7G3
# S7P+j34HV+zvQ9tmYhVhz2ANpNje+ODDYgg9VBPrScpZVIUm5SuPG5/r9aGRwjNJ
# 2ENjalJL0o/ocFFN0Ylpe8dw9rPcEnTbe11LVtOWvxV3obD0oiXyrxySZxjl9AYE
# 75C55ADk3Tq1Gf8CuvQ87uCL6zeL7PTXrPL28D2v3XWRMxkdHEDLdCQZIZPZFP6s
# KlLHj9UESeSNY0eIPGmDy/5HvSt+T8WVrg6d1NFDwGdz4xQIfuU/n3O4MwrPXT80
# h5aK7lPoJRUCAwEAAaOBsjCBrzAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQE
# AwIBBjBtBggrBgEFBQcBDARhMF+hXaBbMFkwVzBVFglpbWFnZS9naWYwITAfMAcG
# BSsOAwIaBBSP5dMahqyNjmvDz4Bq1EgYLHsZLjAlFiNodHRwOi8vbG9nby52ZXJp
# c2lnbi5jb20vdnNsb2dvLmdpZjAdBgNVHQ4EFgQUf9Nlp8Ld7LvwMAnzQzn6Aq8z
# MTMwDQYJKoZIhvcNAQEFBQADggEBAJMkSjBfYs/YGpgvPercmS29d/aleSI47MSn
# oHgSrWIORXBkxeeXZi2YCX5fr9bMKGXyAaoIGkfe+fl8kloIaSAN2T5tbjwNbtjm
# BpFAGLn4we3f20Gq4JYgyc1kFTiByZTuooQpCxNvjtsM3SUC26SLGUTSQXoFaUpY
# T2DKfoJqCwKqJRc5tdt/54RlKpWKvYbeXoEWgy0QzN79qIIqbSgfDQvE5ecaJhnh
# 9BFvELWV/OdCBTLbzp1RXii2noXTW++lfUVAco63DmsOBvszNUhxuJ0ni8RlXw2G
# dpxEevaVXPZdMggzpFS2GD9oXPJCSoU4VINf0egs8qwR1qjtY2owggVqMIIEUqAD
# AgECAhAMtnr7s7inKYYI4A6UzzU+MA0GCSqGSIb3DQEBBQUAMIG0MQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWdu
# IFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBhdCBodHRwczov
# L3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVWZXJpU2lnbiBD
# bGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBMB4XDTExMDYyNDAwMDAwMFoXDTE0
# MDcwMzIzNTk1OVowga0xCzAJBgNVBAYTAkNaMQ8wDQYDVQQIEwZQcmFndWUxDzAN
# BgNVBAcTBlByYWd1ZTEdMBsGA1UEChQUU2hhcnBDcmFmdGVycyBzLnIuby4xPjA8
# BgNVBAsTNURpZ2l0YWwgSUQgQ2xhc3MgMyAtIE1pY3Jvc29mdCBTb2Z0d2FyZSBW
# YWxpZGF0aW9uIHYyMR0wGwYDVQQDFBRTaGFycENyYWZ0ZXJzIHMuci5vLjCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK0A6khiBRSzjcckXo8lVbY/TcZH
# K/LT5Gwkg7EyyiBivHnIRsuVNazEu8ka9ZmVHNH+8V0vTlRu9irToZVkOW0TqVc0
# KJxDa9Om32J5aauQ0VWBI13EI4Rzx7x+X6lZv65w7N11bdHjSwOdVZqNIwAH6YvF
# gUa1j8MOKYKTcPUb7Pr6slRRqvWNJaSzc5sKDo2u3ztoM6Mi8ZOLTvlIi2WAu9AO
# JrbJLnIS/SPbgL+A3s1Mt/GquVs3vocaHLg3/6Aol4XKmI/YFcOASD72b9ZfpVTg
# hd61qnQ9IXwtjHCDAkMHIxnyk/hUfXN2W+5EFt0AvGN7j+AY8wW8yoJM5o8CAwEA
# AaOCAXswggF3MAkGA1UdEwQCMAAwDgYDVR0PAQH/BAQDAgeAMEAGA1UdHwQ5MDcw
# NaAzoDGGL2h0dHA6Ly9jc2MzLTIwMTAtY3JsLnZlcmlzaWduLmNvbS9DU0MzLTIw
# MTAuY3JsMEQGA1UdIAQ9MDswOQYLYIZIAYb4RQEHFwMwKjAoBggrBgEFBQcCARYc
# aHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYTATBgNVHSUEDDAKBggrBgEFBQcD
# AzBxBggrBgEFBQcBAQRlMGMwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLnZlcmlz
# aWduLmNvbTA7BggrBgEFBQcwAoYvaHR0cDovL2NzYzMtMjAxMC1haWEudmVyaXNp
# Z24uY29tL0NTQzMtMjAxMC5jZXIwHwYDVR0jBBgwFoAUz5mp6nsm9EvJjo/X8AUm
# 7+PSp50wEQYJYIZIAYb4QgEBBAQDAgQQMBYGCisGAQQBgjcCARsECDAGAQEAAQH/
# MA0GCSqGSIb3DQEBBQUAA4IBAQBy6KC5DX/wo55ppitx2h/f8UxWmNsHvvArhQKQ
# zSfYtQYQ8fueV3FYaC/9vkd1Ard35A3AsT1UpLueZ4NVXA4ltqKeXM5F6e+hPWe5
# nc5zkDr8WFrLqjsPjXc9HiHpoQm+yZ9Lnc/wkA+eHvrLp+Dml5XJWOvbzHf9vWLz
# SiEaqI2miA6yzNcSZmALzaner1j3AjaMU8Omr0UvsIpJwoJVDFWopNzCJG7ovJwh
# ajBy1mthHS/l1pOoWa2D/GffHmseDgltdlwjVZ3EnUQ4HN8cZ7vSB/re1hzPskC5
# QLajNvHRjOsnjr4ZfGWZmDq3ZQ2E4mTyYXlIWFI4Yhh9G9XuMIIGCjCCBPKgAwIB
# AgIQUgDlqiVW/BqG7ZbJ1EszxzANBgkqhkiG9w0BAQUFADCByjELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQLExZWZXJpU2lnbiBU
# cnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJpU2lnbiwgSW5jLiAt
# IEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxWZXJpU2lnbiBDbGFz
# cyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IC0gRzUw
# HhcNMTAwMjA4MDAwMDAwWhcNMjAwMjA3MjM1OTU5WjCBtDELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQLExZWZXJpU2lnbiBUcnVz
# dCBOZXR3b3JrMTswOQYDVQQLEzJUZXJtcyBvZiB1c2UgYXQgaHR0cHM6Ly93d3cu
# dmVyaXNpZ24uY29tL3JwYSAoYykxMDEuMCwGA1UEAxMlVmVyaVNpZ24gQ2xhc3Mg
# MyBDb2RlIFNpZ25pbmcgMjAxMCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAPUjS16l14q7MunUV/fv5Mcmfq0ZmP6onX2U9jZrENd1gTB/BGh/yyt1
# Hs0dCIzfaZSnN6Oce4DgmeHuN01fzjsU7obU0PUnNbwlCzinjGOdF6MIpauw+81q
# YoJM1SHaG9nx44Q7iipPhVuQAU/Jp3YQfycDfL6ufn3B3fkFvBtInGnnwKQ8PEEA
# Pt+W5cXklHHWVQHHACZKQDy1oSapDKdtgI6QJXvPvz8c6y+W+uWHd8a1VrJ6O1Qw
# UxvfYjT/HtH0WpMoheVMF05+W/2kk5l/383vpHXv7xX2R+f4GXLYLjQaprSnTH69
# u08MPVfxMNamNo7WgHbXGS6lzX40LYkCAwEAAaOCAf4wggH6MBIGA1UdEwEB/wQI
# MAYBAf8CAQAwcAYDVR0gBGkwZzBlBgtghkgBhvhFAQcXAzBWMCgGCCsGAQUFBwIB
# FhxodHRwczovL3d3dy52ZXJpc2lnbi5jb20vY3BzMCoGCCsGAQUFBwICMB4aHGh0
# dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEwDgYDVR0PAQH/BAQDAgEGMG0GCCsG
# AQUFBwEMBGEwX6FdoFswWTBXMFUWCWltYWdlL2dpZjAhMB8wBwYFKw4DAhoEFI/l
# 0xqGrI2Oa8PPgGrUSBgsexkuMCUWI2h0dHA6Ly9sb2dvLnZlcmlzaWduLmNvbS92
# c2xvZ28uZ2lmMDQGA1UdHwQtMCswKaAnoCWGI2h0dHA6Ly9jcmwudmVyaXNpZ24u
# Y29tL3BjYTMtZzUuY3JsMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AudmVyaXNpZ24uY29tMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEF
# BQcDAzAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVmVyaVNpZ25NUEtJLTItODAd
# BgNVHQ4EFgQUz5mp6nsm9EvJjo/X8AUm7+PSp50wHwYDVR0jBBgwFoAUf9Nlp8Ld
# 7LvwMAnzQzn6Aq8zMTMwDQYJKoZIhvcNAQEFBQADggEBAFYi5jSkxGHLSLkBrVao
# ZA/ZjJHEu8wM5a16oCJ/30c4Si1s0X9xGnzscKmx8E/kDwxT+hVe/nSYSSSFgSYc
# kRRHsExjjLuhNNTGRegNhSZzA9CpjGRt3HGS5kUFYBVZUTn8WBRr/tSk7XlrCAxB
# cuc3IgYJviPpP0SaHulhncyxkFz8PdKNrEI9ZTbUtD1AKI+bEM8jJsxLIMuQH12M
# TDTKPNjlN9ZvpSC9NOsm2a4N58Wa96G0IZEzb4boWLslfHQOWP51G2M/zjF8m48b
# lp7FU3aEW5ytkfqs7ZO6XcghU8KCU2OvEg1QhxEbPVRSloosnD2SGgiaBS7Hk6VI
# kdMxggR6MIIEdgIBATCByTCBtDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlT
# aWduLCBJbmMuMR8wHQYDVQQLExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTswOQYD
# VQQLEzJUZXJtcyBvZiB1c2UgYXQgaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3Jw
# YSAoYykxMDEuMCwGA1UEAxMlVmVyaVNpZ24gQ2xhc3MgMyBDb2RlIFNpZ25pbmcg
# MjAxMCBDQQIQDLZ6+7O4pymGCOAOlM81PjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGC
# NwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQURCupidOc
# wlSdJLHGSKujQNJ7NicwDQYJKoZIhvcNAQEBBQAEggEAkm70UAo6Xjxq7JYwBySr
# GVY09oaR5oMY64CDzeBTqn+/76mRSSYKMq1PAKAnPTdz2w3dPKjcsoVwVDD2e/0l
# UY9IJMauL+rVUcSrZcN31T6Hkfjje5B2flyfSoNhB0CF8ojdddBJC7qNBx22zvd7
# 1QvAWF5Gm7VHvKK6QBjjO6+DaBjyUt+qnF01rO1n60SlLNuf5G9MxfbR7HeKt/VD
# sJRegG/AeTc/Zttl7dSsjLASxNY77OvexC1Az0vKT2IdpIufAxmVxcW1bitLJPpc
# YYQUFZRlY0/delcraUsyCY0wRuMVSYbyTs6W3T6b152CfyCNS9VE1j04L/GRAQ3G
# kqGCAgswggIHBgkqhkiG9w0BCQYxggH4MIIB9AIBATByMF4xCzAJBgNVBAYTAlVT
# MR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEwMC4GA1UEAxMnU3ltYW50
# ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBDQSAtIEcyAhAOz/Q4yP6/NW4E2GqY
# GxpQMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqG
# SIb3DQEJBTEPFw0xMzExMTQxMjMxMDJaMCMGCSqGSIb3DQEJBDEWBBQcdjsc/6SZ
# cz4+tKiL5zz6vdl0BjANBgkqhkiG9w0BAQEFAASCAQALGuVheRBR3Jf8ap4ABIrR
# AKUcKUL16CZeR/T6AjEgn5YVeQvxmAXrIws+YDEp8TmDNadmi78qOXMESyiPK3Ez
# 8pnf7KmgR+O0vMolhCwTB9EQYQSi8bgPLrDAfCDWTS6/pIkdWOXTlwWkFqyDkCr6
# nrh5XCVLFL6H4OIQP2LcQ4XRzB1E1ZbQT9VsXU6AIr3RhU1CvJ4Cjqxb3fgOurdv
# PH14XjvgLKbdmaTdwOP/+47bZHfOfB6wYfy1JklaTs2PAIoqbE9FETGsNZ+tVSft
# A0bGrejZ8BcBYJrZuq9OsxNfD9vaH96i+NKe/tXxP2klIs+jA70mGiCeCZMpvh7F
# SIG # End signature block
