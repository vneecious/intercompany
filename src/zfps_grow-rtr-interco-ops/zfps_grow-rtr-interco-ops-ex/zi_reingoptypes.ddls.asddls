@AbapCatalog.sqlViewName: 'ZV_REINGOPTYP'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT - Value Help Tipos de Operacion'
@Search.searchable: true

define view ZI_ReingOpTypes
  as select from zreing_op_types
{
  @Search.defaultSearchElement: true
  @Search.ranking: #HIGH
  key op_type     as OpType,
  @Search.defaultSearchElement: true
  @Search.ranking: #MEDIUM
      descr       as Descr,
      auto_create as AutoCreate
}
