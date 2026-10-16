@AbapCatalog.sqlViewName: 'ZV_RNGOPTYROLE'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Op Types por Rol Contable IC'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #CUSTOMIZING
@Search.searchable: true

define view ZI_ReingOpTypesByRoleVH
  as select from zreing_role_op
    inner join zreing_op_types
      on zreing_op_types.op_type = zreing_role_op.op_type
{
  @Search.defaultSearchElement: true
  @Search.ranking: #HIGH
  key zreing_role_op.gl_role     as GlRole,
  key zreing_role_op.op_type     as OpType,
  @Search.defaultSearchElement: true
  @Search.ranking: #MEDIUM
      zreing_op_types.descr      as Descr,
      zreing_op_types.auto_create as AutoCreate
}
