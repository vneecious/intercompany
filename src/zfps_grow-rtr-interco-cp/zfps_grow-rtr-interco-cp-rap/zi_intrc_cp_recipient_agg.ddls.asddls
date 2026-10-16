@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CP Doc Export - Recipient CompCode Aggregated'
define view entity ZI_INTRC_CP_RECIPIENT_AGG
  as select from zfi_a_intrc_cpid as _CPID
    inner join   zfi_a_intrc_cpi  as _CPI on  _CPI.id      = _CPID.id
                                          and _CPI.item_id  = _CPID.item_id
{
  key _CPID.id                         as Id,
  key _CPID.documentkey                as Documentkey,
      max( _CPI.recipientcompanycode ) as RecipientCompanyCode
}
group by _CPID.id, _CPID.documentkey
