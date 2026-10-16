@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT V2 - Sociedades Receptoras'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTReceiver2
  as select from zreing_ct2_rec_a
  association     to parent ZI_ReingCTMaterial2 as _Material on  _Material.CtUuid  = $projection.CtUuid
                                                             and _Material.MatUuid = $projection.MatUuid
  association [1] to ZI_ReingCTContract2        as _Contract on  _Contract.CtUuid = $projection.CtUuid
{
  key ct_uuid    as CtUuid,
  key mat_uuid   as MatUuid,
  key rec_uuid   as RecUuid,
      rec_bukrs  as RecBukrs,
      prctr         as Prctr,
      campana       as Campana,
      role_category as RoleCategory,
      allocation    as Allocation,
      country       as Country,
      rec_status as RecStatus,
      valid_from as ValidFrom,
      valid_to   as ValidTo,
      @Semantics.user.createdBy: true
      created_by as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at as CreatedAt,
      @Semantics.user.lastChangedBy: true
      changed_by as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at as ChangedAt,
      _Material,
      _Contract
}
