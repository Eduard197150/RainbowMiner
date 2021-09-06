﻿using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Config.Pools.$Name.Wallets.RVN) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

if ($Config.ExcludeCoinsymbolBalances.Count -and $Config.ExcludeCoinsymbolBalances -contains "RVN") {return}

$Request = [PSCustomObject]@{}

#https://www.ravenminer.com/api/v1/wallet/RFV5WxTdbQEQCdgESiMLRBj5rwXyFHokmC
#old:https://www.ravenminer.com/api/wallet?address=RFV5WxTdbQEQCdgESiMLRBj5rwXyFHokmC
$Success = $true
try {
    if (-not ($Request = Invoke-RestMethodAsync "https://www.ravenminer.com/api/v1/wallet/$($Config.Pools.$Name.Wallets.RVN)" -cycletime ($Config.BalanceUpdateMinutes*60))){$Success = $false}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $Success = $_.Exception.Message -match "404"
}

if (-not $Success) {
    Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
    return
}

if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Info "Pool Balance API ($Name) returned nothing. "
    return
}

[PSCustomObject]@{
        Caption     = "$($Name) (RVN)"
		BaseName    = $Name
        Currency    = "RVN"
        Balance     = [Decimal]$Request.balance.cleared
        Pending     = [Decimal]$Request.balance.pending
        Total       = [Decimal]$Request.balance.cleared + [Decimal]$Request.balance.pending
        #Paid        = [Decimal]$Request.total - [Decimal]$Request.unpaid
        Paid24h     = [Decimal]$Request.earnings."1d"
        Payouts     = @(Get-BalancesPayouts $Request.payouts | Select-Object)
        LastUpdated = (Get-Date).ToUniversalTime()
}