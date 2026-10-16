@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '##GENERATED ZINT_A_MD_GLACCT'
define root view entity ZR_INTERCOGLACCTDETERMINATION
  as select from zint_a_md_glacct as GLAccountDetermination
{
  key id                     as ID,
      valid_from             as ValidFrom,
      valid_to               as ValidTo,
      doc_type               as DocType,
      provider_company_code  as ProviderCompanyCode,
      recipient_company_code as RecipientCompanyCode,
      product                as Product,
      depto                  as Depto,
      p_and_l_id             as PAndLID,
      p_and_l_level          as PAndLLevel,
      tariff_type            as TariffType,
      operation_type         as OperationType,
      gl_account1            as GlAccount1,
      gl_account2            as GlAccount2,
      is_deleted             as IsDeleted,
      @Semantics.systemDateTime.createdAt: true
      created_at             as CreatedAt,
      @Semantics.user.createdBy: true
      created_by             as CreatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at        as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at  as LocalLastChangedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by        as LastChangedBy

}
