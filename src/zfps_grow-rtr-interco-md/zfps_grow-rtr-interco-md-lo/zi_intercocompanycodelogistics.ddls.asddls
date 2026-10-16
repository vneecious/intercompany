@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Company Code Logistics'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_IntercoCompanyCodeLogistics
  as select from zint_a_md007 as CompanyCodeLogistics
  association [0..1] to I_PurchasingOrganization as _PurchasingOrganization on $projection.PurchasingOrganization = _PurchasingOrganization.PurchasingOrganization
  association [0..1] to I_SalesOrganization      as _SalesOrganization      on $projection.SalesOrganization = _SalesOrganization.SalesOrganization
  association [0..1] to I_Plant                  as _Plant                  on $projection.Plant = _Plant.Plant
{
  key bukrs                 as CompanyCode,
  key valid_from            as ValidFrom,
      valid_to              as ValidTo,
      vkorg                 as SalesOrganization,
      ekorg                 as PurchasingOrganization,
      werks                 as Plant,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      _PurchasingOrganization,
      _SalesOrganization,
      _Plant

}
