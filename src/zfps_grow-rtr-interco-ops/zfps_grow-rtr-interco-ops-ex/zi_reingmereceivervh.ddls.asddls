@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ME - Receptores Contrato VH'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingMEReceiverVH
  as select from zreing_ct2_rec_a as rec
    inner join   zreing_ct2_mat_a as mat on  mat.mat_uuid = rec.mat_uuid
    inner join   zreing_ct2_a     as ct  on  ct.ct_uuid   = mat.ct_uuid
{
  //@UI.hidden: true
  key rec.rec_uuid    as RecUuid,
      ct.ct_id        as CtId,
      mat.matnr       as Matnr,
      rec.rec_bukrs   as Bukrs,
      rec.prctr       as Prctr,
      rec.rec_status  as SocStatus
}
