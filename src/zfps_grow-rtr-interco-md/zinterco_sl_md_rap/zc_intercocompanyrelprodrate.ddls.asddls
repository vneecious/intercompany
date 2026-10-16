@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interco Rate values Company Rela Concept'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_IntercoCompanyRelProdRate
  provider contract transactional_query
  as projection on ZI_INTERCOCOMPANYRELPRODRATE
{
  key Uuid,
      Providercompanycode,
      ProvidercompanycodeName,
      Recipientcompanycode,
      RecipientCompanyName,
      Product,
      ProductName,
      -- AGREGADO EXT_OSCUGALD 30.09.2026 - Facturación Local CH/ARG - C25: expone PaymentType
      PaymentType,
      -- Fin EXT_OSCUGALD 30.09.2026 - Facturación Local CH/ARG - C25
      Validfrom,
      Validto,
      Markup,
      Grossingupbase,
      Grossingupmargin,
      Latepaymentinterest,
      Providergrossingup,
      Fixedrate,
      Taxcredit,
      Isdeleted,
      @Semantics.systemDateTime.createdAt: true
      Createdat,
      @Semantics.user.createdBy: true
      Createdby,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt,
      AuthorizationGroup,
      _IntercoCompanyRelProduct,
      _log : redirected to zc_intercorelprodrate_log

}
