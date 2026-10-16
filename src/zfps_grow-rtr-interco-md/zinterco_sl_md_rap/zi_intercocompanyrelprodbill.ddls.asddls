@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Conceptos Facturables por Empresa Prestadora'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #M,
    dataClass: #MIXED
}
define root view entity ZI_IntercoCompanyRelProdBill
  as select from zint_a_md002 as _Bill
  association [0..1] to ZI_IntercoProduct             as _Product      on  _Product.Product = $projection.Product
  association [0..1] to ZI_IntercoCompanyCode         as _CompanyCode  on  _CompanyCode.CompanyCode = $projection.ProviderCompanyCode
  association [0..1] to ZI_IntercoPandL               as _PandL        on  _PandL.PandLId = $projection.PandLID
  association [0..1] to I_ProfitCenter                as _ProfitCenter on  _ProfitCenter.ControllingArea = 'ML00'
                                                                       and _ProfitCenter.ProfitCenter    = $projection.ProfitCenter
                                                                       and _ProfitCenter.ValidityEndDate >= $session.user_date
  association [0..1] to ZI_IntercoCostCenterSubArea_T as _SubArea      on  _SubArea.CostCenterSubArea = $projection.CostCenterSubArea
  association [0..1] to ZI_IntercoCostCenterAlloc_SH  as _Allocation   on  _Allocation.AllocationLong = _Bill.costcenterallocation

  association [0..*] to ZI_INtERCORELPRODBILL_LOG     as _log          on  $projection.Id = _log.uuid
//  composition [0..*] of ZI_INtERCORELPRODBILL_ATTA    as _atta         
{
  key id                                                                          as Id,
      validfrom                                                                   as ValidFrom,
      validto                                                                     as ValidTo,

      product                                                                     as Product,
      _Product.ProductName                                                        as ProductName,
      _Product.ProductType                                                        as ProductType,
      _Product.ProductTypeName                                                    as ProductTypeName,

      providercompanycode                                                         as ProviderCompanyCode,
      _CompanyCode.CompanyCodeName                                                as ProviderCompanyCodeName,

      pandlid                                                                     as PandLID,
      _PandL.PandLL0Name                                                          as PandLName,

      profitcenter                                                                as ProfitCenter,
      _ProfitCenter._Text[ Language = $session.system_language ].ProfitCenterName as ProfitCenterName,

      costcentersubarea                                                           as CostCenterSubArea,
      _SubArea.CostCenterSubAreaName                                              as CostCenterSubAreaName,

      _SubArea.CostCenterArea                                                     as CostCenterArea,
      _SubArea.CostCenterAreaName                                                 as CostCenterAreaName,

      //case when costcenterallocation is not initial
      //  then ltrim( costcenterallocation, '0' )
      //  else costcenterallocation 
      //end
      costcenterallocation                                                        as CostCenterAllocation,
      _Allocation.AllocationName                                                  as CostCenterAllocationName,

      isnotbilable                                                                as IsNotBilable,
      
      zindex                                                                      as zindex, //field to know register upload from file
      
      isdeleted                                                                   as IsDeleted,
      @Semantics.systemDateTime.createdAt: true
      createdat                                                                   as CreatedAt,
      @Semantics.user.createdBy: true
      createdby                                                                   as CreatedBy,
      lastchangedat                                                               as LastChangedAt,

      //associations//
      _log
//      _atta
}
