@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CM - Value Help Tipo Op x CT+Mat'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.representativeKey: 'OpType'
@Search.searchable: true

define view entity ZI_ReingCMOpTypeVH
  as select from zreing_ct2_opt_a
{
      // Campos de binding (filtro por contrato + material de la fila)
      @UI.hidden: true
  key ct_uuid       as CtUuid,
      @UI.hidden: true
  key mat_uuid      as MatUuid,

      @Search.defaultSearchElement: true
      @Search.ranking: #HIGH
      @ObjectModel.text.element: ['OpTypeDescr']
  key op_type       as OpType,

      @Search.defaultSearchElement: true
      max( op_type_descr ) as OpTypeDescr
}
group by
  ct_uuid,
  mat_uuid,
  op_type
