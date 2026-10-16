@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CM - Value Help Materiales x Contrato'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.representativeKey: 'MatUuid'
@Search.searchable: true

define view entity ZI_ReingCMMaterialVH
  as select from zreing_ct2_mat_a
{
      @UI.hidden: true
  key mat_uuid   as MatUuid,

      // CtUuid es el campo de binding (filtro por contrato de la fila)
      @UI.hidden: true
      ct_uuid    as CtUuid,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
      @ObjectModel.text.element: ['MatDesc']
      matnr      as Matnr,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      mat_desc   as MatDesc,

      mat_status as MatStatus
}
