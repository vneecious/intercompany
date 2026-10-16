@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'z_pnl_mt005-I_GLAccountHierarchyNode'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XXL,
    dataClass: #MIXED
}
define view entity ZI_GlAccountHier_mt005
  with parameters
    P_PanLL0Id : hrynode
  as select from I_GLAccountHierarchyNode as GlHier
  inner join zi_skb1_br on GlHier.GLAccount = zi_skb1_br.GLAccount
  association [1..1] to Z_PNL_MT005 as _mt005 on GlHier.ParentNode = _mt005.zagrup_cuentas
{
  key GlHier.GLAccountHierarchy,
  key GlHier.HierarchyNode,
  key GlHier.ValidityEndDate,
  key _mt005.zconsolidation,
  key _mt005.zagrup_cuentas,
      GlHier.ParentNode,
      GlHier.HierarchyVersion,
      GlHier.ValidityStartDate,
      GlHier.ChartOfAccounts,
      GlHier.GLAccount,
      GlHier.SequenceNumber,
      GlHier.HierarchyNodeSequence,
      GlHier.HierarchyNodeLevel,
      GlHier.NodeType,
      GlHier.SignIsInverted,
      GlHier.HierarchyNodeVal,
      GlHier./* Associations */
      _ChartOfAccounts,
      GlHier._GLAccountInChartOfAccounts,
      GlHier._Hierarchy,
      GlHier._Text,
      _mt005
}
where
      GlHier.GLAccountHierarchy = 'H109/MLIB/ZBCE'
  and GlHier.ValidityEndDate    >= $session.system_date
  and GlHier.NodeType           = 'L'
  and _mt005.IdL0               = $parameters.P_PanLL0Id
