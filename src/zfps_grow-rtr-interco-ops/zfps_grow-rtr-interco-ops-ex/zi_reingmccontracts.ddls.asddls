@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'MC - Contratos vinculados a version'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingMCContracts
  as select from zreing_ct2_met_a AS cm
    inner join   zreing_ct2_mat_a AS mat ON  mat.ct_uuid  = cm.ct_uuid
                                         AND mat.mat_uuid = cm.mat_uuid
    inner join   zreing_ct2_a     AS ct  ON  ct.ct_uuid   = cm.ct_uuid
{
  key cm.metric_code  as MetricCode,
  key cm.version_num  as VersionNum,
  key cm.ct_uuid      as CtUuid,
  key cm.mat_uuid     as MatUuid,
  key cm.metric_seq   as MetricSeq,
      ct.ct_id        as CtId,
      ct.ext_contract as ExtContract,
      ct.lifnr        as Lifnr,
      ct.bukrs        as Bukrs,
      ct.responsible  as Responsible,
      ct.ct_status    as CtStatus,
      ct.valid_from   as ValidFrom,
      ct.valid_to     as ValidTo,
      mat.matnr       as Matnr,
      cm.met_status   as MetStatus
}
// Begin Mod 04.09.2026 EXT_AGFAGINA - solo contratos activos.
// La solapa Contratos del Catalogo de Metricas debe listar los contratos ACTIVOS
// que usan la metrica. Antes la vista no filtraba por estado de contrato.
// El estado de la asignacion (MET_STATUS) NO se filtra a proposito: se expone
// como columna, para que una asignacion expirada siga siendo visible mientras
// el contrato este vigente.
where ct.ct_status = 'AC'
// End Mod 04.09.2026 EXT_AGFAGINA
