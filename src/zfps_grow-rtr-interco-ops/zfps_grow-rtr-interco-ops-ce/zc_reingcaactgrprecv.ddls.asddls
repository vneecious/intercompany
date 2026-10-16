//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 09.09.2026
// Description    : CA - Entidad agregada CAActionGroup para dialogos de acciones
// Transport      : DS4K9B5XZC
// Reference      : S 5000049390
//----------------------------------------------------------------------
// Consumption view of the receivers of an actionable group.
// Filtering by receiving company code is served here (Decision D6):
//   GET /CAActionGroupReceiver?$filter=BukrsRecv eq '2000'&$expand=_Group
// instead of an any()/all() path expression over the to-many association of the group,
// which has no reliable support in the OData V4 exposure of CDS on 758. Still a single
// HTTP call, and _Group returns the summary of the WHOLE group (BR-AG-15, CU-R03).
//
// WHY "as select from" AND NOT "as projection on" (ERR-004): a projection view that
// uses "redirected to" is classified as a TRANSACTIONAL projection view and demands a
// business object, which this read-only entity does not have. The association is
// declared directly against the consumption counterpart instead; OData navigation
// (_Group) is identical for the client.
//
// NOTE: @Semantics.booleanIndicator is NOT released in this system, so IsOrphan is
// exposed as its underlying abap.char(1) flag ('X' / ''). Consumers filter it as
// text: $filter=IsOrphan eq 'X'.
//
// ACTIVATION NOTE: mutual association cycle with ZC_ReingCAActionGroup - activate both
// in a single mass activation.
//----------------------------------------------------------------------
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Receptoras del Grupo Accionable'

define view entity ZC_ReingCAActGrpRecv
  as select from ZI_ReingCAActGrpRecv as RC

  association [1..1] to ZC_ReingCAActionGroup as _Group
    on  $projection.PeriodYear  = _Group.PeriodYear
    and $projection.PeriodMonth = _Group.PeriodMonth
    and $projection.CalcRunId   = _Group.CalcRunId
    and $projection.CtUuid      = _Group.CtUuid
    and $projection.MatUuid     = _Group.MatUuid
    and $projection.OpType      = _Group.OpType
    and $projection.OpUuid      = _Group.OpUuid
    and $projection.CmHId       = _Group.CmHId
{
  key RC.PeriodYear        as PeriodYear,
  key RC.PeriodMonth       as PeriodMonth,
  key RC.CalcRunId         as CalcRunId,
  key RC.CtUuid            as CtUuid,
  key RC.MatUuid           as MatUuid,
  key RC.OpType            as OpType,
  key RC.OpUuid            as OpUuid,
  @UI.hidden: true
  key RC.CmHId             as CmHId,
  key RC.BukrsRecv         as BukrsRecv,

      RC.Country           as Country,
      RC.MaxLineStatus     as MaxLineStatus,
      RC.StatusCriticality as StatusCriticality,

      RC.IsOrphan          as IsOrphan,

      /* Associations */
      _Group
}
