//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 04.07.2026
// Description    : Reintegro Gastos - Motor de Calculo IC - F1 Capa CDS de Lectura
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CA - Base Amt Precalculado Cronograma'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCADfrBaseAmt
  as select from zreing_ct2_crn_a as CRN
    inner join zreing_ct2_opt_a as OPT_CHILD
      on  OPT_CHILD.ct_uuid  = CRN.ct_uuid
      and OPT_CHILD.mat_uuid = CRN.mat_uuid
      and OPT_CHILD.op_type  = CRN.op_type
      and OPT_CHILD.op_uuid  = CRN.op_uuid
    inner join zreing_op_type_c as OPC
      on  OPC.op_type = OPT_CHILD.op_type
      and OPC.active  = 'X'
    inner join zreing_ct2_opt_a as OPT_PARENT
      on  OPT_PARENT.ct_uuid       = OPT_CHILD.ct_uuid
      and OPT_PARENT.mat_uuid      = OPT_CHILD.mat_uuid
      and OPT_PARENT.op_type       = OPC.parent_type
      and ( OPT_PARENT.op_uuid     = OPT_CHILD.parent_instance_id
         or OPT_PARENT.op_instance_num = OPT_CHILD.op_instance_num )
    inner join zreing_ca_line_a as PARENT_LINE
      on  PARENT_LINE.ct_uuid     = OPT_PARENT.ct_uuid
      and PARENT_LINE.mat_uuid    = OPT_PARENT.mat_uuid
      and PARENT_LINE.op_uuid     = OPT_PARENT.op_uuid
      and PARENT_LINE.line_status = 'CONT'
{
  key CRN.ct_uuid    as CtUuid,
  key CRN.mat_uuid   as MatUuid,
  key CRN.op_type    as OpType,
  key CRN.op_uuid    as OpUuid,
  key CRN.cron_year  as CronYear,
  key CRN.cron_month as CronMonth,
  key PARENT_LINE.bukrs_recv as BukrsRecv,

  @Semantics.amount.currencyCode: 'CtCurrency'
  cast( cast( PARENT_LINE.net_amt as abap.dec(15,2) ) * cast( CRN.percentage as abap.dec(15,2) ) / 100 as abap.curr(15,2) ) as BaseAmt,

  PARENT_LINE.ct_currency as CtCurrency
}
