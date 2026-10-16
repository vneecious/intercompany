@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'teste'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_TestGLAccountHierarchyNode as select from I_GLAccountHierarchyNode
{
  key GLAccountHierarchy,
  key HierarchyNode,
  key ValidityEndDate,
  ParentNode,
  HierarchyVersion,
  ValidityStartDate,
  ChartOfAccounts,
  GLAccount,
  SequenceNumber,
  HierarchyNodeSequence,
  HierarchyNodeLevel,
  NodeType,
  SignIsInverted,
  HierarchyNodeVal,
  /* Associations */
  _ChartOfAccounts,
  _GLAccountInChartOfAccounts,
  _Hierarchy,
  _Text  
}
