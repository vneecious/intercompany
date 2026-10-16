@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Intrecompany: MasterData / Tax Brazil'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoTaxBR
  as select from zint_a_md_taxbr
  association [1..*] to ZI_IntercoTaxBRItem   as _Items                on  _Items.DocumentType         = $projection.DocumentType
                                                                       and _Items.ProviderCompanyCode  = $projection.ProviderCompanyCode
                                                                       and _Items.RecipientCompanyCode = $projection.RecipientCompanyCode
                                                                       and _Items.Product              = $projection.Product
                                                                       and _Items.Department           = $projection.Department
                                                                       and _Items.ValidFrom            = $projection.ValidFrom
  association        to ZI_IntercoCompanyCode as _ProviderCompanyCode  on  _ProviderCompanyCode.CompanyCode = $projection.ProviderCompanyCode
  association        to ZI_IntercoCompanyCode as _RecipientCompanyCode on  _RecipientCompanyCode.CompanyCode = $projection.RecipientCompanyCode
  association        to ZI_IntercoProduct     as _Product              on  _Product.Product = $projection.Product

{
  key doctype               as DocumentType,
  key providercompanycode   as ProviderCompanyCode,
  key recipientcompanycode  as RecipientCompanyCode,
  key product               as Product,
  key depto                 as Department,
  key valid_from            as ValidFrom,
      valid_to              as ValidTo,
      is_deleted            as IsDeleted,
      created_at            as CreatedAt,
      created_by            as CreatedBy,
      last_changed_at       as LastChangedAt,
      local_last_changed_at as LocalLastChangedAt,
      last_changed_by       as LastChangedBy,
      _Items,
      _ProviderCompanyCode,
      _RecipientCompanyCode,
      _Product
}
