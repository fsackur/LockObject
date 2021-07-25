#requires -version 2.0

function Lock-Object
{
    <#
    .Synopsis
        Locks an object to prevent simultaneous access from another thread.
    .DESCRIPTION
        PowerShell implementation of C#'s "lock" statement.  Code executed in the script block does not have to worry about simultaneous modification of the object by code in another thread.
    .PARAMETER InputObject
        The object which is to be locked.  This does not necessarily need to be the actual object you want to access; it's common for an object to expose a property which is used for this purpose, such as the ICollection.SyncRoot property.
    .PARAMETER ScriptBlock
        The script block that is to be executed while you have a lock on the object.
        Note:  This script block is "dot-sourced" to run in the same scope as the caller.  This allows you to assign variables inside the script block and have them be available to your script or function after the end of the lock block, if desired.
    .EXAMPLE
        $hashTable = @{}
        lock $hashTable.SyncRoot {
            $hashTable.Add("Key", "Value")
        }

        This is an example of using the "lock" alias to Lock-Object, in a manner that most closely resembles the similar C# syntax with positional parameters.
    .EXAMPLE
        $hashTable = @{}
        Lock-Object -InputObject $hashTable.SyncRoot -ScriptBlock {
            $hashTable.Add("Key", "Value")
        }

        This is the same as Example 1, but using the full PowerShell command and parameter names.
    .INPUTS
        None.  This command does not accept pipeline input.
    .OUTPUTS
        System.Object (depends on what's in the script block.)
    .NOTES
        Most of the time, PowerShell code runs in a single thread.  You have to go through several steps to create a situation in which multiple threads can try to access the same .NET object.  In the Links section of this help topic, there is a blog post by Boe Prox which demonstrates this.
    .LINK
        http://learn-powershell.net/2013/04/19/sharing-variables-and-live-objects-between-powershell-runspaces/
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [object]
        $InputObject,

        [Parameter(Mandatory = $true, Position = 1)]
        [scriptblock]
        $ScriptBlock
    )

    # Since we're dot-sourcing the caller's script block, we'll use Private scoped variables within this function to make sure
    # the script block doesn't do anything fishy (like changing our InputObject or lockTaken values before we get a chance to
    # release the lock.)

    Set-Variable -Scope Private -Name __inputObject -Value $InputObject -Option ReadOnly -Force
    Set-Variable -Scope Private -Name __scriptBlock -Value $ScriptBlock -Option ReadOnly -Force
    Set-Variable -Scope Private -Name __threadID -Value ([System.Threading.Thread]::CurrentThread.ManagedThreadId) -Option ReadOnly -Force
    Set-Variable -Scope Private -Name __lockTaken -Value $false

    if ($__inputObject.GetType().IsValueType)
    {
        $params = @{
            Message      = "Lock object cannot be a value type."
            TargetObject = $__inputObject
            Category     = [System.Management.Automation.ErrorCategory]::InvalidArgument
            ErrorId      = 'CannotLockValueType'
        }

        Write-Error @params
        return
    }

    try
    {
        Write-Verbose "Thread ${__threadID}: Requesting lock on $__inputObject"
        [System.Threading.Monitor]::Enter($__inputObject)
        $__lockTaken = $true
        Write-Verbose "Thread ${__threadID}: Lock taken on $__inputObject"

        . $__scriptBlock
    }
    catch
    {
        $params = @{
            Exception    = $_.Exception
            Category     = [System.Management.Automation.ErrorCategory]::OperationStopped
            ErrorId      = 'InvokeWithLockError'
            TargetObject = New-Object psobject -Property @{
                ScriptBlock = $__scriptBlock
                InputObject = $__inputObject
            }
        }

        Write-Error @params
        return
    }
    finally
    {
        if ($__lockTaken)
        {
            Write-Verbose "Thread ${__threadID}: Releasing lock on $__inputObject"
            [System.Threading.Monitor]::Exit($__inputObject)
            Write-Verbose "Thread ${__threadID}: Lock released on $__inputObject"
        }
    }
}
Set-Alias -Name Lock -Value Lock-Object

Export-ModuleMember -Function Lock-Object -Alias Lock

