//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 03.07.2026
// Description    : Reintegro Gastos - Motor de Calculo IC - F1 Capa CDS de Lectura
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
// Change ID V002 (04.08.2026 | EXT_GONZALCA): Delta v2 CA-03 -- reversion.
// El [v43] de la ET (ET-REING-CA-001_v50, S5.1) amplio esta vista a 4
// dimensiones (Prctr/Campana/RoleCategory/Allocation), pero es un error
// de traduccion del tema "4 dimensiones" del resto del proyecto: esta
// vista SOLO la consume ZI_ReingCALineAll Lado B-1/B-1b (S5.3), cuyo
// propio texto dice explicitamente "expandidos POR RECEPTORA" (grano
// BUKRS_RECV, no Prctr) y cuya clave funcional documentada en S5.3 NO
// incluye las 4 dimensiones. El calculo real (step_pc_split/step_distribute,
// via ZCL_REING_CA_SOURCES=>get_me_shares) lee directo de ZREING_ME_I_A
// (que si tiene las 4 dimensiones desde F0/CA-01) -- nunca pasa por esta
// CDS. Ensanchar esta vista no aportaba nada y generaba fan-out de filas
// con clave duplicada en ZI_ReingCALineAll. Se revierte a la definicion
// original (agregada por sociedad).
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CA - Shares ME agregados por Sociedad Receptora'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCAMeShareBySoc
  as select from ZI_ReingMEItem as MI
    inner join zreing_me_h_a    as MH on MI.MeHId = MH.me_h_id
{
  key MH.ct_id                                     as CtId,
  key MH.matnr                                     as Matnr,
  key MH.period_year                               as PeriodYear,
  key MH.period_month                              as PeriodMonth,
  key MI.Bukrs                                     as BukrsRecv,

      cast( sum( MI.SharePct ) as abap.dec(9,6) )  as SharePctSoc,
      max( MI.Country )                            as Country
}
group by MH.ct_id, MH.matnr, MH.period_year, MH.period_month, MI.Bukrs
