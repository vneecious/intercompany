//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 03.08.2026
// Description    : Reintegro Gastos - Motor de Calculo IC - F1 Capa CDS de Lectura
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
// Change ID V002 (04.08.2026 | EXT_GONZALCA): agrega NextDeltaSeq
// (DeltaCount + 1, ya formateado NUMC2) calculado aqui en el SELECT list
// (permitido) en vez de en la condicion ON de ZI_ReingCALineAll (donde
// "coalesce(...) + 1" no esta soportado -- SDDL_PARSER_MSG 066, "+" no
// valido en esa posicion). El consumidor solo compara por igualdad ahora.
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CA - Conteo de Deltas Existentes'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCADeltaSeqCount
  as select from zreing_ca_line_a
{
  key ct_uuid                        as CtUuid,
  key mat_uuid                       as MatUuid,
  key op_type                        as OpType,
  key op_uuid                        as OpUuid,
  key bukrs_recv                     as BukrsRecv,

      cast( count(*) as abap.int4 )  as DeltaCount,
      cast(
        lpad( ltrim( cast( count(*) + 1 as abap.char(20) ), ' ' ), 2, '0' )
      as abap.numc(2) )              as NextDeltaSeq
}
where is_delta = 'X'
  and line_status <> 'ERR'
group by ct_uuid, mat_uuid, op_type, op_uuid, bukrs_recv
