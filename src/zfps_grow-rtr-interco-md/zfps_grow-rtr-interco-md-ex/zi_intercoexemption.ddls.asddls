@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Intercompany: Exemptions'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoExemption
  as select from zint_a_md004
{
  key id              as ID,
      bukrs           as CompanyCode,
      exemption_id    as ExternalID,
      exemption_name  as ExemptionName,
      matnr           as Product,
      -- AGREGADO EXT_OSCUGALD 28.09.2026 - Facturación Local CH/ARG - C09: expone PaymentType
      payment_type    as PaymentType,
      -- Fin EXT_OSCUGALD 28.09.2026 - Facturación Local CH/ARG - C09
      valid_from      as ValidFrom,
      valid_to        as ValidTo,
      is_deleted      as IsDeleted,
      created_at      as CreatedAt,
      created_by      as CreatedBy,
      last_changed_at as LastChangedAt,
      last_changed_by as LastChangedBy
}
