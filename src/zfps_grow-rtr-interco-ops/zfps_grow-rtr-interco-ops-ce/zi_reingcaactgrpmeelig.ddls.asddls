//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 09.09.2026
// Description    : CA - Entidad agregada CAActionGroup para dialogos de acciones
// Transport      : DS4K9B5XZC
// Reference      : S 5000049390
//----------------------------------------------------------------------
// Purpose: same as ZI_ReingCAActGrpCmElig, for the metric header. ZREING_ME_H_A is
// keyed by me_h_id (UUID) and more than one header may stay in LIBD for the same
// ct_id/matnr/period with a different load_version (documented in Change ID V014 of
// ZBP_REINGCARUN), so the existence test must be pre-aggregated to one row per key.
//
// Only 'LIBD' is accepted here on purpose: check_insumos uses
// zif_reing_ca_c=>me_eligible_status-libd, while the pending branches of
// ZI_ReingCALineAll accept 'LIBD' or 'LIBR'. That asymmetry is pre-existing backend
// behaviour (finding H2) and is replicated faithfully, not corrected.
//----------------------------------------------------------------------
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'CA - Elegibilidad ME por ct/mat'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCAActGrpMeElig
  as select from zreing_me_h_a as ME
{
  key ME.ct_id        as CtId,
  key ME.matnr        as Matnr,
  key ME.period_year  as PeriodYear,
  key ME.period_month as PeriodMonth,

      count( * )      as MeLibdCount
}
where ME.me_status = 'LIBD'
group by ME.ct_id,
         ME.matnr,
         ME.period_year,
         ME.period_month
