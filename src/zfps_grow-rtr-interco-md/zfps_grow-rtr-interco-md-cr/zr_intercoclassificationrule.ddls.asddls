@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '##GENERATED Classification Rule'
define root view entity ZR_INTERCOCLASSIFICATIONRULE
  as select from ZI_IntercoClassificationRule as ClassificationRule
  association [0..1] to ZI_IntercoProduct             as _Product         on _Product.Product = $projection.Product
  association [0..1] to ZI_IntercoCostCenterAlloc_SH  as _CcAllocation    on _CcAllocation.Allocation = $projection.CcAllocation
  association [0..1] to ZI_IntercoCostCenterConsVH    as _CcConsolidation on _CcConsolidation.Consolidation = $projection.CcConsolidation
  association [0..1] to ZI_IntercoCostCenterSubArea_T as _CcStdHierArea   on _CcStdHierArea.CostCenterSubArea = $projection.CcStdHierArea
  association [0..1] to ZI_IntercoPandLHierFlattened  as _PandL           on _PandL.ID = $projection.PAndLID
{
  key ID,
      RuleID,
      RuleName,
      ValidFrom,
      ValidTo,
      CompanyCode,
      Ledger,
      PAndLID,
      _PandL.Text                                                                                                              as PAndLName,
      PandLLevel,
      ProfitCenter,
      CcStdHierArea,
      _CcStdHierArea.CostCenterSubAreaName                                                                                     as CcStdHierAreaName,
      CcAllocation,
      _CcAllocation.AllocationName                                                                                             as CcAllocationName,
      CcConsolidation,
      _CcConsolidation.ConsolidationName                                                                                       as CcConsolidationName,
      Product,
      _Product.ProductName,
      IsNotBillable,
      IsDeleted,
      cast (case when IsDeleted is initial then 'X' else '' end as abap_boolean)                                               as IsNotDeleted,
      case when IsDeleted = 'X' then 1 else 0 end                                                                              as RuleCriticality,

      cast (case when ValidTo >= $session.user_date and ValidFrom <= $session.user_date then 'X' else '' end as abap_boolean ) as IsValid,
      cast ( case when $projection.IsValid = 'X' then 3 else 1 end as abap.int1 )                                              as IsValidCriticality,
      // Technical Fields
      $session.system_date                                                                                                     as Today,
      dats_add_days($session.system_date, -1, 'INITIAL')                                                                       as Yesterday,

      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,
      @Semantics.user.lastChangedBy: true
      LastChangedBy,
      // This is used by ui5-spreadsheet-importer, so we can receive exactly the excel row number so we can added in the error messages
      cast ( 0 as abap.int4 )                                                                                                  as ExcelLineNumber,
      Score,

      _Product,
      _CcAllocation,
      _CcConsolidation,
      _CcStdHierArea,
      _PandL

}
