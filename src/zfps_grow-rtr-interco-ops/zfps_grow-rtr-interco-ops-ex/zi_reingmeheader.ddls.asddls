@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ME - Cabecera Carga Metricas Root View'
@ObjectModel.semanticKey: ['MeHId']
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #MIXED

define root view entity ZI_ReingMEHeader
  as select from    zreing_me_h_a        as H
    left outer join I_ProductDescription as PD  on  PD.Product  = H.matnr
                                                and PD.Language = $session.system_language
    left outer join zreing_ct2_a         as CT  on CT.ct_id = H.ct_id
    left outer join I_Supplier           as SUP on SUP.Supplier = CT.lifnr

  composition [0..*] of ZI_ReingMEItem      as _Item
  association [1..1] to ZI_ReingCTContract2 as _Contract on $projection.CtId = _Contract.CtId
  //Begin Insert V001 (CC) - PA-ME-11 - association to calc usage tracking
  association [0..*] to ZI_ReingMECalcUsage as _CalcUsage on $projection.MeHId = _CalcUsage.MeHId
  //End Insert V001 (CC) - PA-ME-11
  // Begin Mod 25.09.2026 EXT_AGFAGINA - DF-554: nombre de la metrica.
  // La cabecera solo guarda MetricCode + MetVersion, por eso en pantalla se veia
  // "M-0016". Se asocia a la version exacta del Catalogo de Metricas.
  // Solo la asociacion: agregar un campo aca obligaria a sumarlo a la tabla
  // draft (mismo caso que DistType en CM). El campo se expone en ZC_ReingMEHeader.
  association [0..1] to ZI_ReingMCVersion as _MetricVersion
    on  $projection.MetricCode = _MetricVersion.MetricCode
    and $projection.MetVersion = _MetricVersion.VersionNum
  // End Mod 25.09.2026 EXT_AGFAGINA
{
  key H.me_h_id               as MeHId,
      H.ct_id                 as CtId,
      H.ct_ext_num            as CtExtNum,
      H.matnr                 as Matnr,
      PD.ProductDescription   as MatnrDesc,
      SUP.SupplierName        as Proveedor,
      H.period_year           as PeriodYear,
      H.period_month          as PeriodMonth,
      H.load_version          as LoadVersion,
      H.me_status             as MeStatus,
      H.metric_code           as MetricCode,
      H.met_version           as MetVersion,
      H.total_share_pct       as TotalSharePct,
      H.released_by           as ReleasedBy,
      H.released_at           as ReleasedAt,
      @Semantics.user.createdBy: true
      H.created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      H.created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      H.last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      H.last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      H.local_last_changed_at as LocalLastChangedAt,
      _Item,
      _Contract,
      //Begin Insert V001 (CC) - PA-ME-11
      _CalcUsage,
      //End Insert V001 (CC) - PA-ME-11
      // Mod 25.09.2026 EXT_AGFAGINA - DF-554
      _MetricVersion
}
