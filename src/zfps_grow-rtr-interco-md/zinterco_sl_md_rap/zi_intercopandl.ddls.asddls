@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany:  P&L'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoPandL
  as select from ZI_GLAccountHierarchyNodePlain as _Plain
  association [0..1] to I_GLAccountHierarchyNode as _PandLL0 on  _PandLL0.HierarchyNode      = $projection.PandLL0Id
                                                             and _PandLL0.GLAccountHierarchy = $projection.GLAccountHierarchy
  association [0..1] to I_GLAccountHierarchyNode as _PandLL1 on  _PandLL1.HierarchyNode      = $projection.PandLL1Id
                                                             and _PandLL1.GLAccountHierarchy = $projection.GLAccountHierarchy
  association [0..1] to I_GLAccountHierarchyNode as _PandLL2 on  _PandLL2.HierarchyNode      = $projection.PandLL2Id
                                                             and _PandLL2.GLAccountHierarchy = $projection.GLAccountHierarchy
  association [0..1] to I_GLAccountHierarchyNode as _PandLL3 on  _PandLL3.HierarchyNode      = $projection.PandLL3Id
                                                             and _PandLL3.GLAccountHierarchy = $projection.GLAccountHierarchy
  association [0..1] to I_GLAccountHierarchyNode as _PandLL4 on  _PandLL4.HierarchyNode      = $projection.PandLL4Id
                                                             and _PandLL4.GLAccountHierarchy = $projection.GLAccountHierarchy
  association [0..1] to I_GLAccountHierarchyNode as _PandLL5 on  _PandLL5.HierarchyNode      = $projection.PandLL5Id
                                                             and _PandLL5.GLAccountHierarchy = $projection.GLAccountHierarchy
{
  key _Plain.GLAccountHierarchy                          as GLAccountHierarchy,
  key _Plain.HierarchyNode                               as PandLId,
      _Plain.HierarchyNodeText                           as PandLName,
      //_Plain.HierarchyNodeLevel as PandLLevel,

      _Plain.HierarchyNodeL0                             as PandLL0Id,
      _PandLL0._Text[ Language = 'S' ].HierarchyNodeText as PandLL0Name,

      _Plain.HierarchyNodeL1                             as PandLL1Id,
      _PandLL1._Text[ Language = 'S' ].HierarchyNodeText as PandLL1Name,

      _Plain.HierarchyNodeL2                             as PandLL2Id,
      _PandLL2._Text[ Language = 'S' ].HierarchyNodeText as PandLL2Name,

      _Plain.HierarchyNodeL3                             as PandLL3Id,
      _PandLL3._Text[ Language = 'S' ].HierarchyNodeText as PandLL3Name,

      _Plain.HierarchyNodeL4                             as PandLL4Id,
      _PandLL4._Text[ Language = 'S' ].HierarchyNodeText as PandLL4Name,

      _Plain.HierarchyNodeL5                             as PandLL5Id,
      _PandLL5._Text[ Language = 'S' ].HierarchyNodeText as PandLL5Name

}
