@AbapCatalog.sqlViewAppendName: ''
@EndUserText.label: 'Extension R_PurchaseOrderTP'
extend view R_PurchaseOrderTP with ZE_R_PurchaseOrderTP
{
  PurchaseOrder.zztipo_compra,
  //    PurchaseOrder.zzusrid,
  PurchaseOrder.zzcategoria_oc,
  PurchaseOrder.zzsubcategoria_oc
}
