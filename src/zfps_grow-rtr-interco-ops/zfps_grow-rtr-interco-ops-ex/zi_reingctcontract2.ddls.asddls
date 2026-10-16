@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT V2 - Contrato IC Root View Entity'
@ObjectModel.semanticKey: ['CtId']
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #MIXED

// Autor  : AGF
// Fecha  : 18.06.2026
// P3 - Asociacion a I_Supplier (SupplierName expuesto solo en ZC)

define root view entity ZI_ReingCTContract2
  as select from zreing_ct2_a
  composition [0..*] of ZI_ReingCTMaterial2 as _Materials
  composition [0..*] of ZI_ReingC2Hist      as _History
  association [0..1] to I_Supplier          as _Supplier
    on _Supplier.Supplier = $projection.Lifnr
{
  key ct_uuid       as CtUuid,
      ct_id         as CtId,
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
      @Semantics.user.createdBy: true
      created_by    as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at    as CreatedAt,
      @Semantics.user.lastChangedBy: true
      changed_by    as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at    as ChangedAt,
      _Materials,
      _History,
      _Supplier
}
