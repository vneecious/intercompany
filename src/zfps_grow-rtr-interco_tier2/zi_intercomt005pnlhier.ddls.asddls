@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Agrup L5 a L0 (released GLAccount hierarchy)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MASTER }
define view entity ZI_IntercoMT005PnLHier
  as select from zfi_t_mt005 as mt005
  inner join I_GLAccountHierarchyNode as l5
    on l5.GLAccountHierarchy = 'H109/MLIB/ZPYL' and l5.ValidityEndDate = '99991231' and l5.HierarchyNode = mt005.zpl5
  inner join I_GLAccountHierarchyNode as l4
    on l4.GLAccountHierarchy = 'H109/MLIB/ZPYL' and l4.ValidityEndDate = '99991231' and l4.HierarchyNode = l5.ParentNode
  inner join I_GLAccountHierarchyNode as l3
    on l3.GLAccountHierarchy = 'H109/MLIB/ZPYL' and l3.ValidityEndDate = '99991231' and l3.HierarchyNode = l4.ParentNode
  inner join I_GLAccountHierarchyNode as l2
    on l2.GLAccountHierarchy = 'H109/MLIB/ZPYL' and l2.ValidityEndDate = '99991231' and l2.HierarchyNode = l3.ParentNode
  inner join I_GLAccountHierarchyNode as l1
    on l1.GLAccountHierarchy = 'H109/MLIB/ZPYL' and l1.ValidityEndDate = '99991231' and l1.HierarchyNode = l2.ParentNode
  inner join I_GLAccountHierarchyNode as l0
    on l0.GLAccountHierarchy = 'H109/MLIB/ZPYL' and l0.ValidityEndDate = '99991231' and l0.HierarchyNode = l1.ParentNode
{
  key mt005.zconsolidation,
  key mt005.zagrup_cuentas,
      l5._Text[1: Language = 'S' and ValidityEndDate = '99991231'].HierarchyNodeText as L5,
      l5.HierarchyNode as IdL5,
      l4._Text[1: Language = 'S' and ValidityEndDate = '99991231'].HierarchyNodeText as L4,
      l4.HierarchyNode as IdL4,
      l3._Text[1: Language = 'S' and ValidityEndDate = '99991231'].HierarchyNodeText as L3,
      l3.HierarchyNode as IdL3,
      l2._Text[1: Language = 'S' and ValidityEndDate = '99991231'].HierarchyNodeText as L2,
      l2.HierarchyNode as IdL2,
      l1._Text[1: Language = 'S' and ValidityEndDate = '99991231'].HierarchyNodeText as L1,
      l1.HierarchyNode as IdL1,
      l0._Text[1: Language = 'S' and ValidityEndDate = '99991231'].HierarchyNodeText as L0,
      l0.HierarchyNode as IdL0,
      length( mt005.zagrup_cuentas )      as count_zagrup_cuentas,
      concat( '0', mt005.zagrup_cuentas ) as temp_zagrup_cuentas
}
