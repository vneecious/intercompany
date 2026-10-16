@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CM - Receptoras Participantes'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCMRecv
  as select from zreing_cm_recv_a as Recv

  association to parent ZI_ReingCMHeader as _Header
    on $projection.CmHId = _Header.CmHId

  association [1] to ZI_ReingCMPeriod as _Period
    on  $projection.PeriodYear  = _Period.PeriodYear
    and $projection.PeriodMonth = _Period.PeriodMonth

{
  key Recv.cm_h_id    as CmHId,
  key Recv.bukrs_recv as BukrsRecv,

      _Header.PeriodYear  as PeriodYear,
      _Header.PeriodMonth as PeriodMonth,
      _Header.CtUuid      as CtUuid,
      _Header.MatUuid     as MatUuid,

      @Semantics.user.createdBy: true
      Recv.created_by as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      Recv.created_at as CreatedAt,
      @Semantics.user.lastChangedBy: true
      Recv.changed_by as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      Recv.changed_at as ChangedAt,

      _Header,
      _Period
}
