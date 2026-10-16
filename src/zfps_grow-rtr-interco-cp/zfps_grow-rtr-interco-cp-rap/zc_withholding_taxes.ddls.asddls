@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'WHT Determination Consumption'
@Metadata.allowExtensions: true
define view entity ZC_WITHHOLDING_TAXES
  as projection on ZI_WITHHOLDING_TAXES
{
  key     Supplier,
  key     CompanyCode,
  key     WithholdingTaxType,
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_INTERCO_BRF_WHT'
          @EndUserText.label: 'Days to Flight'
  virtual WithholdingTax : abap.char( 2 )
}
