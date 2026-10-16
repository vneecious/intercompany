@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intrecompay: Classification Results Header'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_IntercoJEItemHelperClass
  as select from zint_a_jeitem_ch
  composition [1..*] of ZR_IntercoJEItemHelperClassItm as _Items
  composition [1..*] of ZR_INTERCOJEITEMHELPERCLASSEXE as _ItemsExemptions
{
  key ledger             as Ledger,
  key companycode        as CompanyCode,
  key fiscalyear         as FiscalYear,
  key fiscalperiod       as FiscalPeriod,
  key paymenttype        as PaymentType,
      @Semantics.systemDateTime.createdAt: true
      created_at         as CreatedAt,
      @Semantics.user.createdBy: true
      created_by         as CreatedBy,
      is_rule_processed  as IsRuleProcessed,
      is_exemp_processed as IsExemptionProcessed,
      _Items, // Make association public,
      _ItemsExemptions
}
