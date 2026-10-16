@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT - Value Help Proveedor'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.representativeKey: 'Supplier'

define view entity ZI_ReingCTSupplierVH
  as select from I_Supplier
{
      @UI.selectionField: [{ position: 10 }]
      @ObjectModel.text.element: ['SupplierName']
  key Supplier,

      @UI.selectionField: [{ position: 20 }]
      SupplierAccountGroup,

      @UI.selectionField: [{ position: 30 }]
      SupplierName
}
