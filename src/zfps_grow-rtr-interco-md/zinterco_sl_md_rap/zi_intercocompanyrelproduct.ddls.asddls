@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Relationship Companies por Concepts'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZI_IntercoCompanyRelProduct
  as select from zint_a_md001
  association [0..1] to ZI_IntercoCompanyCode     as _ProviderCompany  on _ProviderCompany.CompanyCode = $projection.ProviderCompanyCode
  association [0..1] to ZI_IntercoCompanyCode     as _RecipientCompany on _RecipientCompany.CompanyCode = $projection.RecipientCompanyCode
  association [0..1] to ZI_IntercoProduct         as _Product          on _Product.Product = $projection.Product
  association [0..1] to ZI_IntercoProfitCenter_SH as _ProfitCenterText on _ProfitCenterText.ProfitCenter = $projection.ProfitCenter
  association [0..*] to zi_intercorelproduct_log  as _log              on _log.uuid = $projection.Id
  association [0..1] to ZI_IntercoFlow_SH         as _Flow             on _Flow.Flow = $projection.Flow

{
      @Semantics.uuid: true
  key id                                 as Id,
      providercompanycode                as ProviderCompanyCode,
      _ProviderCompany.CompanyCodeName   as ProviderCompanyCodeName,
      recipientcompanycode               as RecipientCompanyCode,
      _RecipientCompany.CompanyCodeName  as RecipientCompanyCodeName,
      product                            as Product,
      _Product.ProductName               as ProductName,
      _Product.Metric                    as Metric,
      profitcenter                       as ProfitCenter,
      _ProfitCenterText.ProfitCenterName as ProfitCenterName,
      validfrom                          as ValidFrom,
      validto                            as ValidTo,
      rate                               as Rate,
      cast( '%' as abap.unit( 3 ) )      as RateUnit,
      flow                               as Flow,
      _Flow.FlowName                     as FlowName,
      ispromo                            as IsPromo,
      isblocked                          as IsBlocked,
      isdeleted                          as IsDeleted,
      zindex                             as zindex,
      _Product.AuthorizationGroup        as AuthorizationGroup,
      @Semantics.systemDateTime.createdAt: true
      createdat                          as CreatedAt,
      @Semantics.user.createdBy: true
      createdby                          as CreatedBy,
      lastchangedat                      as LastChangedAt,

      _ProviderCompany,
      _RecipientCompany,
      _log
}
