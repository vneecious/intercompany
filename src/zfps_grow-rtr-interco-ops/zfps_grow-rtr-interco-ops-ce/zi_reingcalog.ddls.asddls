//----------------------------------------------------------------------
// Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Change ID      : V001 (CC)
// Date           : 08.07.2026
// Description    : Reintegro Gastos - Motor de Calculo IC - F1 Capa CDS de Lectura
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CA - Log de Eventos'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCALog
  as select from zreing_ca_log_a
  association to parent ZI_ReingCALine as _Line
    on  $projection.CalcRunId = _Line.CalcRunId
    and $projection.LineNum   = _Line.LineNum
  //Begin Insert V001 (CC)
  association [1..1] to ZI_ReingCARun as _Run
    on  $projection.CalcRunId = _Run.CalcRunId
  //End Insert V001 (CC)
{
  key calc_run_id  as CalcRunId,
  key line_num     as LineNum,
  key log_num      as LogNum,
      action       as Action,
      status_from  as StatusFrom,
      status_to    as StatusTo,
      created_by   as CreatedBy,
      created_at   as CreatedAt,
      message      as Message,
      group_run_id as GroupRunId,
      _Line,
      //Begin Insert V001 (CC)
      _Run
      //End Insert V001 (CC)
}
