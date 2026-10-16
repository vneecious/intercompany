@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CM - Value Help Moneda x Contrato'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.representativeKey: 'Currency'
@Search.searchable: true

define view entity ZI_ReingCMCurrencyVH
  as select from zreing_ct2_a
{
      // CtUuid es el campo de binding (filtro por contrato de la fila)
      @UI.hidden: true
  key ct_uuid as CtUuid,

      @Search.defaultSearchElement: true
  key waers   as Currency
}
where
  waers is not initial
