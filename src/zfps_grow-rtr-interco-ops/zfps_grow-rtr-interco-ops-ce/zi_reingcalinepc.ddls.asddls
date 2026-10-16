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
@EndUserText.label: 'CA - Apertura por Profit Center'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCALinePC
  as select from zreing_ca_lpc_a
  association to parent ZI_ReingCALine as _Line
    on  $projection.CalcRunId = _Line.CalcRunId
    and $projection.LineNum   = _Line.LineNum
  //Begin Insert V001 (CC)
  association [1..1] to ZI_ReingCARun as _Run
    on  $projection.CalcRunId = _Run.CalcRunId
  //End Insert V001 (CC)
{
  key calc_run_id   as CalcRunId,
  key line_num      as LineNum,
  key pc_seq        as PcSeq,
      prctr         as Prctr,
      // Begin Change ID V002 (03.08.2026 | EXT_GONZALCA)
      // Descripcion : Delta v2 CA-05 - exponer las 3 dimensiones nuevas de CA-01 (apertura completa)
      campana       as Campana,
      role_category as RoleCategory,
      allocation    as Allocation,
      // End Change ID V002 (03.08.2026 | EXT_GONZALCA)
      share_abs     as ShareAbs,
      // Begin Change ID V001 (14.07.2026 | EXT_GONZALCA)
      // Descripcion : agregar @Semantics.amount.currencyCode a los campos de importe (CtCurrency/LocalCurrency)
      // - falta simbolo de moneda en metadata OData V4, pedido de Frontend
      @Semantics.amount.currencyCode: 'CtCurrency'
      calc_amt      as CalcAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      bruto_amt     as BrutoAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      tax_amt       as TaxAmt,
      @Semantics.amount.currencyCode: 'CtCurrency'
      net_amt       as NetAmt,
      ct_currency   as CtCurrency,
      @Semantics.amount.currencyCode: 'LocalCurrency'
      net_local_amt as NetLocalAmt,
      local_currency as LocalCurrency,
      // End Change ID V001 (14.07.2026 | EXT_GONZALCA)
      // V001 (CC) - CA-11 (Brazil): currency belongs to the parent line.
      _Line.TransCurrency as TransCurrency,
      @Semantics.amount.currencyCode: 'TransCurrency'
      bruto_trans_amt as BrutoTransAmt,
      @Semantics.amount.currencyCode: 'TransCurrency'
      net_trans_amt as NetTransAmt,
      _Line,
      //Begin Insert V001 (CC)
      _Run
      //End Insert V001 (CC)
}

