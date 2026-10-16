@EndUserText.label: 'Test'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZC_TEST_INTERCO_STATEMENT_2 
 
as projection on ZI_INTERCO_STATEMENT_2( p_period : '202401',  p_libro: '0L', p_bukrs : 'MLA' )


{
    
   key Ledger,
   key GLAccount,
   key SapEntity,
   key ProfitCenter,
   key CostCenter,
   Allocation,
   Concept,
   AccountDescription,
   zagrup_cuentas,
   Segmento,
   SubSegment,
   Area,
   zconsolidation,
   Subbu,
   BusinessUnit,
   StandardHier,
   SubArea,
   IdL0,
   L0,
   IdL1,
   L1,
   IdL2,
   L2,
   IdL3,
   L3,
   IdL4,
   L4,
   IdL5,
   L5,
   AmountG1,
   AmountG2,
   AmountG3,
   AmountG4,
   AmountG5,
   AmountG6,
   AmountG7,
   AmountG8,
   AmountG9,
   AmountG10,
   AmountG11,
   AmountG12,
   Total,
   Currency,
   IsNotBilable,
   
   @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_INTERCO_BRF_EXEMPTIONS'
   virtual IsNotBilabeExemptions: abap_boolean
   
}
