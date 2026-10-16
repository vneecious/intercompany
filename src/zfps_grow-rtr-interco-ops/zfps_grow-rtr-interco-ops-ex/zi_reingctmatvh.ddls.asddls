@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT - Value Help Materiales IC (ICSRV)'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.representativeKey: 'Product'
@Search.searchable: true

define view entity ZI_ReingCTMatVH
  as select from I_ProductVH
    left outer join I_ProductDescription as _Text
      on  _Text.Product  = I_ProductVH.Product
      and _Text.Language = $session.system_language
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
      @ObjectModel.text.element: ['ProductDescription']
  key I_ProductVH.Product          as Product,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
      _Text.ProductDescription      as ProductDescription,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.7
      @Search.ranking: #LOW
      I_ProductVH.ProductExternalID as ProductExternalID,

      I_ProductVH.ProductType       as ProductType,
      I_ProductVH.ProductGroup      as ProductGroup,
      I_ProductVH.BaseUnit          as BaseUnit
}
where
  I_ProductVH.Product like 'ICSRV%'
