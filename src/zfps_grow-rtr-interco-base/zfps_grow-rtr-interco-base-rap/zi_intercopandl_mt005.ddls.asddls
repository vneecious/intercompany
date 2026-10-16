@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'join mt005 with pandl hier names'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zi_intercopandl_mt005
  as select from ZI_CDS_MT005 as mt_005
  association [0..1] to ZI_IntercoPandL as _pandl on mt_005.zpl5 = _pandl.PandLId
{
  key mt_005.zagrup_cuentas,
  key mt_005.zconsolidation,
      mt_005.zpl5,
      mt_005.displayName,
      _pandl.PandLL0Id,
      _pandl.PandLL0Name,
      _pandl.PandLL1Id,
      _pandl.PandLL1Name,
      _pandl.PandLL2Id,
      _pandl.PandLL2Name,
      _pandl.PandLL3Id,
      _pandl.PandLL3Name,
      _pandl.PandLL4Id,
      _pandl.PandLL4Name,
      _pandl.PandLL5Id,
      _pandl.PandLL5Name

}
