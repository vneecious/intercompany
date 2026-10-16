@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View for ZR_INTERCOCOMPANYCODELOGISTICS'
@ObjectModel.semanticKey: [ 'CompanyCode', 'ValidFrom' ]
define root view entity ZC_INTERCOCOMPANYCODELOGISTICS
  provider contract transactional_query
  as projection on ZR_IntercoCompanyCodeLogistics
{
  key CompanyCode,
  key ValidFrom,
      ValidTo,
      SalesOrganization,
      PurchasingOrganization,
      Plant,
      CreatedAt,
      CreatedBy,
      LocalLastChangedAt,
      LastChangedAt,
      LastChangedBy,
      /* Associations */
      _Plant,
      _PurchasingOrganization,
      _SalesOrganization

}
