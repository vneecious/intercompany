@AbapCatalog.sqlViewAppendName: 'ZEPODOC'
@EndUserText.label: 'Extension R_PurchasingDocument'
extend view R_PurchasingDocument with ZE_R_PurchaseOrderDoc
{
  ekko.zztipo_compra,
  //    ekko.zzusrid,
  ekko.zzcategoria_oc,
  ekko.zzsubcategoria_oc
}
