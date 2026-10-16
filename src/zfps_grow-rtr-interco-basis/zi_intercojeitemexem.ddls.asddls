@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany / Basis: JE Item Excluded for Interco'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XXL,
    dataClass: #MIXED
}
define view entity ZI_INTERCOJEITEMEXEM
  as select from I_JournalEntryItem
  association [1..1] to ZI_IntercoCompanyCode       as _IntercoCompanyCode on  _IntercoCompanyCode.CompanyCode = $projection.CompanyCode
  // This join is also defined in `ZI_IntercoJEItem`. If you modify it here, ensure you update it there as well.
  association [0..*] to ZI_IntercoExemptionRuleFlat as _Exemption          on  (
               _Exemption.CompanyCode                                                                    is initial
               or _Exemption.CompanyCode                                                                 = $projection.CompanyCode
             )

                                                                           and (
                                                                              _Exemption.CostCenter      is initial
                                                                              or _Exemption.CostCenter   = $projection.CostCenter
                                                                            )
                                                                           and (
                                                                              _Exemption.ProfitCenter    is initial
                                                                              or _Exemption.ProfitCenter = $projection.ProfitCenter
                                                                            )
                                                                           and (
                                                                              _Exemption.GLAccount       is initial
                                                                              or _Exemption.GLAccount    = $projection.GLAccount
                                                                            )
                                                                           and $projection.PostingDate   between _Exemption.ValidFrom and _Exemption.ValidTo
{
  key I_JournalEntryItem.SourceLedger,
  key I_JournalEntryItem.CompanyCode,
  key I_JournalEntryItem.FiscalYear,
  key I_JournalEntryItem.FiscalPeriod,
  key I_JournalEntryItem.AccountingDocument,
  key I_JournalEntryItem.LedgerGLLineItem,
  key I_JournalEntryItem.Ledger,
      CostCenter,
      ProfitCenter,
      GLAccount,
      PostingDate,
      cast(coalesce(_Exemption[1: left outer ].ExternalID, '0000000000' ) as zint_exemption_id) as ClassificationExemptionExtID,
      _Exemption[1: left outer ].ExemptionName,
      bintohex(_Exemption[1: left outer ].ID)                                                   as ExternalExemptionID,
      _Exemption,
      _IntercoCompanyCode
}