# SIG # Begin signature block
# MIIhfgYJKoZIhvcNAQcCoIIhbzCCIWsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUEO4VJlqBpWy72lcsVZE/WVcJ
# g1KgghywMIIDtzCCAp+gAwIBAgIQDOfg5RfYRv6P5WD8G/AwOTANBgkqhkiG9w0B
# AQUFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMDYxMTEwMDAwMDAwWhcNMzExMTEwMDAwMDAwWjBlMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3Qg
# Q0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCtDhXO5EOAXLGH87dg
# +XESpa7cJpSIqvTO9SA5KFhgDPiA2qkVlTJhPLWxKISKityfCgyDF3qPkKyK53lT
# XDGEKvYPmDI2dsze3Tyoou9q+yHyUmHfnyDXH+Kx2f4YZNISW1/5WBg1vEfNoTb5
# a3/UsDg+wRvDjDPZ2C8Y/igPs6eD1sNuRMBhNZYW/lmci3Zt1/GiSw0r/wty2p5g
# 0I6QNcZ4VYcgoc/lbQrISXwxmDNsIumH0DJaoroTghHtORedmTpyoeb6pNnVFzF1
# roV9Iq4/AUaG9ih5yLHa5FcXxH4cDrC0kqZWs72yl+2qp/C3xag/lRbQ/6GW6whf
# GHdPAgMBAAGjYzBhMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0G
# A1UdDgQWBBRF66Kv9JLLgjEtUYunpyGd823IDzAfBgNVHSMEGDAWgBRF66Kv9JLL
# gjEtUYunpyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEAog683+Lt8ONyc3pklL/3
# cmbYMuRCdWKuh+vy1dneVrOfzM4UKLkNl2BcEkxY5NM9g0lFWJc1aRqoR+pWxnmr
# EthngYTffwk8lOa4JiwgvT2zKIn3X/8i4peEH+ll74fg38FnSbNd67IJKusm7Xi+
# fT8r87cmNW1fiQG2SVufAQWbqz0lwcy2f8Lxb4bG+mRo64EtlOtCt/qMHt1i8b5Q
# Z7dsvfPxH2sMNgcWfzd8qVttevESRmCD1ycEvkvOl77DZypoEd+A5wwzZr8TDRRu
# 838fYxAe+o0bJW1sj6W3YQGx0qMmoRBxna3iw/nDmVG3KwcIzi7mULKn+gpFL6Lw
# 8jCCBQswggPzoAMCAQICEAOiV15N2F/TLPzy+oVrWjMwDQYJKoZIhvcNAQEFBQAw
# bzELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTEuMCwGA1UEAxMlRGlnaUNlcnQgQXNzdXJlZCBJRCBD
# b2RlIFNpZ25pbmcgQ0EtMTAeFw0xNDA1MDUwMDAwMDBaFw0xNTA1MTMxMjAwMDBa
# MGExCzAJBgNVBAYTAkNBMQswCQYDVQQIEwJPTjERMA8GA1UEBxMIQnJhbXB0b24x
# GDAWBgNVBAoTD0RhdmlkIExlZSBXeWF0dDEYMBYGA1UEAxMPRGF2aWQgTGVlIFd5
# YXR0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvcX51YAyViQE16mg
# +IVQCQ0O8QC/wXBzTMPirnoGK9TThmxQIYgtcekZ5Xa/dWpW0xKKjaS6dRwYYXET
# pzozoMWZbFDVrgKaqtuZNu9TD6rqK/QKf4iL/eikr0NIUL4CoSEQDeGLXDw7ntzZ
# XKM86RuPw6MlDapfFQQFIMjsT7YaoqQNTOxhbiFoHVHqP7xL3JTS7TApa/RnNYyl
# O7SQ7TSNsekiXGwUNxPqt6UGuOP0nyR+GtNiBcPfeUi+XaqjjBmpqgDbkEIMLDuf
# fDO54VKvDLl8D2TxTFOcKZv61IcToOs+8z1sWTpMWI2MBuLhRR3A6iIhvilTYRBI
# iX5FZQIDAQABo4IBrzCCAaswHwYDVR0jBBgwFoAUe2jOKarAF75JeuHlP9an90WP
# NTIwHQYDVR0OBBYEFDS4+PmyUp+SmK2GR+NCMiLd+DpvMA4GA1UdDwEB/wQEAwIH
# gDATBgNVHSUEDDAKBggrBgEFBQcDAzBtBgNVHR8EZjBkMDCgLqAshipodHRwOi8v
# Y3JsMy5kaWdpY2VydC5jb20vYXNzdXJlZC1jcy1nMS5jcmwwMKAuoCyGKmh0dHA6
# Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9hc3N1cmVkLWNzLWcxLmNybDBCBgNVHSAEOzA5
# MDcGCWCGSAGG/WwDATAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2Vy
# dC5jb20vQ1BTMIGCBggrBgEFBQcBAQR2MHQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBMBggrBgEFBQcwAoZAaHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEQ29kZVNpZ25pbmdDQS0xLmNydDAM
# BgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBBQUAA4IBAQBbzAp8wys0A5LcuENslW0E
# oz7rc0A8h+XgjJWdJOFRohE1mZRFpdkVxM0SRqw7IzlSFtTMCsVVPNwU6O7y9rCY
# x5agx3CJBkJVDR/Y7DcOQTmmHy1zpcrKAgTznZuKUQZLpoYz/bA+Uh+bvXB9woCA
# IRbchos1oxC+7/gjuxBMKh4NM+9NIvWs6qpnH5JeBidQDQXp3flPkla+MKrPTL/T
# /amgna5E+9WHWnXbMFCpZ5n1bI1OvgNVZlYC/JTa4fjPEk8d16jYVP4GlRz/QUYI
# y6IAGc/z6xpkdtpXWVCbW0dCd5ybfUYTaeCJumGpS/HSJ7JcTZj694QDOKNvhfrm
# MIIGajCCBVKgAwIBAgIQA5/t7ct5W43tMgyJGfA2iTANBgkqhkiG9w0BAQUFADBi
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENB
# LTEwHhcNMTMwNTIxMDAwMDAwWhcNMTQwNjA0MDAwMDAwWjBHMQswCQYDVQQGEwJV
# UzERMA8GA1UEChMIRGlnaUNlcnQxJTAjBgNVBAMTHERpZ2lDZXJ0IFRpbWVzdGFt
# cCBSZXNwb25kZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC6aUqB
# TW+lFBaqis1nvku/xmmPWBzgeegenVgmmNpc1Hyj+dsrjBI2w/z5ZAaxu8KomAoX
# DeGV60C065ZtmL+mj3nPvIqSe22cGAZR2KUYUzIBJxlh6IRB38bw6Mr+d61f2J57
# jGBvhVxGvWvnD4DO5wPDfDHPt2VVxvvgmQjkc1r7l9rQTL60tsYPfyaSqbj8OO60
# 5DqkSNBM6qlGJ1vPkhGTnBan/tKtHyLFHqzBce+8StsBCUTfmBwtZ7qoigMzyVG1
# 9wJNCaRN/oBexddFw30IqgEzzDPYTzAW5P8iMi7rfjvw+R4y65Ul0vL+bVSEutXl
# 1NHdG6+9WXuUhTABAgMBAAGjggM1MIIDMTAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0T
# AQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCCAb8GA1UdIASCAbYwggGy
# MIIBoQYJYIZIAYb9bAcBMIIBkjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGln
# aWNlcnQuY29tL0NQUzCCAWQGCCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMA
# ZQAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8A
# bgBzAHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAA
# dABoAGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAA
# dABoAGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0A
# ZQBuAHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQA
# eQAgAGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgA
# ZQByAGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUAbgBjAGUALjALBglghkgBhv1s
# AxUwHwYDVR0jBBgwFoAUFQASKxOYspkH7R7for5XDStnAs0wHQYDVR0OBBYEFGMv
# yd95knu1I8q74aTuM37j4p36MH0GA1UdHwR2MHQwOKA2oDSGMmh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENBLTEuY3JsMDigNqA0hjJo
# dHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURDQS0xLmNy
# bDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0QXNzdXJlZElEQ0EtMS5jcnQwDQYJKoZIhvcNAQEFBQADggEBAKt0
# vUAATHYVJVc90xwD/31FyEUSZucoZWDY3zuz+g3BrDOP9IG5YfGd+5hV195HQ7qA
# PfFIzD9nMFYfzvTQTIS9h6SexeEPqAZd0C9uXtwZ6PCH6uBOrz1sII5zb37Whxjg
# htOa/J7qjHLpQQ+4cbU4LPgpstUcop0b7F8quNw3IOHLu/DQbGyls8ufSvZU4yY0
# PS64wSsct/bDPf7RLR5Q9JTI+P3uc9tJtRv09f+lkME5FBvY7XEbapj7+kCaRKkp
# DlVeeLi3pIPDcAHwZkDlrnk04StNA6Et5ttUYhjt1QmLoqrWDMhPGr6ZJXhpmYnU
# WYne34jw02dedKWdpkQwggajMIIFi6ADAgECAhAPqEkGFdcAoL4hdv3F7G29MA0G
# CSqGSIb3DQEBBQUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0
# IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMTAyMTExMjAwMDBaFw0yNjAyMTAxMjAw
# MDBaMG8xCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNV
# BAsTEHd3dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFzc3VyZWQg
# SUQgQ29kZSBTaWduaW5nIENBLTEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCcfPmgjwrKiUtTmjzsGSJ/DMv3SETQPyJumk/6zt/G0ySR/6hSk+dy+PFG
# hpTFqxf0eH/Ler6QJhx8Uy/lg+e7agUozKAXEUsYIPO3vfLcy7iGQEUfT/k5mNM7
# 629ppFwBLrFm6aa43Abero1i/kQngqkDw/7mJguTSXHlOG1O/oBcZ3e11W9mZJRr
# u4hJaNjR9H4hwebFHsnglrgJlflLnq7MMb1qWkKnxAVHfWAr2aFdvftWk+8b/HL5
# 3z4y/d0qLDJG2l5jvNC4y0wQNfxQX6xDRHz+hERQtIwqPXQM9HqLckvgVrUTtmPp
# P05JI+cGFvAlqwH4KEHmx9RkO12rAgMBAAGjggNDMIIDPzAOBgNVHQ8BAf8EBAMC
# AYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMwggHDBgNVHSAEggG6MIIBtjCCAbIGCGCG
# SAGG/WwDMIIBpDA6BggrBgEFBQcCARYuaHR0cDovL3d3dy5kaWdpY2VydC5jb20v
# c3NsLWNwcy1yZXBvc2l0b3J5Lmh0bTCCAWQGCCsGAQUFBwICMIIBVh6CAVIAQQBu
# AHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBpAGMAYQB0
# AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAAdABhAG4AYwBl
# ACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAALwBDAFAAUwAg
# AGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIAdAB5ACAAQQBn
# AHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQAIABsAGkAYQBi
# AGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIAcABvAHIAYQB0
# AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUAbgBjAGUALjAS
# BgNVHRMBAf8ECDAGAQH/AgEAMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYY
# aHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2Fj
# ZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGB
# BgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMB0GA1UdDgQWBBR7aM4p
# qsAXvkl64eU/1qf3RY81MjAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823I
# DzANBgkqhkiG9w0BAQUFAAOCAQEAe3IdZP+IyDrBt+nnqcSHu9uUkteQWTP6K4fe
# qFuAJT8Tj5uDG3xDxOaM3zk+wxXssNo7ISV7JMFyXbhHkYETRvqcP2pRON60Jcvw
# q9/FKAFUeRBGJNE4DyahYZBNur0o5j/xxKqb9to1U0/J8j3TbNwj7aqgTWcJ8zqA
# PTz7NkyQ53ak3fI6v1Y1L6JMZejg1NrRx8iRai0jTzc7GZQY1NWcEDzVsRwZ/4/I
# a5ue+K6cmZZ40c2cURVbQiZyWo0KSiOSQOiG3iLCkzrUm2im3yl/Brk8Dr2fxIac
# gkdCcTKGCZlyCXlLnXFp9UH/fzl3ZPGEjb6LHrJ9aKOlkLEM/zCCBs0wggW1oAMC
# AQICEAb9+QOWA63qAArrPye7uhswDQYJKoZIhvcNAQEFBQAwZTELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTA2
# MTExMDAwMDAwMFoXDTIxMTExMDAwMDAwMFowYjELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8G
# A1UEAxMYRGlnaUNlcnQgQXNzdXJlZCBJRCBDQS0xMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEA6IItmfnKwkKVpYBzQHDSnlZUXKnE0kEGj8kz/E1FkVyB
# n+0snPgWWd+etSQVwpi5tHdJ3InECtqvy15r7a2wcTHrzzpADEZNk+yLejYIA6sM
# NP4YSYL+x8cxSIB8HqIPkg5QycaH6zY/2DDD/6b3+6LNb3Mj/qxWBZDwMiEWicZw
# iPkFl32jx0PdAug7Pe2xQaPtP77blUjE7h6z8rwMK5nQxl0SQoHhg26Ccz8mSxSQ
# rllmCsSNvtLOBq6thG9IhJtPQLnxTPKvmPv2zkBdXPao8S+v7Iki8msYZbHBc63X
# 8djPHgp0XEK4aH631XcKJ1Z8D2KkPzIUYJX9BwSiCQIDAQABo4IDejCCA3YwDgYD
# VR0PAQH/BAQDAgGGMDsGA1UdJQQ0MDIGCCsGAQUFBwMBBggrBgEFBQcDAgYIKwYB
# BQUHAwMGCCsGAQUFBwMEBggrBgEFBQcDCDCCAdIGA1UdIASCAckwggHFMIIBtAYK
# YIZIAYb9bAABBDCCAaQwOgYIKwYBBQUHAgEWLmh0dHA6Ly93d3cuZGlnaWNlcnQu
# Y29tL3NzbC1jcHMtcmVwb3NpdG9yeS5odG0wggFkBggrBgEFBQcCAjCCAVYeggFS
# AEEAbgB5ACAAdQBzAGUAIABvAGYAIAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBj
# AGEAdABlACAAYwBvAG4AcwB0AGkAdAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBu
# AGMAZQAgAG8AZgAgAHQAaABlACAARABpAGcAaQBDAGUAcgB0ACAAQwBQAC8AQwBQ
# AFMAIABhAG4AZAAgAHQAaABlACAAUgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAg
# AEEAZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABp
# AGEAYgBpAGwAaQB0AHkAIABhAG4AZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwBy
# AGEAdABlAGQAIABoAGUAcgBlAGkAbgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBl
# AC4wCwYJYIZIAYb9bAMVMBIGA1UdEwEB/wQIMAYBAf8CAQAweQYIKwYBBQUHAQEE
# bTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYB
# BQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3Vy
# ZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0
# dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5j
# cmwwHQYDVR0OBBYEFBUAEisTmLKZB+0e36K+Vw0rZwLNMB8GA1UdIwQYMBaAFEXr
# oq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3DQEBBQUAA4IBAQBGUD7Jtygkpzgd
# tlspr1LPUukxR6tWXHvVDQtBs+/sdR90OPKyXGGinJXDUOSCuSPRujqGcq04eKx1
# XRcXNHJHhZRW0eu7NoR3zCSl8wQZVann4+erYs37iy2QwsDStZS9Xk+xBdIOPRqp
# FFumhjFiqKgz5Js5p8T1zh14dpQlc+Qqq8+cdkvtX8JLFuRLcEwAiR78xXm8TBJX
# /l/hHrwCXaj++wc4Tw3GXZG5D2dFzdaD7eeSDY2xaYxP+1ngIw/Sqq4AfO6cQg7P
# kdcntxbuD8O9fAqg7iwIVYUiuOsYGk38KiGtSTGDR5V3cdyxG0tLHBCcdxTBnU8v
# WpUIKRAmMYIEODCCBDQCAQEwgYMwbzELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERp
# Z2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEuMCwGA1UEAxMl
# RGlnaUNlcnQgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EtMQIQA6JXXk3YX9Ms
# /PL6hWtaMzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUszdkZYN+f8ZdUW8+kPboOgDblSwwDQYJ
# KoZIhvcNAQEBBQAEggEALNJqGA2QOmJE+Pw7PTrpNdHW8ijqyr7HwlQfiWbei/yi
# rAkfy5WxFR9d+She0oNDtM1DMnV5zus/rsiolyhfygpsKStVeO+xgEV866EWvd3C
# xkaTfVeQuzDeaYJQ3P4NSsIMPzOwqPChWacYps7jWSzzebF0z69akvluEsFvNWab
# oILn4+S9YsFjwdAip3+RHapV8vAquNzHOWHsisrwyIL435ynHNsDCKf3FKErPksr
# if3u3Xt5d/ZhyYA97NsvcWwLFkxqLaau2PNl0XDTvU8tscPQBbCIibduUIYKnV7u
# +bX6YpUd3qLyoe/RC/d/RqfHibN/6/lXv+hbp5qKqKGCAg8wggILBgkqhkiG9w0B
# CQYxggH8MIIB+AIBATB2MGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IEFzc3VyZWQgSUQgQ0EtMQIQA5/t7ct5W43tMgyJGfA2iTAJBgUrDgMCGgUA
# oF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQw
# NTE0MDAzODI2WjAjBgkqhkiG9w0BCQQxFgQU2+MKs6G4Xn66uDDmYmnWtcwJgY0w
# DQYJKoZIhvcNAQEBBQAEggEAI2tt9jB070aPn6uNZso0otQ51Y+Ifbj6qH8sE6NQ
# 0Muhrh2CbNqWYc8yBNWXo5YOxQdh3Pz/gd8BkPR++91AUq5Izga8FRwdsxBvJoPG
# ZZzNchC18qTHgneAKLrKEv3SNswy/YEGk4PqpopT0QcfXEpsJoHN6sk0PtLxAWX2
# 7/HXVe68R6TAU4sNQgPfu5ziZNtauz90BcbJUd9Jyl1KCy1mF7WRpHTYQQaBaQiV
# 9pmIZCgTVKkgMQOZQJ9xilXrQmWKK/yUparl5cE6svKu71r0m7yiJ/dX35JHGDmb
# +KqyHoCYUJ2i9jj6RR5U/u3RzSwAyQX827GEQcrYA5jrjw==
# SIG # End signature block
