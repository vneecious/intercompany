@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bases Facturables Clasificadas - Items'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoBasisItem
  as select from zfi_a_intrc_bi
  association        to parent ZI_INTERCOBASIS as _header     on $projection.Id = _header.Id
  association [1..1] to ZI_IntercoProduct      as _Product    on _Product.Product = $projection.Product
  association [1..1] to ZI_IntercoDepartment   as _Department on _Department.Department = $projection.Department
  //  association [1..*] to ZI_IntercoProposal     as _Proposals on _Proposals.IntercoBasisId = $projection.Id
{
  key id                            as Id,
  key companycode                   as Providercompanycode,
  key fiscalyear                    as Fiscalyear,
  key fiscalperiod                  as Fiscalperiod,
  key ledger                        as Ledger,
  key pandll5id                     as PandLL5ID,
  key costcenterstandardhierarea    as CostCenterStdHierArea,
  key ccallocation                  as CCAllocation,
  key ccconsolidation               as CCConsolidation,
  key glaccount                     as Glaccount,
  key product                       as Product,
  key costcenter                    as Costcenter,
  key profitcenter                  as Profitcenter,
  key paymenttype                   as PaymentType,
      zfi_a_intrc_bi.mindatetime    as MinDateTime,
      zfi_a_intrc_bi.maxdatetime    as MaxDateTime,
      companycodecurrency           as Companycodecurrency,
      globalcurrency                as Globalcurrency,
      @Semantics.amount.currencyCode: 'Globalcurrency'
      amountinglobalcurrency        as Amountinglobalcurrency,
      @Semantics.amount.currencyCode: 'Companycodecurrency'
      amountincompanycodecurrency   as Amountincompanycodecurrency,
      depto                         as Department,
      is_released                   as IsReleased,
      substring( costcenter, 4, 1 ) as CostCenterD4,
      _header.ExecutionStatus,
      //Associations
      _header,
      _Product,
      _Department
      //      _Proposals
}
