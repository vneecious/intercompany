@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Relation companyproduct/bill products'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_INTERCOPRODRELPRODBIL
  as select from ZI_IntercoCompanyRelProdBill as prodbill

  association [0..*] to ZI_IntercoCompanyRelProduct as _companyprod  on  prodbill.Product       = _companyprod.Product
                                                                     and _companyprod.IsDeleted = ''
                                                                     and _companyprod.ValidFrom <= $session.system_date
                                                                     and _companyprod.ValidTo   >= $session.system_date
  association [0..1] to ZI_READ_DOM_BILLABLE        as _billabletext on  prodbill.IsNotBilable = _billabletext.value
{
  key prodbill.Product,
  key _companyprod.ProviderCompanyCode    as ProviderCompanyCode,
  key prodbill.ProviderCompanyCode        as ProviderCompanyCodeOriginal,
  key prodbill.ProductName,
  key prodbill.PandLID,
  key prodbill.PandLName,
  key lpad(prodbill.ProfitCenter,10, '0') as profitcenter,
  key prodbill.CostCenterSubArea,
  key prodbill.CostCenterAllocation,
      prodbill.IsNotBilable,
      _billabletext.Text                  as textbillable,
      _companyprod.IsPromo                as Ispromo, 
      cast (case when ( prodbill.ProviderCompanyCode <> _companyprod.ProviderCompanyCode and prodbill.ProviderCompanyCode <> '' ) then 'X'
                 else '' end as abap.char(1))   as FlagNotTakeRec


}
where
      prodbill.ValidFrom <= $session.system_date
  and prodbill.ValidTo   >= $session.system_date
  and prodbill.IsDeleted = ' '

group by
  Product,
  _companyprod.ProviderCompanyCode,
  prodbill.ProviderCompanyCode,
  ProductName,
  PandLID,
  PandLName,
  ProfitCenter,
  CostCenterSubArea,
  CostCenterAllocation,
  IsNotBilable,
  _billabletext.Text,
  _companyprod.IsPromo
