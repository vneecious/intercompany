@AbapCatalog.sqlViewAppendName: ''
@EndUserText.label: 'Extension I_PurchaseOrderTP_2'
extend view I_PurchaseOrderTP_2 with ZE_I_PurchaseOrderTP_2
{
  _PurchaseOrderTP.zztipo_compra,
  //    _PurchaseOrderTP.zzusrid,
  _PurchaseOrderTP.zzcategoria_oc,
  _PurchaseOrderTP.zzsubcategoria_oc
}
