//----------------------------------------------------------------------
// Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Change ID      : V001 (CC)
// Date           : 08.07.2026
// Description    : App CA - Motor de Calculo IC - F3.1 Fundamentos RAP (DD-B6)
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Apertura por Profit Center (Drill-down)'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZC_ReingCALinePC
  as projection on ZI_ReingCALinePC
{
  key CalcRunId,
  key LineNum,
  key PcSeq,
      Prctr,
      // Begin Change ID V002 (03.08.2026 | EXT_GONZALCA)
      // Descripcion : Delta v2 CA-05 - propagar las 3 dimensiones nuevas de ZI_ReingCALinePC
      Campana,
      RoleCategory,
      Allocation,
      // End Change ID V002 (03.08.2026 | EXT_GONZALCA)
      ShareAbs,
      CalcAmt,
      BrutoAmt,
      TaxAmt,
      NetAmt,
      CtCurrency,
      NetLocalAmt,
      LocalCurrency,
      // V001 (CC) - CA-11 (Brazil): amounts retain parent transaction currency.
      TransCurrency,
      @Semantics.amount.currencyCode: 'TransCurrency'
      BrutoTransAmt,
      @Semantics.amount.currencyCode: 'TransCurrency'
      NetTransAmt,
      _Line : redirected to parent ZC_ReingCALine,
      //Begin Insert V001 (CC) - DD-B6
      _Run : redirected to ZC_ReingCARun
      //End Insert V001 (CC) - DD-B6
}

