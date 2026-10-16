@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT - Material IC View Entity'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTMaterial
  as select from zreing_ct_mat_a
  association to parent ZI_ReingCTContract as _Contract
    on _Contract.CtId = $projection.CtId
  composition [0..*] of ZI_ReingCTOpType   as _OpTypes
  composition [0..*] of ZI_ReingCTReceiver as _Receivers
  composition [0..*] of ZI_ReingCTMetric   as _Metrics
  composition [0..*] of ZI_ReingCTGL       as _GLLines
{
  key ct_id      as CtId,
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Product', element: 'Product' } }]
  key matnr      as Matnr,
      mat_desc   as MatDesc,
      amount     as Amount,
      waers      as Waers,
      kostl      as Kostl,
      prctr      as Prctr,
      saknr      as Saknr,
      mat_status as MatStatus,
      created_by as CreatedBy,
      created_at as CreatedAt,
      changed_by as ChangedBy,
      changed_at as ChangedAt,
      _Contract,
      _OpTypes,
      _Receivers,
      _Metrics,
      _GLLines
}
