@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel: {
    semanticKey: ['ID', 'RuleID'],
    representativeKey: 'ID'
}
@EndUserText.label: 'Intercompany: Exemption Rules'
@Metadata.allowExtensions: true
define view entity ZI_INTERCOEXEMPTIONRULETP
  as select from ZI_IntercoExemptionRule
  association        to parent ZI_INTERCOEXEMPTIONTP as _Exemption    on $projection.ID = _Exemption.ID
  association [0..1] to I_GLAccount                  as _GLAccount    on _GLAccount.GLAccount = $projection.GLAccount
  association [0..1] to I_ProfitCenter               as _ProfitCenter on _ProfitCenter.ProfitCenter = $projection.ProfitCenter
  association [0..1] to I_CostCenter                 as _CostCenter   on _CostCenter.CostCenter = $projection.CostCenter
{
  key ID,
  key RuleID,
      @Semantics.fiscal.year: true
      AccountingDocumentType,
      GLAccount,
      ProfitCenter,
      CostCenter,
      _Exemption,
      _GLAccount,
      _ProfitCenter,
      _CostCenter
}
