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
//Begin Change V002 (CC) - bug #78: missing accent in view label
@EndUserText.label: 'CA - Memoria de Cálculo (Pasos)'
//End Change V002 (CC)
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingCAStep
  as select from zreing_ca_step_a
  association to parent ZI_ReingCALine as _Line
    on  $projection.CalcRunId = _Line.CalcRunId
    and $projection.LineNum   = _Line.LineNum
  //Begin Insert V001 (CC)
  association [1..1] to ZI_ReingCARun as _Run
    on  $projection.CalcRunId = _Run.CalcRunId
  //End Insert V001 (CC)
{
  key calc_run_id    as CalcRunId,
  key line_num       as LineNum,
  key step_num       as StepNum,
  key seq            as Seq,
      step_category  as StepCategory,
      // V001 (CC) - #118: highlight result steps without changing amount types.
      case step_category
              when 'NET' then 5
              when 'FX'  then 5
              else 0
      end as RowCriticality,
      tax_type       as TaxType,
      tx_rule_id     as TxRuleId,
      step_desc      as StepDesc,
      // Begin Change ID V001 (14.07.2026 | EXT_GONZALCA)
      // Descripcion : agregar @Semantics.amount.currencyCode a InputAmt/OutputAmt - falta simbolo de
      // moneda en metadata OData V4, pedido de Frontend
      @Semantics.amount.currencyCode: 'InputCurrency'
      input_amt      as InputAmt,
      input_currency as InputCurrency,
      rate_pct       as RatePct,
      rate_desc      as RateDesc,
      @Semantics.amount.currencyCode: 'OutputCurrency'
      output_amt     as OutputAmt,
      output_currency as OutputCurrency,
      // End Change ID V001 (14.07.2026 | EXT_GONZALCA)
      sign           as Sign,
      source_table   as SourceTable,
      source_key     as SourceKey,
      // V001 (CC) - CA-11 (Brazil): output amount in parent transaction currency.
      _Line.TransCurrency as TransCurrency,
      @Semantics.amount.currencyCode: 'TransCurrency'
      output_trans_amt as OutputTransAmt,
      _Line,
      //Begin Insert V001 (CC)
      _Run
      //End Insert V001 (CC)
}

