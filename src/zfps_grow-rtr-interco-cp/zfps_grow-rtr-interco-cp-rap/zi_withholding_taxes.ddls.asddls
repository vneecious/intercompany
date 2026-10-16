@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Base view for withholding taxes'
@Metadata.ignorePropagatedAnnotations: true

@Analytics: { dataCategory: #CUBE }
@ObjectModel: {
                usageType: { sizeCategory: #XXL,
                dataClass:  #MIXED,
                serviceQuality: #D },
                supportedCapabilities: [#ANALYTICAL_PROVIDER, #SQL_DATA_SOURCE, #CDS_MODELING_DATA_SOURCE],
                modelingPattern: #ANALYTICAL_CUBE }

//@OData.publish: true

define view entity ZI_WITHHOLDING_TAXES
  as select from I_SupplierWithHoldingTax
{
  key Supplier,
  key CompanyCode,
  key WithholdingTaxType,
      //  WithholdingTaxCode
      cast( '' as abap.char(2) ) as WithholdingTax
}
