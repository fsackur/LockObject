
# We want a WaitHandle so that an object releasing a lock can signal other threads trying to acquire
# the lock.
# This needs to be weakly-referenced to avoid memory leaks. Therefore, we use ConditionalWeakTable,
# which is also thread-safe.
# This table needs to be shared among all threads, which is tricky if we use PowerShell. Therefore,
# we use a static .NET class, which is the same across the entire AppDomain. PowerShell only runs in
# a single AppDomain, so this class will  provide the same WaitHandle for a given object across all
# threads.
$TypeDef = @'
    using System.Runtime.CompilerServices;
    using System.Threading;

    namespace LockObject
    {
        public static class WaitHandles
        {
            private static ConditionalWeakTable<object, AutoResetEvent> table = new ConditionalWeakTable<object, AutoResetEvent>();

            private static AutoResetEvent CreateCallback(object obj)
            {
                return new AutoResetEvent(true);
            }

            public static AutoResetEvent GetWaitHandle(object obj)
            {
                // this will create a value using CreateCallback if one doesn't exist already
                return table.GetValue(obj, CreateCallback);
            }
        }
    }
'@

try
{
    Add-Type $TypeDef -ErrorAction Stop
}
catch
{
    if ($_ -notmatch 'already exists')
    {
        throw
    }
}


function Lock-Object
{
    <#
        .SYNOPSIS
        Locks an object to prevent simultaneous access from another thread.

        .DESCRIPTION
        PowerShell implementation of C#'s "lock" statement. Code executed in the script block does
        not have to worry about simultaneous modification of the object by code in another thread.

        .PARAMETER InputObject
        The object which is to be locked. This does not necessarily need to be the actual object
        you want to access; it's common for an object to expose a property which is used for this
        purpose, such as the ICollection.SyncRoot property.

        .PARAMETER ScriptBlock
        The script block that is to be executed while you have a lock on the object.
        Note:  This script block is "dot-sourced" to run in the same scope as the caller. This
        allows you to assign variables inside the script block and have them be available to your
        script or function after the end of the lock block, if desired.

        .EXAMPLE
        $hashTable = @{}
        lock $hashTable.SyncRoot {
            $hashTable.Add("Key", "Value")
        }

        This is an example of using the "lock" alias to Lock-Object, in a manner that most closely
        resembles the similar C# syntax with positional parameters.

        .EXAMPLE
        $hashTable = @{}
        Lock-Object -InputObject $hashTable.SyncRoot -ScriptBlock {
            $hashTable.Add("Key", "Value")
        }

        This is the same as Example 1, but using the full PowerShell command and parameter names.

        .INPUTS
        None. This command does not accept pipeline input.

        .OUTPUTS
        System.Object (depends on what's in the script block.)

        .NOTES
        Most of the time, PowerShell code runs in a single thread. You have to go through several
        steps to create a situation in which multiple threads can try to access the same .NET
        object. In the Links section of this help topic, there is a blog post by Boe Prox which
        demonstrates this.

        .LINK
        http://learn-powershell.net/2013/04/19/sharing-variables-and-live-objects-between-powershell-runspaces/
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [ValidateScript({
            if ($__inputObject.GetType().IsValueType)
            {
                $Params = @{
                    Message      = "Lock object cannot be a value type."
                    TargetObject = $__inputObject
                    Category     = 'InvalidArgument'
                    ErrorId      = 'CannotLockValueType'
                }
                Write-Error @Params -ErrorAction Stop
            }
            return $true
        })]
        [object]$InputObject,

        [Parameter(Mandatory = $true, Position = 1)]
        [scriptblock]$ScriptBlock
    )


    $ThreadId   = [Threading.Thread]::CurrentThread.ManagedThreadId
    $WaitHandle = [LockObject.WaitHandles]::GetWaitHandle($InputObject)

    # Since we're dot-sourcing the caller's script block, we'll use Private scoped variables within
    # this function to make sure the script block doesn't do anything fishy (like changing our
    # InputObject or lockTaken values before we get a chance to release the lock.)
    $Params = @{
        Scope  = 'Private'
        Option = 'ReadOnly'
        Force  = $true
    }
    Set-Variable -Name __inputObject -Value $InputObject @Params
    Set-Variable -Name __scriptBlock -Value $ScriptBlock @Params
    Set-Variable -Name __threadID -Value $ThreadId @Params
    Set-Variable -Name __waitHandle -Value $WaitHandle @Params
    Set-Variable -Name __lockTaken -Value $false -Scope Private


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
        $Params = @{
            Exception    = $_.Exception
            Category     = [System.Management.Automation.ErrorCategory]::OperationStopped
            ErrorId      = 'InvokeWithLockError'
            TargetObject = New-Object psobject -Property @{
                ScriptBlock = $__scriptBlock
                InputObject = $__inputObject
            }
        }

        Write-Error @Params
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
