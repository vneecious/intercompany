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
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Lineas de Calculo (Drill-down)'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #L
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZC_ReingCALine
  as projection on ZI_ReingCALine
  // Begin Change (27.08.2026 | EXT_AGFAGINA) - fix navegacion documento contable
  // La asociacion heredada de la vista de interfaz apunta a ZI_ReingContabDoc,
  // que NO esta expuesta en ZREING_CA_SRV y no tiene las anotaciones UI.
  // Se redeclara aca apuntando a la vista de consumo (expuesta y anotada).
  // Sufijo C siguiendo la convencion ya usada en ZC_ReingContabDoc (_ItemC).
  association [0..*] to ZC_ReingContabDoc as _ContabDocC
    on  $projection.CalcRunId = _ContabDocC.CalcRunId
    and $projection.LineNum   = _ContabDocC.LineNum
  // End Change (27.08.2026 | EXT_AGFAGINA)
{
  key CalcRunId,
  key LineNum,
      CtUuid,
      CtId,
      // Begin Insert V004 (17.09.2026 | EXT_GONZALCA)
      // Bug tracker #81: numero de contrato externo en el header de la object
      // page, resuelto en ZI_ReingCALine (V005) por la asociacion _Contract2.
      // Igual que el V003 de ExchRateTypeDesc, hay que propagar los elementos
      // explicitamente: esta proyeccion usa lista de campos, no select *, asi
      // que sin estas dos lineas no llegan al metadata OData y la DDLX no
      // puede ni anotar ExtContract ni apuntar headerInfo.title a HeaderTitle.
      ExtContract,
      HeaderTitle,
      // End Insert V004 (17.09.2026 | EXT_GONZALCA)
      Lifnr,
      BpName,
      BukrsPrest,
      MatUuid,
      Matnr,
      OpType,
      OpUuid,
      @UI.hidden: true
      CmHId,
      @UI.hidden: true
      CmLoadSeq,
      OpInstanceNum,
      ParentOpType,
      OriginRunId,
      OriginLineNum,
      ParentNetAmt,
      ParentCurrency,
      DeferPct,
      DeferCuotaNum,
      DeferCuotaTotal,
      DeferFrom,
      DeferTo,
      BukrsRecv,
      Country,
      BaseAmt,
      SharePct,
      SharePaisPct,
      ShareCombPct,
      CalcAmt,
      BrutoAmt,
      GrossUpAmt,
      TaxAmt,
      NetAmt,
      CtCurrency,
      NetLocalAmt,
      LocalCurrency,
      // V001 (CC) - CA-11 (Brazil): additive transaction-currency exposure.
      TransCurrency,
      @Semantics.amount.currencyCode: 'TransCurrency'
      NetTransAmt,
      ExchRate1,
      ExchRate1Type,
      ExchRate,
      ExchRateType,
      // Begin Insert V003 (16.09.2026 | EXT_GONZALCA)
      // Bug tracker #71: texto del tipo de tasa, resuelto en ZI_ReingCALine
      // (V004) por @ObjectModel.text.element sobre ExchRateType. Hay que
      // propagarlo explicitamente: esta proyeccion usa lista de campos, no
      // select *, asi que sin esta linea el elemento de texto no llega al
      // metadata OData y la DDLX no puede aplicar el textArrangement.
      ExchRateTypeDesc,
      // End Insert V003 (16.09.2026 | EXT_GONZALCA)
      // Begin Change ID V002 (03.08.2026 | EXT_GONZALCA)
      // Descripcion : Delta v2 CA-05 - quitar HasPcBreakdown; propagar campos delta de ZI_ReingCALine
      IsDelta,
      DeltaSeq,
      DeltaBaseAmt,
      HideDeltaFields,
      DeltaAmtCriticality,
      // End Change ID V002 (03.08.2026 | EXT_GONZALCA)
      // Begin Insert V005 (18.09.2026 | EXT_GONZALCA)
      // ET-REING-CA-001 v50 SS9.3, seccion "Origen del Delta": propagar el
      // elemento derivado TotalEfectivo calculado en ZI_ReingCALine (V006).
      // Mismo motivo que ExtContract/HeaderTitle (V004) y ExchRateTypeDesc
      // (V003): esta proyeccion usa lista explicita de campos, no select *,
      // asi que sin esta linea el elemento no llega al metadata OData y la
      // DDLX no puede anotarlo ni incluirlo en el fieldGroup de la seccion.
      TotalEfectivo,
      // End Insert V005 (18.09.2026 | EXT_GONZALCA)
      LineStatus,
      SimMessage,
      ProcStartedAt,
      ProcHeartbeatAt,
      ProcJobId,
      InsumoCheckAt,
      FiAwkey,
      LocalLastChangedAt,
      // Begin Change ID V001 (14.07.2026 | EXT_GONZALCA)
      // Descripcion : propagar los 2 campos calculados nuevos de ZI_ReingCALine (StatusCriticality, HasParent)
      // a la proyeccion F6 - imprescindible: ZC_ReingCALine usa lista explicita de campos (no select *), por lo
      // que sin este agregado la DDLX ZC_REINGCALINE no puede anotarlos ni el metadata OData los expone
      StatusCriticality,
      HasParent,
      // Iteracion #4 - fix post-activacion (ERR-002): propagar tambien los 2 campos calculados constantes
      // de criticidad fija (CritCriticalFix, CritPositiveFix) agregados en ZI_ReingCALine
      CritCriticalFix,
      CritPositiveFix,
      // End Change ID V001 (14.07.2026 | EXT_GONZALCA)
      _LinePC : redirected to composition child ZC_ReingCALinePC,
      _Step   : redirected to composition child ZC_ReingCAStep,
      _Log    : redirected to composition child ZC_ReingCALog,
      _Run    : redirected to parent ZC_ReingCARun,
      // Begin Change (27.08.2026 | EXT_AGFAGINA) - documento contable en app CA
      // Navegacion de solo lectura a los documentos FI (3-4 por linea segun DOCFLOW).
      // Se expone _ContabDocC (declarada arriba, target = vista de consumo anotada
      // y expuesta en el servicio), NO la _ContabDoc heredada de la interfaz.
      _ContabDocC
      // End Change (27.08.2026 | EXT_AGFAGINA)
}

