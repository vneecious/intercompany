@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany / Basis: ZC_IntercoJEItemClass background'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_IntercoJEItemClassBG
  as select from zint_a_jeh
  association to ZI_IntercoJEItemClassBGResult as _Results on  _Results.Ledger       = $projection.Ledger
                                                           and _Results.Companycode  = $projection.Companycode
                                                           and _Results.Fiscalyear   = $projection.Fiscalyear
                                                           and _Results.Fiscalperiod = $projection.Fiscalperiod
                                                           and _Results.PaymentType  = $projection.PaymentType
{
  key id           as ID,
      companycode  as Companycode,
      fiscalyear   as Fiscalyear,
      fiscalperiod as Fiscalperiod,
      ledger       as Ledger,
      paymenttype  as PaymentType,
      allfilters   as AllFilters,
      // EXT_VINBARRI 17.11.2026: columnas pedidas por la UI al lanzar el background (lista separada por coma)
      requestedcolumns as RequestedColumns,
      pending      as Pending,
      createdby    as Createdby,
      createdat    as Createdat,
      _Results
}
