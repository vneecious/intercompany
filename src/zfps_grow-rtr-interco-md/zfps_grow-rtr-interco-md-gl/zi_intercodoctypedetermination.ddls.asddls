@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Accounting Document Type Determination Rule'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoDocTypeDetermination
  as select from zint_a_md_blart
{
  key id                       as ID,
      valid_from               as ValidFrom,
      valid_to                 as ValidTo,
      doc_type                 as DocType,
      provider_company_code    as ProviderCompanyCode,
      recipient_company_code   as RecipientCompanyCode,
      payment_type             as PaymentType,
      amount_sign              as AmountSign,
      accounting_document_type as AccountingDocumentType,
      is_deleted               as IsDeleted,
      created_at               as CreatedAt,
      created_by               as CreatedBy,
      last_changed_at          as LastChangedAt,
      local_last_changed_at    as LocalLastChangedAt,
      last_changed_by          as LastChangedBy
}
