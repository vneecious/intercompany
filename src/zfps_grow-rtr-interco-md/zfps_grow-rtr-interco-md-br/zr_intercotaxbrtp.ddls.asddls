@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: BO Tax BR'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZR_IntercoTaxBRTP
  as select from ZI_IntercoTaxBR
  composition [1..*] of ZR_IntercoTaxBRItemTP as _Items
{
  key DocumentType,
      @ObjectModel.foreignKey.association: '_ProviderCompanyCode'
  key ProviderCompanyCode,
      @ObjectModel.foreignKey.association: '_RecipientCompanyCode'
  key RecipientCompanyCode,
      @ObjectModel.foreignKey.association: '_Product'
  key Product,
  key Department,
  key ValidFrom,
      ValidTo,
      IsDeleted,
      cast (case when IsDeleted is initial then 'X' else '' end as abap_boolean) as IsNotDeleted,
      case when IsDeleted = 'X' then 1 else 0 end                                as Criticality,
      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt,
      LocalLastChangedAt,
      @Semantics.user.lastChangedBy: true
      LastChangedBy,
      _Items,
      _ProviderCompanyCode,
      _RecipientCompanyCode,
      _Product
}
