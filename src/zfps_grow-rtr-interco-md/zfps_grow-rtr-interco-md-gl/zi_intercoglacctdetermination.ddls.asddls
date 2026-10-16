@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Account Determination Rule'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_IntercoGLAcctDetermination
  as select from zint_a_md_glacct
{
  key id                     as Id,
      valid_from             as ValidFrom,
      valid_to               as ValidTo,
      doc_type               as DocType,
      provider_company_code  as ProviderCompanyCode,
      recipient_company_code as RecipientCompanyCode,
      product                as Product,
      depto                  as Department,
      p_and_l_id             as PAndLId,
      p_and_l_level          as PAndLLevel,
      tariff_type            as TariffType,
      operation_type         as OperationType,
      gl_account1            as GlAccount1,
      gl_account2            as GlAccount2,
      is_deleted             as IsDeleted,
      created_at             as CreatedAt,
      created_by             as CreatedBy,
      last_changed_at        as LastChangedAt,
      local_last_changed_at  as LocalLastChangedAt,
      last_changed_by        as LastChangedBy
}
