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
@EndUserText.label: 'CA - Cabecera de Ejecucion (Root)'
@ObjectModel.semanticKey: ['CalcRunId']
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define root view entity ZI_ReingCARun
  as select from zreing_ca_run_a
  composition [0..*] of ZI_ReingCALine as _Line
{
  key calc_run_id           as CalcRunId,
      fiscal_period         as FiscalPeriod,
      fiscal_year           as FiscalYear,
      total_lines           as TotalLines,
      total_groups          as TotalGroups,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      _Line
}
