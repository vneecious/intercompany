@EndUserText.label: 'Relationship Companies por Concepts'
//@AccessControl.authorizationCheck: #NOT_REQUIRED
@AccessControl.authorizationCheck: #CHECK
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_IntercoCompanyRelProduct
  provider contract transactional_query
  as projection on ZI_IntercoCompanyRelProduct
{
  key Id,
      //@ObjectModel.text.element:  [ 'ProviderCompanyCodeName' ]
      ProviderCompanyCode,
      ProviderCompanyCodeName,
      //@ObjectModel.text.element:  [ 'RecipientCompanyCodeName' ]
      RecipientCompanyCode,
      RecipientCompanyCodeName,
      //@ObjectModel.text.element:  [ 'ProductName' ]
      Product,
      ProductName,
      -- Ini Facturación Local CH/ARG EXT_OSCUGALD 24.10.2026 - G01A: proyecta PaymentType
      PaymentType,
      -- Fin EXT_OSCUGALD 24.10.2026 - G01A
      //@ObjectModel.text.element:  [ 'ProfitCenterName' ]
      ProfitCenter,
      ProfitCenterName,
      ValidFrom,
      ValidTo,
      //@ObjectModel.text.element:  [ 'RateUnit' ]
      Rate,
      RateUnit,
      Metric,
      //@ObjectModel.text.element:  [ 'FlowName' ]
      Flow,
      FlowName,
      //IsPromo,
      IsBlocked,
      IsDeleted,
      zindex,
      AuthorizationGroup,
      CreatedAt,
      CreatedBy,
      _log : redirected to zc_intercorelproduct_log
}
