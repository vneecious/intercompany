@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT V2 - Material IC View Entity'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTMaterial2
  as select from zreing_ct2_mat_a
  association to parent ZI_ReingCTContract2 as _Contract
    on _Contract.CtUuid = $projection.CtUuid
  composition [0..*] of ZI_ReingCTOpType2   as _OpTypes
  composition [0..*] of ZI_ReingCTReceiver2 as _Receivers
  composition [0..*] of ZI_ReingCTMetric2   as _Metrics
  composition [0..*] of ZI_ReingCTGL2       as _GLLines
{
  key ct_uuid    as CtUuid,
  key mat_uuid   as MatUuid,
      matnr      as Matnr,
      mat_desc   as MatDesc,
      amount     as Amount,
      waers      as Waers,
      kostl      as Kostl,
      prctr      as Prctr,
      saknr      as Saknr,
      mat_status as MatStatus,
      @Semantics.user.createdBy: true
      created_by as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at as CreatedAt,
      @Semantics.user.lastChangedBy: true
      changed_by as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at as ChangedAt,
      _Contract,
      _OpTypes,
      _Receivers,
      _Metrics,
      _GLLines
}
