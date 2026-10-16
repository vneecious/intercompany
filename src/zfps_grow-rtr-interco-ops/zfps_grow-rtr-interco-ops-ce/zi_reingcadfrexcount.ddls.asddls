//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 03.07.2026
// Description    : Reintegro Gastos - Motor de Calculo IC - F1 Capa CDS de Lectura
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CA - Cuotas de Cronograma Ya Ejecutadas'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCADfrExCount
  as select from zreing_ct2_crn_a
{
  key ct_uuid                        as CtUuid,
  key mat_uuid                       as MatUuid,
  key op_type                        as OpType,
  key op_uuid                        as OpUuid,

      cast( count(*) as abap.int4 )  as ExCount
}
where cron_status = 'EX'
group by ct_uuid, mat_uuid, op_type, op_uuid
