@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel: {
    semanticKey: ['ID', 'RuleID'],
    representativeKey: 'ID'
}
@EndUserText.label: 'Intercompany: Exemption Rules'
@Metadata.allowExtensions: true
define view entity ZC_IntercoExemptionRuleTP
  as projection on ZI_INTERCOEXEMPTIONRULETP
{
  key ID,
  key RuleID,
      AccountingDocumentType,
      GLAccount,
      ProfitCenter,
      CostCenter,
      _Exemption : redirected to parent ZC_IntercoExemptionTP,
      _ProfitCenter,
      _CostCenter
}
