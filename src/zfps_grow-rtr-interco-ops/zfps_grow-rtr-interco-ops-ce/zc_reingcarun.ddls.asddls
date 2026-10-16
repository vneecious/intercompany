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
@EndUserText.label: 'CA - Cabecera de Ejecucion (Drill-down)'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define root view entity ZC_ReingCARun
  provider contract transactional_query
  as projection on ZI_ReingCARun
{
  key CalcRunId,
      FiscalPeriod,
      FiscalYear,
      TotalLines,
      TotalGroups,
      CreatedBy,
      CreatedAt,
      LocalLastChangedAt,
      _Line : redirected to composition child ZC_ReingCALine
}
