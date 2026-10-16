@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT - Contrato IC Root View Entity'
@ObjectModel.semanticKey: ['CtId']
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #MIXED

define root view entity ZI_ReingCTContract
  as select from zreing_ct_a
  composition [0..*] of ZI_ReingCTMaterial as _Materials
{
  key ct_id         as CtId,
      ct_uuid       as CtUuid,
      lifnr         as Lifnr,
      bukrs         as Bukrs,
      ext_contract  as ExtContract,
      valid_from    as ValidFrom,
      valid_to      as ValidTo,
      waers         as Waers,
      responsible   as Responsible,
      email_contact as EmailContact,
      renewal_days  as RenewalDays,
      total_amount  as TotalAmount,
      ct_status     as CtStatus,
      comments      as Comments,
      created_by    as CreatedBy,
      created_at    as CreatedAt,
      changed_by    as ChangedBy,
      changed_at    as ChangedAt,
      _Materials
}
