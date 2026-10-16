@AbapCatalog.sqlViewName: 'ZV_PNL_PROD'
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - PNL Producto - BU - SubBU'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view ZI_PNL_PROD

  as select from hrrp_node  as prd
    inner join   hrrp_nodet as product on  product.hrynode = prd.parnode
                                       and product.hryid   = '0106/ML00/MLIB'
//                                       and product.spras   = $session.system_language
                                       and product.spras   = 'S'
    inner join   hrrp_nodet as subbu   on  subbu.hrynode = product.parnode
                                       and subbu.hryid   = '0106/ML00/MLIB'
//                                       and subbu.spras   = $session.system_language
                                       and subbu.spras   = 'S'
    inner join   hrrp_nodet as bu      on  bu.hrynode = subbu.parnode
                                       and bu.hryid   = '0106/ML00/MLIB'
//                                       and bu.spras   = $session.system_language
                                       and bu.spras   = 'S'
{
  key prd.nodevalue                   as ProfitCenter,
      product.parnode                 as Product,
      product.nodetxt                 as ProductName,
      subbu.parnode                   as Subbu,
      subbu.nodetxt                   as SubbuName,
      bu.parnode                      as BusinessUnit,
      bu.nodetxt                      as BusinessUnitName,
      cast( 0 as abap.sstring( 100 )) as BusinessUnitProductName
}
where
      prd.hryid    = '0106/ML00/MLIB'
  and prd.nodetype = 'L'
