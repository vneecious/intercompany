//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 09.09.2026
// Description    : CA - Entidad agregada CAActionGroup para dialogos de acciones
// Transport      : DS4K9B5XZC
// Reference      : S 5000049390
//----------------------------------------------------------------------
// Receivers of an actionable group, at group x receiver granularity. It replaces the
// aggregated ReceiversText field (Decision D1): STRING_AGG is not part of the aggr_expr
// set of a CDS view entity, so the receiver list is exposed as an association instead.
//
// It also carries the FULL group key plus the _Group association, so that filtering by
// receiver selects the groups that contain that receiver but still returns the summary
// of the whole group (BR-AG-15 / CU-R03): the filtered receiver must not hide that
// another line of the same group is processing or has a different status.
//
// The GROUP BY has two jobs: dedupe against the row multiplication of finding H5, and
// give OData a formally unique key.
//
// The @ObjectModel.usageType annotations are deliberately absent: with
// dataClass #TRANSACTIONAL the consumption projection ZC_ReingCAActGrpRecv is treated
// as a transactional projection view and SAP demands a business object
// ("Transactional Projection View must be part of a business object"), which this
// read-only entity does not have and must not have.
//
// ACTIVATION NOTE: mutual association cycle with ZI_ReingCAActionGroup (_Receivers here,
// _Group there). Neither activates alone - both must go in a single mass activation.
//----------------------------------------------------------------------
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'CA - Receivers of an actionable group'

define view entity ZI_ReingCAActGrpRecv
  as select from ZI_ReingCAActGrpLine as GL

  association [1..1] to ZI_ReingCAActionGroup as _Group
    on  $projection.PeriodYear  = _Group.PeriodYear
    and $projection.PeriodMonth = _Group.PeriodMonth
    and $projection.CalcRunId   = _Group.CalcRunId
    and $projection.CtUuid      = _Group.CtUuid
    and $projection.MatUuid     = _Group.MatUuid
    and $projection.OpType      = _Group.OpType
    and $projection.OpUuid      = _Group.OpUuid
    and $projection.CmHId       = _Group.CmHId
{
  key GL.PeriodYear                as PeriodYear,
  key GL.PeriodMonth               as PeriodMonth,
  key GL.CalcRunId                 as CalcRunId,
  key GL.CtUuid                    as CtUuid,
  key GL.MatUuid                   as MatUuid,
  key GL.OpType                    as OpType,
  key GL.OpUuid                    as OpUuid,
  key GL.CmHId                     as CmHId,
  key GL.BukrsRecv                 as BukrsRecv,

      max( GL.Country )            as Country,
      max( GL.LineStatus )         as MaxLineStatus,
      max( GL.StatusCriticality )  as StatusCriticality,
      max( GL.IsOrphan )           as IsOrphan,

      /* Associations */
      _Group
}
group by GL.PeriodYear,
         GL.PeriodMonth,
         GL.CalcRunId,
         GL.CtUuid,
         GL.MatUuid,
         GL.OpType,
         GL.OpUuid,
         GL.CmHId,
         GL.BukrsRecv
