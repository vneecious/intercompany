@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CM - Value Help Contratos activos'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.representativeKey: 'CtUuid'
@Search.searchable: true

define view entity ZI_ReingCMContractVH
  as select from zreing_ct2_a
{
      @UI.hidden: true
  key ct_uuid       as CtUuid,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
      @ObjectModel.text.element: ['Lifnr']
      ct_id         as CtId,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.7
      lifnr         as Lifnr,

      bukrs         as Bukrs,
      waers         as Waers,
      ct_status     as CtStatus
}
where
  ct_status = 'AC'
