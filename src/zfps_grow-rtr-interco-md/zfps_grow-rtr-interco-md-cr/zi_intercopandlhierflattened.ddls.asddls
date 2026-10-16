@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'P&L Hierarchy Flattened'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoPandLHierFlattened
  as select from ZI_GLAccountHierarchyNodePlain
  association [0..1] to ZI_IntercoPandLHierFlattened as _L0 on _L0.ID = $projection.IDL0
  association [0..1] to ZI_IntercoPandLHierFlattened as _L1 on _L1.ID = $projection.IDL1
  association [0..1] to ZI_IntercoPandLHierFlattened as _L2 on _L2.ID = $projection.IDL2
  association [0..1] to ZI_IntercoPandLHierFlattened as _L3 on _L3.ID = $projection.IDL3
  association [0..1] to ZI_IntercoPandLHierFlattened as _L4 on _L4.ID = $projection.IDL4
  association [0..1] to ZI_IntercoPandLHierFlattened as _L5 on _L5.ID = $projection.IDL5
{
      @ObjectModel.text.element: [ 'Text' ]
  key HierarchyNode                                                           as ID,
      cast (HierarchyNodeLevel as abap.int4 )                                 as InternalLevel,
      concat('L', cast ( $projection.InternalLevel - 1 as zint_dte_panllvl )) as CustomerLevel,
      HierarchyNodeText                                                       as Text,
      @ObjectModel.text.association: '_L0'
      HierarchyNodeL0                                                         as IDL0,
      @ObjectModel.text.association: '_L1'
      HierarchyNodeL1                                                         as IDL1,
      @ObjectModel.text.association: '_L2'
      HierarchyNodeL2                                                         as IDL2,
      @ObjectModel.text.association: '_L3'
      HierarchyNodeL3                                                         as IDL3,
      @ObjectModel.text.association: '_L4'
      HierarchyNodeL4                                                         as IDL4,
      @ObjectModel.text.association: '_L5'
      HierarchyNodeL5                                                         as IDL5,
      _L0,
      _L1,
      _L2,
      _L3,
      _L4,
      _L5
}
