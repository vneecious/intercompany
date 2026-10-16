@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BO ZI_INTERCOJEITEMCLASSBG'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_IntercoJEItemClassBGTP
  as select from ZI_IntercoJEItemClassBG
  composition [0..*] of ZR_IntercoJEItemClassBGResulTP as _Results
{
  key ID,
      Companycode,
      Fiscalyear,
      Fiscalperiod,
      Ledger,
      PaymentType,
      Pending,
      AllFilters,
      @Semantics.user.lastChangedBy: true
      Createdby,
      @Semantics.systemDateTime.lastChangedAt: true
      Createdat,
      /* Associations */
      _Results
      //  _association_name // Make association public
}
