@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Wrapper I_ExchangeRate'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_ExchangeRate as select from I_ExchangeRate
{
    key ExchangeRateType,
    key SourceCurrency,
    key TargetCurrency,
    key ExchangeRateEffectiveDate,
    ExchangeRate,
    NumberOfSourceCurrencyUnits,
    NumberOfTargetCurrencyUnits,
    AlternativeExchangeRateType,
    AltvExchangeRateTypeValdtyDate,
    InvertedExchangeRateIsAllowed,
    ReferenceCurrency,
    BuyingRateAvgExchangeRateType,
    SellingRateAvgExchangeRateType,
    FixedExchangeRateIsUsed,
    SpecialConversionIsUsed,
    SourceCurrencyDecimals,
    TargetCurrencyDecimals,
    ExchRateIsIndirectQuotation,
    AbsoluteExchangeRate,
    EffectiveExchangeRate,
    DirectQuotedEffectiveExchRate,
    IndirectQuotedEffctvExchRate,
    /* Associations */
    _ExchangeRateType,
    _SourceCurrency,
    _TargetCurrency,
    _Text
}
