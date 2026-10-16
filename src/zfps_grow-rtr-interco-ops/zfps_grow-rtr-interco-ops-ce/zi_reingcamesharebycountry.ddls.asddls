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
@EndUserText.label: 'CA - Shares ME agregados por Pais'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCAMeShareByCountry
  as select from ZI_ReingMEItem as MI
    inner join zreing_me_h_a    as MH on MI.MeHId = MH.me_h_id
{
  key MH.ct_id                                     as CtId,
  key MH.matnr                                     as Matnr,
  key MH.period_year                               as PeriodYear,
  key MH.period_month                              as PeriodMonth,
  key MI.Country                                   as Country,

      cast( sum( MI.SharePct ) as abap.dec(9,6) )  as SharePctPais
}
group by MH.ct_id, MH.matnr, MH.period_year, MH.period_month, MI.Country
