@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interco Rate values Company Rel Concepts'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #M,
    dataClass: #MIXED
}
define root view entity ZI_INTERCOCOMPANYRELPRODRATE
  as select from zint_a_md003
  association [0..*] to ZI_IntercoCompanyRelProduct as _IntercoCompanyRelProduct on  $projection.Providercompanycode  = _IntercoCompanyRelProduct.ProviderCompanyCode
                                                                                 and $projection.Recipientcompanycode = _IntercoCompanyRelProduct.RecipientCompanyCode
                                                                                 and $projection.Product              = _IntercoCompanyRelProduct.Product
  association [0..*] to ZI_INtERCORELPRODRATE_LOG   as _log                      on  $projection.Uuid = _log.uuid
  association [0..1] to ZI_IntercoCompanyCode       as _ProviderCompany          on  _ProviderCompany.CompanyCode = $projection.Providercompanycode
  association [0..1] to ZI_IntercoCompanyCode       as _RecipientCompany         on  _RecipientCompany.CompanyCode = $projection.Recipientcompanycode
{
  key  uuid                              as Uuid,
       providercompanycode               as Providercompanycode,
       _ProviderCompany.CompanyCodeName  as ProvidercompanycodeName,
       recipientcompanycode              as Recipientcompanycode,
       _RecipientCompany.CompanyCodeName as RecipientCompanyName,
       product                           as Product,
       productname                       as ProductName,
       -- AGREGADO EXT_OSCUGALD 30.09.2026 - Facturación Local CH/ARG - C25: expone PaymentType (opcional, vacío = aplica a ambos procesos)
       payment_type                      as PaymentType,
       -- Fin EXT_OSCUGALD 30.09.2026 - Facturación Local CH/ARG - C25
       validfrom                         as Validfrom,
       validto                           as Validto,

       markup                            as Markup,
       grossingupbase                    as Grossingupbase,
       grossingupmargin                  as Grossingupmargin,

       latepaymentinterest               as Latepaymentinterest,

       providergrossingup                as Providergrossingup,

       fixedrate                         as Fixedrate,
       taxcredit                         as Taxcredit,
       isdeleted                         as Isdeleted,
       @Semantics.systemDateTime.createdAt: true
       createdat                         as Createdat,
       @Semantics.user.createdBy: true
       createdby                         as Createdby,
       @Semantics.systemDateTime.lastChangedAt: true
       lastchangedat                     as LastChangedAt,
       authorizationgroup                as AuthorizationGroup, //Check

       //associations//
       _IntercoCompanyRelProduct,
       _log,
       _ProviderCompany,
       _RecipientCompany

}
