@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT - Sociedades Receptoras'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTReceiver
  as select from zreing_ct_rec_a
  association to parent ZI_ReingCTMaterial as _Material
    on  _Material.CtId  = $projection.CtId
    and _Material.Matnr = $projection.Matnr
  association [1] to ZI_ReingCTContract as _Contract
    on _Contract.CtId = $projection.CtId
{
  key ct_id       as CtId,
  key matnr       as Matnr,
  key rec_bukrs   as RecBukrs,
      prctr       as Prctr,
      country     as Country,
      rec_status  as RecStatus,
      valid_from  as ValidFrom,
      valid_to    as ValidTo,
      created_by  as CreatedBy,
      created_at  as CreatedAt,
      changed_by  as ChangedBy,
      changed_at  as ChangedAt,
      _Material,
      _Contract
}
