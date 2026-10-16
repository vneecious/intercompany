@AbapCatalog.viewEnhancementCategory: [#NONE] 
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'I_ProductValuationBasic for Abap Cloud'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZR_ProductValuationBasic
  as select from I_ProductValuationBasic
{
  key Product,
  key ValuationArea,
      @ObjectModel.foreignKey.association: '_InventoryValuationType'
  key ValuationType,
      @ObjectModel.foreignKey.association: '_ValuationClass'
      @ObjectModel.sapObjectNodeTypeReference:'ProductValuationClass'
      ValuationClass,
      @ObjectModel.foreignKey.association: '_PriceDeterminationControl'
      PriceDeterminationControl,
      FiscalMonthCurrentPeriod,
      FiscalYearCurrentPeriod,
      @Semantics.amount.currencyCode: 'Currency'
      StandardPrice,
      PriceUnitQty,
      @ObjectModel.foreignKey.association: '_InventoryValnProcedure'
      @ObjectModel.sapObjectNodeTypeReference:'ProductPriceControl'
      InventoryValuationProcedure,
      FuturePriceValidityStartDate,
      @Semantics.amount.currencyCode: 'Currency'
      PrevInvtryPriceInCoCodeCrcy,
      @Semantics.amount.currencyCode: 'Currency'
      MovingAveragePrice,
      @ObjectModel.sapObjectNodeTypeReference:'ProductValuationCategory'
      ValuationCategory,
      @ObjectModel.foreignKey.association: '_BR_MaterialUsage'
      ProductUsageType,
      @ObjectModel.foreignKey.association: '_BR_MaterialOrigin'
      ProductOriginType,
      IsProducedInhouse,
      ProdCostEstNumber,
      IsMarkedForDeletion,
      //Retail field
      ValuationMargin,
      IsActiveEntity, // to enbale extensibility in Draft 2.0

      //ML fields
      CompanyCode,
      @ObjectModel.foreignKey.association: '_ValnClassSalesOrderStock'
      @ObjectModel.sapObjectNodeTypeReference:'ProductValuationClass'
      ValuationClassSalesOrderStock,
      @ObjectModel.foreignKey.association: '_ValnClassProjectStock'
      @ObjectModel.sapObjectNodeTypeReference:'ProductValuationClass'
      ProjectStockValuationClass,
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      TaxBasedPricesPriceUnitQty,
      PriceLastChangeDate,
      @Semantics.amount.currencyCode: 'Currency'
      FuturePrice,
      MaintenanceStatus,
//      @Semantics.currencyCode: true
      Currency,
//      @Semantics.unitOfMeasure: true
      @ObjectModel.foreignKey.association: '_BaseUnitOfMeasure'                 
      BaseUnit,
      MLIsActiveAtProductLevel,
      _Product,
      _ValuationClass,
      _ValnClassSalesOrderStock,
      _ValnClassProjectStock,
      _InventoryValnProcedure,
      _PriceDeterminationControl,
      _BR_MaterialUsage,
      _BR_MaterialOrigin,
      _InventoryValuationType,
      _BaseUnitOfMeasure
}
