@AbapCatalog.sqlViewAppendName: 'ZEPURCHORD'
@EndUserText.label: 'Extension R_PurchaseOrder'
extend view R_PurchaseOrder with ZE_R_Purchase_Order
{
  R_PurchasingDocument.zztipo_compra,
//  R_PurchasingDocument.zzusrid,
  R_PurchasingDocument.zzcategoria_oc,
  R_PurchasingDocument.zzsubcategoria_oc
}
